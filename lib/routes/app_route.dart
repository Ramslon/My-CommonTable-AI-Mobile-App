import 'package:flutter/material.dart';
import 'package:commontable_ai_app/presentation/screens/onboarding_screen.dart';
import 'package:commontable_ai_app/presentation/screens/home_screen.dart';
import 'package:commontable_ai_app/presentation/screens/nutrition_plan_screen.dart';
import 'package:commontable_ai_app/presentation/screens/progress_dashboard_screen.dart';
import 'package:commontable_ai_app/presentation/screens/settings_screen.dart';
import 'package:commontable_ai_app/presentation/screens/nutrition_analysis_screen.dart';
import 'package:commontable_ai_app/presentation/screens/real_chatbot_screen.dart'
    as chat;
import 'package:commontable_ai_app/presentation/screens/student_features_screen.dart';
import 'package:commontable_ai_app/presentation/screens/low_income_features_screen.dart';
import 'package:commontable_ai_app/presentation/screens/premium_features_screen.dart';
import 'package:commontable_ai_app/presentation/screens/billing_screen.dart';
import 'package:commontable_ai_app/presentation/screens/privacy_settings_screen.dart';
import 'package:commontable_ai_app/presentation/screens/community_feed_screen.dart';
import 'package:commontable_ai_app/presentation/screens/offline_accessibility_screen.dart';

class AppRoutes {
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String chatbot = '/chatbot';
  static const String nutritionAnalysis = '/nutrition-analysis';
  static const String mealPlans = '/meal-plans';
  static const String progressDashboard = '/progressDashboard';
  static const String settings = '/settings';
  static const String studentFeatures = '/student-features';
  static const String lowIncomeFeatures = '/low-income-features';
  static const String premiumFeatures = '/premium-features';
  static const String billing = '/billing';
  static const String privacySettings = '/privacy-settings';
  static const String socialCommunity = '/community';
  static const String offlineAccessibility = '/offline-accessibility';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case chatbot:
        return MaterialPageRoute(
          builder: (_) => const chat.RealChatbotScreen(),
        );
      case nutritionAnalysis:
        return MaterialPageRoute(
          builder: (_) => const NutritionAnalysisScreen(),
        );
      case mealPlans:
        return MaterialPageRoute(builder: (_) => const NutritionPlanScreen());
      case progressDashboard:
        return MaterialPageRoute(
          builder: (_) => const ProgressDashboardScreen(),
        );
      case studentFeatures:
        return MaterialPageRoute(builder: (_) => const StudentFeaturesScreen());
      case lowIncomeFeatures:
        return MaterialPageRoute(
          builder: (_) => const LowIncomeFeaturesScreen(),
        );
      case premiumFeatures:
        return MaterialPageRoute(builder: (_) => const PremiumFeaturesScreen());
      case billing:
        return MaterialPageRoute(builder: (_) => const BillingScreen());
      case privacySettings:
        return MaterialPageRoute(builder: (_) => const PrivacySettingsScreen());
      case socialCommunity:
        return MaterialPageRoute(builder: (_) => const CommunityFeedScreen());
      case offlineAccessibility:
        return MaterialPageRoute(builder: (_) => const OfflineAccessibilityScreen());
      case AppRoutes.settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      default:
        return MaterialPageRoute(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('Page not found'))),
        );
    }
  }
}
