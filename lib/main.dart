import 'package:flutter/material.dart';
import 'package:commontable_ai_app/presentation/screens/onboarding_screen.dart';
import 'package:commontable_ai_app/presentation/screens/home_screen.dart';
import 'package:commontable_ai_app/routes/app_route.dart';
import 'package:commontable_ai_app/presentation/widgets/biometric_gate.dart';
import 'package:commontable_ai_app/core/services/firebase_boot.dart';
import 'package:commontable_ai_app/core/services/notifications_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase defensively; app can still run if not configured.
  await FirebaseBoot.init();
  // Set up notifications; safe to call even if FCM not fully configured.
  try {
    await NotificationsService.init();
  } catch (_) {}
  runApp(const CommontableAIApp());
}

class CommontableAIApp extends StatelessWidget {
  const CommontableAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BiometricGate(
      child: MaterialApp(
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
      onGenerateRoute: AppRoutes.generateRoute,
    ),
    );
  }
}
