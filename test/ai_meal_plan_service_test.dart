import 'package:commontable_ai_app/core/models/meal_plan.dart';
import 'package:commontable_ai_app/core/services/ai_meal_plan_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('weekly plan generates 7 days and reasonable calories', () {
    final svc = AiMealPlanService();
    final plan = svc.generatePlan(
      targetCalories: 2400,
      timeframe: MealPlanTimeframe.weekly,
      preference: DietaryPreference.omnivore,
      mealsPerDay: 3,
    );

    expect(plan.days.length, 7);
    for (final day in plan.days) {
      // allow +/- 20% tolerance due to simple algorithm
      expect(day.dayCalories, inInclusiveRange(1920, 2880));
      expect(day.meals.length, 3);
      expect(day.meals.first.items.isNotEmpty, true);
    }
  });
}
