import 'package:flutter/material.dart';
import 'package:commontable_ai_app/core/models/meal_plan.dart';
import 'package:commontable_ai_app/core/services/ai_meal_plan_service.dart';

class NutritionPlanScreen extends StatefulWidget {
  const NutritionPlanScreen({super.key});

  @override
  State<NutritionPlanScreen> createState() => _NutritionPlanScreenState();
}

class _NutritionPlanScreenState extends State<NutritionPlanScreen> {
  final _service = AiMealPlanService();

  // Form state
  MealPlanTimeframe _timeframe = MealPlanTimeframe.daily;
  DietaryPreference _preference = DietaryPreference.omnivore;
  int _mealsPerDay = 3;
  String _goal = 'Maintain'; // Lose, Maintain, Gain
  late final TextEditingController _calorieCtrl;
  bool _loading = false;
  MealPlan? _plan;

  @override
  void initState() {
    super.initState();
    _calorieCtrl = TextEditingController(text: _goalToCalories(_goal).toString());
  }

  @override
  void dispose() {
    _calorieCtrl.dispose();
    super.dispose();
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
    final calories = int.tryParse(_calorieCtrl.text.trim()) ?? _goalToCalories(_goal);
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Meal Plan Generator', style: TextStyle(fontWeight: FontWeight.bold)),
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
            const Text('Your Goals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _goal,
                    items: const [
                      DropdownMenuItem(value: 'Lose', child: Text('Lose Weight')),
                      DropdownMenuItem(value: 'Maintain', child: Text('Maintain')),
                      DropdownMenuItem(value: 'Gain', child: Text('Gain Muscle')),
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
                      DropdownMenuItem(value: MealPlanTimeframe.daily, child: Text('Daily')),
                      DropdownMenuItem(value: MealPlanTimeframe.weekly, child: Text('Weekly')),
                    ],
                    onChanged: (v) => setState(() => _timeframe = v ?? _timeframe),
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
                      DropdownMenuItem(value: DietaryPreference.omnivore, child: Text('Omnivore')),
                      DropdownMenuItem(value: DietaryPreference.vegetarian, child: Text('Vegetarian')),
                      DropdownMenuItem(value: DietaryPreference.vegan, child: Text('Vegan')),
                      DropdownMenuItem(value: DietaryPreference.lowCarb, child: Text('Low Carb')),
                      DropdownMenuItem(value: DietaryPreference.highProtein, child: Text('High Protein')),
                    ],
                    onChanged: (v) => setState(() => _preference = v ?? _preference),
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
                    onChanged: (v) => setState(() => _mealsPerDay = v ?? _mealsPerDay),
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
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(day.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                Text('${day.dayCalories} kcal · P ${day.dayProtein} · C ${day.dayCarbs} · F ${day.dayFats}', style: const TextStyle(color: Colors.black54)),
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
        ...meal.items.map((i) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(i.name)),
                Text('${i.calories} kcal', style: const TextStyle(color: Colors.black54)),
              ],
            )),
        Align(
          alignment: Alignment.centerRight,
          child: Text('Total: ${meal.totalCalories} kcal · P ${meal.totalProtein} · C ${meal.totalCarbs} · F ${meal.totalFats}',
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ),
        const Divider(height: 16),
      ],
    );
  }
}
