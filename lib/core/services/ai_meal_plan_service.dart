import 'dart:math';

import 'package:commontable_ai_app/core/models/meal_plan.dart';

class AiMealPlanService {
  final _rand = Random(42);

  MealPlan generatePlan({
    required int targetCalories,
    required MealPlanTimeframe timeframe,
    required DietaryPreference preference,
    int mealsPerDay = 3,
  }) {
    final daysCount = timeframe == MealPlanTimeframe.daily ? 1 : 7;
    final splits = _calorieSplits(mealsPerDay);
    final db = _foodDb(preference);

    List<DayPlan> days = List.generate(daysCount, (dayIdx) {
      final label = timeframe == MealPlanTimeframe.daily
          ? 'Today'
          : _weekdayLabel(dayIdx);

      final meals = <Meal>[];
      for (int i = 0; i < mealsPerDay; i++) {
        final mealTitle = _mealTitle(i, mealsPerDay);
        final mealTarget = (targetCalories * splits[i]).round();
        meals.add(_buildMeal(mealTitle, mealTarget, db));
      }
      return DayPlan(label: label, meals: meals);
    });

    return MealPlan(
      timeframe: timeframe,
      targetCalories: targetCalories,
      preference: preference,
      mealsPerDay: mealsPerDay,
      days: days,
    );
  }

  Meal _buildMeal(String title, int target, List<MealItem> db) {
    // Simple greedy selection plus optional scaling of last item to match calories
    int remaining = target;
    final chosen = <MealItem>[];
    int attempts = 0;

    // pick up to 3-4 items
    while (remaining > 200 && chosen.length < 3 && attempts < 20) {
      attempts++;
      final candidate = db[_rand.nextInt(db.length)];
      if (candidate.calories < remaining && !_contains(chosen, candidate)) {
        chosen.add(candidate);
        remaining -= candidate.calories;
      }
    }

    // If still far from target, scale a filler item (e.g., nuts, yogurt, rice)
    if (remaining > 80) {
      final filler = _bestFiller(db);
      final factor = remaining / filler.calories;
      chosen.add(filler.scale(factor.clamp(0.5, 2.0)));
      remaining = 0;
    }

    // If underflow negative, trim last item slightly
    int total = chosen.fold(0, (s, i) => s + i.calories);
    if (total > target + 150 && chosen.isNotEmpty) {
      final last = chosen.removeLast();
      final over = total - target;
      final factor = (last.calories - over) / last.calories;
      if (factor > 0.5) chosen.add(last.scale(factor));
    }

    return Meal(title: title, items: chosen);
  }

  bool _contains(List<MealItem> items, MealItem x) =>
      items.any((i) => i.name == x.name);

  List<double> _calorieSplits(int mealsPerDay) {
    switch (mealsPerDay) {
      case 2:
        return const [0.45, 0.55];
      case 3:
        return const [0.25, 0.40, 0.35];
      case 4:
        return const [0.22, 0.33, 0.30, 0.15];
      case 5:
        return const [0.20, 0.30, 0.28, 0.12, 0.10];
      default:
        return List.filled(mealsPerDay, 1.0 / mealsPerDay);
    }
  }

  String _mealTitle(int idx, int mealsPerDay) {
    const names = ['Breakfast', 'Lunch', 'Dinner', 'Snack', 'Snack'];
    return idx < names.length ? names[idx] : 'Meal ${idx + 1}';
  }

  String _weekdayLabel(int dayIdx) {
    const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return names[dayIdx % 7];
  }

  MealItem _bestFiller(List<MealItem> db) {
    // choose calorie-dense neutral filler
    final fillers = db.where((m) => m.name.contains('Rice') || m.name.contains('Oats') || m.name.contains('Yogurt') || m.name.contains('Nuts')).toList();
    return fillers.isNotEmpty ? fillers[_rand.nextInt(fillers.length)] : db[_rand.nextInt(db.length)];
  }

