import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ProgressDashboardScreen extends StatefulWidget {
  const ProgressDashboardScreen({super.key});

  @override
  State<ProgressDashboardScreen> createState() => _ProgressDashboardScreenState();
}

class _ProgressDashboardScreenState extends State<ProgressDashboardScreen> {
  String? _userId;

  @override
  void initState() {
    super.initState();
    _ensureInit();
  }

  Future<void> _ensureInit() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _userId = FirebaseAuth.instance.currentUser?.uid;
      if (mounted) setState(() {});
    } catch (_) {
      // ignore if auth not configured
    }
  }

  Stream<List<_AssessmentDoc>> _assessmentsStream() {
    Query<Map<String, dynamic>> ref = FirebaseFirestore.instance
        .collection('dietAssessments')
        .orderBy('createdAt', descending: true)
        .limit(30);
    if (_userId != null) {
      ref = ref.where('userId', isEqualTo: _userId);
    }
    return ref.snapshots().map((snap) => snap.docs.map((d) => _AssessmentDoc.from(d.data())).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Progress Dashboard"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<_AssessmentDoc>>(
        stream: _assessmentsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.insights_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('No assessments yet', style: TextStyle(fontWeight: FontWeight.w700)),
                    SizedBox(height: 4),
                    Text('Save a diet assessment to see your progress here.', textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }

          final latest = items.first;
          final last7 = items.take(7).toList().reversed.toList();
          final last14 = items.take(14).toList().reversed.toList();

          // Overview averages for last 7 days
          double avgCal = 0, avgPro = 0, avgCarb = 0, avgFat = 0;
          for (final it in last7) {
            avgCal += it.calories;
            avgPro += it.protein;
            avgCarb += it.carbs;
            avgFat += it.fat;
          }
          final div = last7.isEmpty ? 1 : last7.length.toDouble();
          avgCal /= div;
          avgPro /= div;
          avgCarb /= div;
          avgFat /= div;

          // Daily intake ring from latest
          const targetCal = 2400.0;
          final ringVal = (latest.calories / targetCal).clamp(0.0, 1.0);

          // Macro percents from latest
          final macroKcal = (latest.protein * 4) + (latest.carbs * 4) + (latest.fat * 9);
          final pctPro = macroKcal == 0 ? 0.0 : (latest.protein * 4) / macroKcal;
          final pctCarb = macroKcal == 0 ? 0.0 : (latest.carbs * 4) / macroKcal;
          final pctFat = macroKcal == 0 ? 0.0 : (latest.fat * 9) / macroKcal;

          // Weekly calories bar (last 7 documents)
          final barLabels = last7.map((e) => DateFormat('E').format(e.createdAt)).toList();
          final barValues = last7.map((e) => e.calories.round()).toList();
          final maxBar = (barValues.isEmpty ? 0 : (barValues.reduce((a, b) => a > b ? a : b))) + 200;

          // 2-week trend of health score
          final trend = last14.map((e) => e.healthScore.round()).toList();
          final maxTrend = 100;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Overview stats
                Row(
                  children: [
                    Expanded(child: _StatCard(title: 'Calories', value: '${avgCal.toStringAsFixed(0)} kcal (avg 7d)', color: Colors.orange, icon: Icons.local_fire_department)),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(title: 'Protein', value: '${avgPro.toStringAsFixed(0)} g (avg 7d)', color: Colors.green, icon: Icons.fitness_center)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _StatCard(title: 'Carbs', value: '${avgCarb.toStringAsFixed(0)} g (avg 7d)', color: Colors.blue, icon: Icons.bakery_dining)),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(title: 'Fats', value: '${avgFat.toStringAsFixed(0)} g (avg 7d)', color: Colors.purple, icon: Icons.opacity)),
                  ],
                ),

                const SizedBox(height: 24),

                // Daily intake ring
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        _RingProgress(label: 'Latest Intake', valueLabel: '${latest.calories.toStringAsFixed(0)} / ${targetCal.toStringAsFixed(0)}', value: ringVal, color: Colors.orange),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Latest Summary", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              _MacroRow(label: 'Protein', percent: pctPro, color: Colors.green),
                              const SizedBox(height: 8),
                              _MacroRow(label: 'Carbs', percent: pctCarb, color: Colors.blue),
                              const SizedBox(height: 8),
                              _MacroRow(label: 'Fats', percent: pctFat, color: Colors.purple),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Text("Your Weekly Nutrition Summary", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Calorie Intake (kcal)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        _SimpleBarChart(labels: barLabels, values: barValues, maxValue: maxBar, barColor: Colors.green),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                const Text("Diet Quality Score Trend", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      height: 160,
                      child: _SimpleLineChart(points: trend, maxValue: maxTrend, lineColor: Colors.teal),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

}

// Simple bar chart using Rows and Containers
class _SimpleBarChart extends StatelessWidget {
  final List<String> labels;
  final List<int> values;
  final int maxValue;
  final Color barColor;

  const _SimpleBarChart({
    required this.labels,
    required this.values,
    required this.maxValue,
    this.barColor = Colors.green,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Allow horizontal scroll when space is tight to avoid overflow
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (int i = 0; i < values.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _Bar(
                    heightFactor: maxValue == 0 ? 0 : (values[i] / maxValue),
                    label: labels[i],
                    color: barColor,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  final double heightFactor;
  final String label;
  final Color color;

  const _Bar({
    required this.heightFactor,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 18,
          height: 160 * heightFactor.clamp(0.0, 1.0),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _MacroRow extends StatelessWidget {
  final String label;
  final double percent;
  final Color color;

  const _MacroRow({
    required this.label,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 70, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 10,
              color: color,
              backgroundColor: Colors.grey.shade300,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text("${(percent * 100).round()}%", style: const TextStyle(color: Colors.black54)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(10),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            // Make the text area flexible so it wraps within tight widths
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.black54),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _RingProgress extends StatelessWidget {
  final String label;
  final String valueLabel;
  final double value;
  final Color color;

  const _RingProgress({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 90,
              height: 90,
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: 10,
                color: color,
                backgroundColor: Colors.grey.shade300,
              ),
            ),
            Text("${(value * 100).round()}%", style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(valueLabel, style: const TextStyle(color: Colors.black54)),
      ],
    );
  }
}

class _SimpleLineChart extends StatelessWidget {
  final List<int> points;
  final int maxValue;
  final Color lineColor;

  const _SimpleLineChart({
    required this.points,
    required this.maxValue,
    this.lineColor = Colors.green,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LineChartPainter(points: points, maxValue: maxValue, color: lineColor),
      size: Size.infinite,
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<int> points;
  final int maxValue;
  final Color color;

  _LineChartPainter({required this.points, required this.maxValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path = Path();
    final double dxStep = size.width / (points.length - 1);

    double x = 0;
    double y = size.height - (points.first / maxValue) * size.height;
    path.moveTo(x, y);

    for (int i = 1; i < points.length; i++) {
      x = dxStep * i;
      y = size.height - (points[i] / maxValue) * size.height;
      path.lineTo(x, y);
    }

    // Draw axes baseline (optional subtle)
    final axisPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), axisPaint);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _AssessmentDoc {
  final DateTime createdAt;
  final String period;
  final double healthScore;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  _AssessmentDoc({
    required this.createdAt,
    required this.period,
    required this.healthScore,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  static _AssessmentDoc from(Map<String, dynamic> data) {
    final intake = (data['intake'] as Map?)?.cast<String, dynamic>() ?? const {};
    return _AssessmentDoc(
      createdAt: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
      period: data['period'] ?? 'daily',
      healthScore: (data['healthScore'] as num?)?.toDouble() ?? 0,
      calories: (intake['Calories (kcal)'] as num?)?.toDouble() ?? (data['calories'] as num?)?.toDouble() ?? 0,
      protein: (intake['Protein (g)'] as num?)?.toDouble() ?? 0,
      carbs: (intake['Carbs (g)'] as num?)?.toDouble() ?? 0,
      fat: (intake['Fat (g)'] as num?)?.toDouble() ?? 0,
    );
  }
}
