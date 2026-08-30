import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/driver_home_screen.dart';
import 'screens/splash_screen.dart';
import 'services/session_manager.dart';
import 'theme/app_theme.dart';
import 'package:showcaseview/showcaseview.dart';
import 'services/onboarding_narrator.dart';
import 'services/voice_guide_service.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => AuthProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
            return ShowCaseWidget(
      onStart: (index, key) {
        final text = OnboardingNarrator.textFor(key);
        if (text != null) VoiceGuideService().speak(text);
      },
      onComplete: (index, key) {
        if (key == OnboardingNarrator.lastKey) {
          OnboardingNarrator.onFinished?.call();
          OnboardingNarrator.clear();
        }
      },
      builder: (context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'WaterWali',
        theme: AppTheme.light,
        home: const AuthGate(),
      ),
    );
  }
}

// Runs auto-login once at startup, then hands off to the same
// role-based routing as before.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
    @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    // Any service that hits a 401 calls this, forcing an immediate logout
    // no matter which screen the user happens to be on at the time.
    SessionManager.onSessionExpired = auth.logout;

    // Auto-login can resolve almost instantly (no saved token) or after a
    // real network round trip (validating a saved token) — without a
    // minimum wait, the splash screen would just flash for a single frame
    // in the fast case instead of actually being visible.
    Future.wait([
      auth.tryAutoLogin(),
      Future.delayed(const Duration(seconds: 2)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.isInitializing) {
          return const SplashScreen();
        }
        if (!authProvider.isAuthenticated) {
          return const LoginScreen();
        }
        return authProvider.isDriver ? const DriverHomeScreen() : const HomeScreen();
      },
    );
  }
}