import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:commontable_ai_app/core/models/meal_plan.dart';
import 'package:commontable_ai_app/core/services/ai_meal_plan_service.dart';
import 'package:commontable_ai_app/core/services/diet_assessment_service.dart';
import 'package:commontable_ai_app/core/services/offline_cache_service.dart';
import 'package:commontable_ai_app/core/services/privacy_settings_service.dart';
import 'package:commontable_ai_app/routes/app_route.dart';

class NutritionPlanScreen extends StatefulWidget {
  const NutritionPlanScreen({super.key});

  @override
  State<NutritionPlanScreen> createState() => _NutritionPlanScreenState();
}

class _NutritionPlanScreenState extends State<NutritionPlanScreen> {
  final _service = AiMealPlanService();
  final _assessor = DietAssessmentService();

  // Form state
  MealPlanTimeframe _timeframe = MealPlanTimeframe.daily;
  DietaryPreference _preference = DietaryPreference.omnivore;
  int _mealsPerDay = 3;
  String _goal = 'Maintain'; // Lose, Maintain, Gain
  late final TextEditingController _calorieCtrl;
  bool _loading = false;
  MealPlan? _plan;

  // Assessment state
  final TextEditingController _dietTextCtrl = TextEditingController();
  bool _assessing = false;
  DietAssessmentResult? _assessment;
  List<_ScorePoint> _history = [];
  String _historyPeriodFilter = 'All'; // All | daily | weekly
  String? _userId; // if auth available

  @override
  void initState() {
    super.initState();
    _calorieCtrl = TextEditingController(
      text: _goalToCalories(_goal).toString(),
    );
    _resolveUser();
    _loadHistory();
    _loadOfflinePlanIfAny();
  }

