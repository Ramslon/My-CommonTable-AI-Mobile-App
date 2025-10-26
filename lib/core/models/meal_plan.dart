import 'package:flutter/foundation.dart';

@immutable
class MealItem {
  final String name;
  final int calories; // per serving
  final int protein; // g
  final int carbs; // g
  final int fats; // g
  final double servings; // portion multiplier

  const MealItem({
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    this.servings = 1.0,
  });

  MealItem scale(double factor) => MealItem(
        name: name,
        calories: (calories * factor).round(),
        protein: (protein * factor).round(),
        carbs: (carbs * factor).round(),
        fats: (fats * factor).round(),
        servings: servings * factor,
      );
}

@immutable
class Meal {
  final String title; // Breakfast/Lunch/Dinner/Snack
  final List<MealItem> items;

  const Meal({required this.title, required this.items});

  int get totalCalories => items.fold(0, (s, i) => s + i.calories);
  int get totalProtein => items.fold(0, (s, i) => s + i.protein);
  int get totalCarbs => items.fold(0, (s, i) => s + i.carbs);
  int get totalFats => items.fold(0, (s, i) => s + i.fats);
}

@immutable
class DayPlan {
  final String label; // e.g., Monday or Today
  final List<Meal> meals;

  const DayPlan({required this.label, required this.meals});

  int get dayCalories => meals.fold(0, (s, m) => s + m.totalCalories);
  int get dayProtein => meals.fold(0, (s, m) => s + m.totalProtein);
  int get dayCarbs => meals.fold(0, (s, m) => s + m.totalCarbs);
  int get dayFats => meals.fold(0, (s, m) => s + m.totalFats);
}

enum MealPlanTimeframe { daily, weekly }

enum DietaryPreference { omnivore, vegetarian, vegan, lowCarb, highProtein }

@immutable
class MealPlan {
  final MealPlanTimeframe timeframe;
  final int targetCalories;
  final DietaryPreference preference;
  final int mealsPerDay;
  final List<DayPlan> days; // 1 for daily, 7 for weekly

  const MealPlan({
    required this.timeframe,
    required this.targetCalories,
    required this.preference,
    required this.mealsPerDay,
    required this.days,
  });
}
