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

  Map<String, dynamic> toMap() => {
        'name': name,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fats': fats,
        'servings': servings,
      };

  factory MealItem.fromMap(Map<String, dynamic> map) => MealItem(
        name: map['name'] as String,
        calories: (map['calories'] ?? 0) as int,
        protein: (map['protein'] ?? 0) as int,
        carbs: (map['carbs'] ?? 0) as int,
        fats: (map['fats'] ?? 0) as int,
        servings: (map['servings'] ?? 1.0).toDouble(),
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

  Map<String, dynamic> toMap() => {
        'title': title,
        'items': items.map((i) => i.toMap()).toList(),
      };

  factory Meal.fromMap(Map<String, dynamic> map) => Meal(
        title: (map['title'] ?? '') as String,
        items: ((map['items'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => MealItem.fromMap(m.cast<String, dynamic>()))
            .toList(),
      );
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

  Map<String, dynamic> toMap() => {
        'label': label,
        'meals': meals.map((m) => m.toMap()).toList(),
      };

  factory DayPlan.fromMap(Map<String, dynamic> map) => DayPlan(
        label: (map['label'] ?? '') as String,
        meals: ((map['meals'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => Meal.fromMap(m.cast<String, dynamic>()))
            .toList(),
      );
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

  // --- Serialization helpers for offline storage ---
  Map<String, dynamic> toMap() => {
        'timeframe': timeframe.name,
        'targetCalories': targetCalories,
        'preference': preference.name,
        'mealsPerDay': mealsPerDay,
        'days': days.map((d) => d.toMap()).toList(),
      };

  static MealPlan fromMap(Map<String, dynamic> map) => MealPlan(
        timeframe: MealPlanTimeframe.values.firstWhere(
          (e) => e.name == map['timeframe'],
          orElse: () => MealPlanTimeframe.daily,
        ),
        targetCalories: (map['targetCalories'] ?? 2000) as int,
        preference: DietaryPreference.values.firstWhere(
          (e) => e.name == map['preference'],
          orElse: () => DietaryPreference.omnivore,
        ),
        mealsPerDay: (map['mealsPerDay'] ?? 3) as int,
        days: ((map['days'] as List?) ?? const [])
    .whereType<Map>()
    .map((m) => DayPlan.fromMap(m.cast<String, dynamic>()))
    .toList(),
      );
}
