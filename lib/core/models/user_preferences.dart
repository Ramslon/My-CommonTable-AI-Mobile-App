import 'dart:convert';

/// Basic dietary preference enum
enum DietaryPreference {
  omnivore,
  vegetarian,
  vegan,
  pescatarian,
  keto,
  paleo,
}

/// User preferences for generating personalized meal plans
class UserPreferences {
  final String goal; // e.g., "lose", "maintain", "gain"
  final List<String> allergies; // e.g., ["peanut", "gluten"]
  final List<String> dislikes; // items the user dislikes
  final double? dailyBudget; // approximate budget in local currency
  final String? region; // region/cuisine preference
  final DietaryPreference dietaryPreference;
  final int mealsPerDay;
  final int? dailyCaloriesTarget;

  const UserPreferences({
    required this.goal,
    this.allergies = const [],
    this.dislikes = const [],
    this.dailyBudget,
    this.region,
    this.dietaryPreference = DietaryPreference.omnivore,
    this.mealsPerDay = 3,
    this.dailyCaloriesTarget,
  });

  UserPreferences copyWith({
    String? goal,
    List<String>? allergies,
    List<String>? dislikes,
    double? dailyBudget,
    String? region,
    DietaryPreference? dietaryPreference,
    int? mealsPerDay,
    int? dailyCaloriesTarget,
  }) {
    return UserPreferences(
      goal: goal ?? this.goal,
      allergies: allergies ?? this.allergies,
      dislikes: dislikes ?? this.dislikes,
      dailyBudget: dailyBudget ?? this.dailyBudget,
      region: region ?? this.region,
      dietaryPreference: dietaryPreference ?? this.dietaryPreference,
      mealsPerDay: mealsPerDay ?? this.mealsPerDay,
      dailyCaloriesTarget: dailyCaloriesTarget ?? this.dailyCaloriesTarget,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'goal': goal,
      'allergies': allergies,
      'dislikes': dislikes,
      'dailyBudget': dailyBudget,
      'region': region,
      'dietaryPreference': dietaryPreference.name,
      'mealsPerDay': mealsPerDay,
      'dailyCaloriesTarget': dailyCaloriesTarget,
    };
  }

  factory UserPreferences.fromMap(Map<String, dynamic> map) {
    return UserPreferences(
      goal: (map['goal'] ?? 'maintain').toString(),
      allergies: (map['allergies'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      dislikes: (map['dislikes'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      dailyBudget: (map['dailyBudget'] is num) ? (map['dailyBudget'] as num).toDouble() : null,
      region: map['region']?.toString(),
      dietaryPreference: _dietFrom(map['dietaryPreference']?.toString()),
      mealsPerDay: (map['mealsPerDay'] is num) ? (map['mealsPerDay'] as num).toInt() : 3,
      dailyCaloriesTarget: (map['dailyCaloriesTarget'] is num)
          ? (map['dailyCaloriesTarget'] as num).toInt()
          : null,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory UserPreferences.fromJson(String source) =>
      UserPreferences.fromMap(jsonDecode(source) as Map<String, dynamic>);

  static DietaryPreference _dietFrom(String? value) {
    switch (value) {
      case 'vegetarian':
        return DietaryPreference.vegetarian;
      case 'vegan':
        return DietaryPreference.vegan;
      case 'pescatarian':
        return DietaryPreference.pescatarian;
      case 'keto':
        return DietaryPreference.keto;
      case 'paleo':
        return DietaryPreference.paleo;
      case 'omnivore':
      default:
        return DietaryPreference.omnivore;
    }
  }
}
