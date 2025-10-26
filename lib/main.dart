import 'package:flutter/material.dart';
import 'package:commontable_ai_app/presentation/screens/onboarding_screen.dart';
import 'package:commontable_ai_app/presentation/screens/home_screen.dart';
import 'package:commontable_ai_app/routes/app_route.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CommontableAIApp());
}

class CommontableAIApp extends StatelessWidget {
  const CommontableAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Commontable AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          bodyMedium: TextStyle(fontSize: 16),
        ),
      ),
      // Define app routes in a central place
      initialRoute: AppRoutes.onboarding,
      routes: {
        AppRoutes.onboarding: (context) => const OnboardingScreen(),
        AppRoutes.home: (context) => const HomeScreen(),
      },
    );
  }
}