  @override
  void dispose() {
    _calorieCtrl.dispose();
    _dietTextCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOfflinePlanIfAny() async {
    try {
      final p = await PrivacySettingsService().load();
      if (!p.offlineMode) return;
      final cached = await OfflineCacheService().getMealPlan();
      if (cached != null && mounted) {
        setState(() => _plan = cached);
      }
    } catch (_) {}
  }

  int _goalToCalories(String g) {
    switch (g) {
      case 'Lose':
        return 2000;
      case 'Gain':
        return 2800;
      case 'Maintain':
      default:
        return 2400;
    }
  }

  Future<void> _generate() async {
    FocusScope.of(context).unfocus();
    final calories =
        int.tryParse(_calorieCtrl.text.trim()) ?? _goalToCalories(_goal);
    setState(() {
      _loading = true;
      _plan = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final plan = _service.generatePlan(
      targetCalories: calories,
      timeframe: _timeframe,
      preference: _preference,
      mealsPerDay: _mealsPerDay,
    );
    setState(() {
      _plan = plan;
      _loading = false;
    });
  }

  Future<void> _assess() async {
    FocusScope.of(context).unfocus();
    final lines = _dietTextCtrl.text.split('\n');
    setState(() {
      _assessing = true;
      _assessment = null;
    });
    try {
      final result = await _assessor.assessDiet(
        foods: lines,
        period: _timeframe == MealPlanTimeframe.daily ? 'daily' : 'weekly',
      );
      setState(() => _assessment = result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Assessment failed: $e')));
    } finally {
      if (mounted) setState(() => _assessing = false);
    }
  }

  Future<void> _saveAssessment() async {
    if (_assessment == null) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      await _resolveUser();
      final a = _assessment!;
      await FirebaseFirestore.instance.collection('dietAssessments').add({
        'createdAt': a.createdAt.toIso8601String(),
        'period': a.period,
        'healthScore': a.healthScore,
        'intake': a.intake,
        'risks': a.risks,
        'suggestions': a.suggestions,
        if (_userId != null) 'userId': _userId,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Assessment saved')));
      await _loadHistory();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  Future<void> _loadHistory() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      await _resolveUser();
      Query<Map<String, dynamic>> ref = FirebaseFirestore.instance.collection(
        'dietAssessments',
      );
      if (_userId != null) {
        ref = ref.where('userId', isEqualTo: _userId);
      }
      if (_historyPeriodFilter == 'daily') {
        ref = ref.where('period', isEqualTo: 'daily');
      } else if (_historyPeriodFilter == 'weekly') {
        ref = ref.where('period', isEqualTo: 'weekly');
      }
      final qs = await ref
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();
      final points = <_ScorePoint>[];
      for (final d in qs.docs) {
        final data = d.data();
        final ts = DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now();
        final sc = (data['healthScore'] as num?)?.toDouble() ?? 0;
        points.add(_ScorePoint(ts, sc));
      }
      setState(() => _history = points.reversed.toList());
    } catch (_) {
      // ignore silently
    }
  }

  Future<void> _resolveUser() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      final user = FirebaseAuth.instance.currentUser;
      setState(() => _userId = user?.uid);
    } catch (_) {
      // auth not set up; leave _userId as null
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AI Meal Plan Generator',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        color: Colors.grey.shade100,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildForm(),
              const SizedBox(height: 16),
              if (_loading) const Center(child: CircularProgressIndicator()),
              if (!_loading && _plan != null) _PlanView(plan: _plan!),
              const SizedBox(height: 16),
              _buildAssessmentCard(),
              if (_assessment != null) ...[
                const SizedBox(height: 12),
                _buildAssessmentResult(_assessment!),
              ],
              const SizedBox(height: 16),
              if (_history.isNotEmpty) _buildProgressChart(),
              if (_history.isNotEmpty) const SizedBox(height: 12),
              if (_history.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoutes.progressDashboard,
                    ),
                    icon: const Icon(Icons.dashboard_customize_outlined),
                    label: const Text('View Full Progress Dashboard'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Goals',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _goal,
                    items: const [
                      DropdownMenuItem(
                        value: 'Lose',
                        child: Text('Lose Weight'),
                      ),
                      DropdownMenuItem(
                        value: 'Maintain',
                        child: Text('Maintain'),
                      ),
                      DropdownMenuItem(
                        value: 'Gain',
                        child: Text('Gain Muscle'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _goal = v;
                        _calorieCtrl.text = _goalToCalories(v).toString();
                      });
                    },
                    decoration: const InputDecoration(labelText: 'Goal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<MealPlanTimeframe>(
                    initialValue: _timeframe,
                    items: const [
                      DropdownMenuItem(
                        value: MealPlanTimeframe.daily,
                        child: Text('Daily'),
                      ),
                      DropdownMenuItem(
                        value: MealPlanTimeframe.weekly,
                        child: Text('Weekly'),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _timeframe = v ?? _timeframe),
                    decoration: const InputDecoration(labelText: 'Timeframe'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<DietaryPreference>(
                    initialValue: _preference,
                    items: const [
                      DropdownMenuItem(
                        value: DietaryPreference.omnivore,
                        child: Text('Omnivore'),
                      ),
                      DropdownMenuItem(
                        value: DietaryPreference.vegetarian,
                        child: Text('Vegetarian'),
                      ),
                      DropdownMenuItem(
                        value: DietaryPreference.vegan,
                        child: Text('Vegan'),
                      ),
                      DropdownMenuItem(
                        value: DietaryPreference.lowCarb,
                        child: Text('Low Carb'),
                      ),
                      DropdownMenuItem(
                        value: DietaryPreference.highProtein,
                        child: Text('High Protein'),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _preference = v ?? _preference),
                    decoration: const InputDecoration(labelText: 'Preference'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _mealsPerDay,
                    items: const [
                      DropdownMenuItem(value: 2, child: Text('2 meals/day')),
                      DropdownMenuItem(value: 3, child: Text('3 meals/day')),
                      DropdownMenuItem(value: 4, child: Text('4 meals/day')),
                      DropdownMenuItem(value: 5, child: Text('5 meals/day')),
                    ],
                    onChanged: (v) =>
                        setState(() => _mealsPerDay = v ?? _mealsPerDay),
                    decoration: const InputDecoration(labelText: 'Meals/Day'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _calorieCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Target Calories'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                onPressed: _loading ? null : _generate,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generate Plan'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssessmentCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.health_and_safety_outlined, color: Colors.teal),
                SizedBox(width: 8),
                Text(
                  'AI Dietary Assessment & Risk Analyzer',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Enter foods you ate ${_timeframe == MealPlanTimeframe.daily ? 'today' : 'this week'} (one per line):',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _dietTextCtrl,
              decoration: const InputDecoration(
                hintText:
                    'e.g. oats with yogurt\nrice and beans\nchicken stew with vegetables',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _assessing ? null : _assess,
                    icon: const Icon(Icons.analytics_outlined),
                    label: Text(_assessing ? 'Assessing...' : 'Assess My Diet'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _assessment == null ? null : _saveAssessment,
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('Save Assessment'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssessmentResult(DietAssessmentResult a) {
    final pct = (a.healthScore / 100).clamp(0.0, 1.0);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Diet Quality Score',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 14,
                backgroundColor: Colors.grey.withValues(alpha: 0.2),
                color: pct >= 0.7
                    ? Colors.green
                    : pct >= 0.5
                    ? Colors.orange
                    : Colors.red,
              ),
            ),
            const SizedBox(height: 6),
            Text('${a.healthScore.toStringAsFixed(0)}%'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: a.risks.isEmpty
                  ? [const Chip(label: Text('No immediate risks detected'))]
                  : a.risks.map((r) => Chip(label: Text(r))).toList(),
            ),
            const SizedBox(height: 12),
            const Text(
              'AI Suggestions',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            _aiText(a.suggestions),
          ],
        ),
      ),
    );
  }

  Widget _aiText(String text) {
    final parsed = _parseBullets(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (parsed.base.isNotEmpty) Text(parsed.base),
        if (parsed.bullets != null) ...[
          const SizedBox(height: 8),
          ...parsed.bullets!.map(
            (b) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• '),
                Expanded(child: Text(b)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProgressChart() {
    final spots = <FlSpot>[];
    for (var i = 0; i < _history.length; i++) {
      spots.add(FlSpot(i.toDouble(), _history[i].score));
    }
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Diet Quality Progress',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Filter:'),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _historyPeriodFilter,
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All')),
                    DropdownMenuItem(value: 'daily', child: Text('Daily')),
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                  ],
                  onChanged: (v) async {
                    if (v == null) return;
                    setState(() => _historyPeriodFilter = v);
                    await _loadHistory();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 100,
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      barWidth: 3,
                      color: Colors.teal,
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanView extends StatelessWidget {
  final MealPlan plan;
  const _PlanView({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          plan.timeframe == MealPlanTimeframe.daily
              ? 'Your Daily Plan (~${plan.targetCalories} kcal)'
              : 'Your Weekly Plan (~${plan.targetCalories} kcal/day)',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        if (plan.timeframe == MealPlanTimeframe.daily)
          _DayCard(day: plan.days.first)
        else
          ...plan.days.map((d) => _DayCard(day: d)),
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  final DayPlan day;
  const _DayCard({required this.day});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    day.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${day.dayCalories} kcal · P ${day.dayProtein} · C ${day.dayCarbs} · F ${day.dayFats}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...day.meals.map((m) => _MealTile(meal: m)),
          ],
        ),
      ),
    );
  }
}

class _MealTile extends StatelessWidget {
  final Meal meal;
  const _MealTile({required this.meal});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(meal.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        ...meal.items.map(
          (i) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(i.name)),
              Text(
                '${i.calories} kcal',
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Total: ${meal.totalCalories} kcal · P ${meal.totalProtein} · C ${meal.totalCarbs} · F ${meal.totalFats}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),
        const Divider(height: 16),
      ],
    );
  }
}

class _ScorePoint {
  final DateTime ts;
  final double score; // 0..100
  _ScorePoint(this.ts, this.score);
}

class _ParsedReply {
  final String base;
  final List<String>? bullets;
  _ParsedReply(this.base, this.bullets);
}

_ParsedReply _parseBullets(String text) {
  final lines = text.split('\n');
  final bullets = <String>[];
  final baseLines = <String>[];
  for (final l in lines) {
    final t = l.trimLeft();
    if (t.startsWith('• ') || t.startsWith('- ')) {
      final cleaned = t.substring(2).trim();
      if (cleaned.isNotEmpty) bullets.add(cleaned);
    } else {
      baseLines.add(l);
    }
  }
  final base = baseLines.join('\n').trim();
  return _ParsedReply(
    base.isEmpty ? text : base,
    bullets.isEmpty ? null : bullets,
  );
}
