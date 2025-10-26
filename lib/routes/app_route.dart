import 'package:flutter/material.dart';
import 'package:commontable_ai_app/presentation/screens/onboarding_screen.dart';
import 'package:commontable_ai_app/presentation/screens/home_screen.dart';
import 'package:commontable_ai_app/presentation/screens/chatbot_screen.dart';
import 'package:commontable_ai_app/presentation/screens/nutrition_plan_screen.dart';
import 'package:commontable_ai_app/presentation/screens/progress_screen.dart';
import 'package:commontable_ai_app/presentation/screens/settings_screen.dart';
import 'package:commontable_ai_app/presentation/screens/food_identification_screen.dart';

class AppRoutes {
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String chatbot = '/chatbot';
  static const String nutritionAnalysis = '/nutrition-analysis';
  static const String mealPlans = '/meal-plans';
  static const String progress = '/progress';
  static const String settings = '/settings';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case chatbot:
        return MaterialPageRoute(builder: (_) => const ChatbotScreen());
      case nutritionAnalysis:
        return MaterialPageRoute(builder: (_) => const FoodIdentificationScreen());
      case mealPlans:
        return MaterialPageRoute(builder: (_) => const NutritionPlanScreen());
      case progress:
        return MaterialPageRoute(builder: (_) => const ProgressScreen());
      case AppRoutes.settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Page not found')),
          ),
        );
    }
  }
}
