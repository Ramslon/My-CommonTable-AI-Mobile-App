import 'package:flutter/material.dart';
import 'package:commontable_ai_app/presentation/screens/onboarding_screen.dart';
import 'package:commontable_ai_app/presentation/screens/home_screen.dart';
import 'package:commontable_ai_app/routes/app_route.dart';
import 'package:commontable_ai_app/presentation/widgets/biometric_gate.dart';
import 'package:commontable_ai_app/core/services/firebase_boot.dart';
import 'package:commontable_ai_app/core/services/notifications_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:commontable_ai_app/core/services/offline_cache_service.dart';
import 'package:commontable_ai_app/core/services/accessibility_settings.dart';
import 'package:commontable_ai_app/core/services/offline_sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Register FCM background handler as early as possible
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  // Initialize Firebase defensively; app can still run if not configured.
  await FirebaseBoot.init();
  // Set up notifications; safe to call even if FCM not fully configured.
  try {
    await NotificationsService.init();
  } catch (_) {}
  // Init Hive for offline caching
  await Hive.initFlutter();
  await OfflineCacheService().init();
  // Load accessibility prefs
  await AccessibilitySettings().init();
  // Start connectivity-based auto-sync
  OfflineSyncService().start();
  runApp(const CommontableAIApp());
}

class CommontableAIApp extends StatelessWidget {
  const CommontableAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BiometricGate(
      child: AnimatedBuilder(
        animation: AccessibilitySettings(),
        builder: (context, _) => MaterialApp(
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
          builder: (context, child) {
            final scale = AccessibilitySettings().textScaleFactor;
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(textScaleFactor: scale),
              child: child!,
            );
          },
        ),
      ),
    );
  }
}