  List<MealItem> _foodDb(DietaryPreference pref) {
    // Per-serving approximate macros
    const omni = [
      MealItem(name: 'Oats (1 cup cooked)', calories: 150, protein: 5, carbs: 27, fats: 3),
      MealItem(name: 'Greek Yogurt (200g)', calories: 120, protein: 20, carbs: 7, fats: 0),
      MealItem(name: 'Banana', calories: 105, protein: 1, carbs: 27, fats: 0),
      MealItem(name: 'Chicken Breast (150g)', calories: 248, protein: 46, carbs: 0, fats: 5),
      MealItem(name: 'Salmon (150g)', calories: 280, protein: 34, carbs: 0, fats: 14),
      MealItem(name: 'Brown Rice (1 cup)', calories: 215, protein: 5, carbs: 45, fats: 2),
      MealItem(name: 'Quinoa (1 cup)', calories: 222, protein: 8, carbs: 39, fats: 3),
      MealItem(name: 'Avocado (1/2)', calories: 120, protein: 1, carbs: 6, fats: 10),
      MealItem(name: 'Almonds (30g)', calories: 174, protein: 6, carbs: 6, fats: 15),
      MealItem(name: 'Eggs (2)', calories: 156, protein: 12, carbs: 2, fats: 10),
      MealItem(name: 'Sweet Potato (200g)', calories: 180, protein: 4, carbs: 41, fats: 0),
      MealItem(name: 'Broccoli (1 cup)', calories: 55, protein: 4, carbs: 11, fats: 0),
    ];

    const veg = [
      MealItem(name: 'Tofu (150g)', calories: 180, protein: 18, carbs: 6, fats: 10),
      MealItem(name: 'Lentils (1 cup cooked)', calories: 230, protein: 18, carbs: 40, fats: 1),
      MealItem(name: 'Chickpeas (1 cup)', calories: 269, protein: 14, carbs: 45, fats: 4),
      MealItem(name: 'Brown Rice (1 cup)', calories: 215, protein: 5, carbs: 45, fats: 2),
      MealItem(name: 'Quinoa (1 cup)', calories: 222, protein: 8, carbs: 39, fats: 3),
      MealItem(name: 'Greek Yogurt (200g)', calories: 120, protein: 20, carbs: 7, fats: 0),
      MealItem(name: 'Spinach (2 cups)', calories: 20, protein: 2, carbs: 3, fats: 0),
      MealItem(name: 'Banana', calories: 105, protein: 1, carbs: 27, fats: 0),
      MealItem(name: 'Almonds (30g)', calories: 174, protein: 6, carbs: 6, fats: 15),
      MealItem(name: 'Sweet Potato (200g)', calories: 180, protein: 4, carbs: 41, fats: 0),
    ];

    const vegan = [
      MealItem(name: 'Tofu (150g)', calories: 180, protein: 18, carbs: 6, fats: 10),
      MealItem(name: 'Tempeh (150g)', calories: 300, protein: 30, carbs: 18, fats: 12),
      MealItem(name: 'Lentils (1 cup cooked)', calories: 230, protein: 18, carbs: 40, fats: 1),
      MealItem(name: 'Chickpeas (1 cup)', calories: 269, protein: 14, carbs: 45, fats: 4),
      MealItem(name: 'Brown Rice (1 cup)', calories: 215, protein: 5, carbs: 45, fats: 2),
      MealItem(name: 'Quinoa (1 cup)', calories: 222, protein: 8, carbs: 39, fats: 3),
      MealItem(name: 'Spinach (2 cups)', calories: 20, protein: 2, carbs: 3, fats: 0),
      MealItem(name: 'Banana', calories: 105, protein: 1, carbs: 27, fats: 0),
      MealItem(name: 'Almonds (30g)', calories: 174, protein: 6, carbs: 6, fats: 15),
      MealItem(name: 'Oats (1 cup cooked)', calories: 150, protein: 5, carbs: 27, fats: 3),
    ];

    const lowCarb = [
      MealItem(name: 'Eggs (2)', calories: 156, protein: 12, carbs: 2, fats: 10),
      MealItem(name: 'Chicken Breast (150g)', calories: 248, protein: 46, carbs: 0, fats: 5),
      MealItem(name: 'Salmon (150g)', calories: 280, protein: 34, carbs: 0, fats: 14),
      MealItem(name: 'Avocado (1/2)', calories: 120, protein: 1, carbs: 6, fats: 10),
      MealItem(name: 'Greek Yogurt (200g)', calories: 120, protein: 20, carbs: 7, fats: 0),
      MealItem(name: 'Almonds (30g)', calories: 174, protein: 6, carbs: 6, fats: 15),
      MealItem(name: 'Broccoli (1 cup)', calories: 55, protein: 4, carbs: 11, fats: 0),
      MealItem(name: 'Tofu (150g)', calories: 180, protein: 18, carbs: 6, fats: 10),
    ];

    const highProtein = [
      MealItem(name: 'Chicken Breast (200g)', calories: 330, protein: 62, carbs: 0, fats: 7),
      MealItem(name: 'Greek Yogurt (250g)', calories: 150, protein: 25, carbs: 9, fats: 0),
      MealItem(name: 'Eggs (3)', calories: 234, protein: 18, carbs: 3, fats: 15),
      MealItem(name: 'Tofu (200g)', calories: 240, protein: 24, carbs: 8, fats: 13),
      MealItem(name: 'Tempeh (150g)', calories: 300, protein: 30, carbs: 18, fats: 12),
      MealItem(name: 'Lentils (1 cup cooked)', calories: 230, protein: 18, carbs: 40, fats: 1),
      MealItem(name: 'Quinoa (1 cup)', calories: 222, protein: 8, carbs: 39, fats: 3),
      MealItem(name: 'Brown Rice (1 cup)', calories: 215, protein: 5, carbs: 45, fats: 2),
    ];

    switch (pref) {
      case DietaryPreference.vegetarian:
        return veg + [
          MealItem(name: 'Nuts (30g)', calories: 174, protein: 6, carbs: 6, fats: 15),
          MealItem(name: 'Yogurt (200g)', calories: 120, protein: 20, carbs: 7, fats: 0),
        ];
      case DietaryPreference.vegan:
        return vegan + [MealItem(name: 'Peanut Butter (2 tbsp)', calories: 180, protein: 7, carbs: 7, fats: 16)];
      case DietaryPreference.lowCarb:
        return lowCarb + [MealItem(name: 'Cheese (50g)', calories: 200, protein: 12, carbs: 1, fats: 17)];
      case DietaryPreference.highProtein:
        return highProtein + [MealItem(name: 'Whey (1 scoop)', calories: 120, protein: 24, carbs: 3, fats: 1)];
      case DietaryPreference.omnivore:
        return omni;
    }
  }
}
