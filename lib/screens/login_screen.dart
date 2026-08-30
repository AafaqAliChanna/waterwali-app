import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:showcaseview/showcaseview.dart';
import '../services/auth_provider.dart';
import '../services/onboarding_service.dart';
import '../services/onboarding_narrator.dart';
import '../services/voice_guide_service.dart';
import '../theme/app_theme.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  final _phoneKey = GlobalKey();
  final _passwordKey = GlobalKey();
  final _loginButtonKey = GlobalKey();
  final _registerKey = GlobalKey();
  bool _tourActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartTour());
  }

  Future<void> _maybeStartTour() async {
    final seen = await OnboardingService.hasSeen('login');
    if (seen || !mounted) return;

    OnboardingNarrator.register(
      narrations: {
        _phoneKey: 'Welcome to WaterWali! Enter the phone number you signed up with here.',
        _passwordKey: 'Then, enter your password here.',
        _loginButtonKey: 'Tap Login to sign in to your account.',
        _registerKey: "New here? Tap Register to create an account as a customer or a driver.",
      },
      lastKey: _registerKey,
      onFinished: () async {
        await OnboardingService.markSeen('login');
        if (mounted) setState(() => _tourActive = false);
      },
    );

    setState(() => _tourActive = true);
    ShowCaseWidget.of(context)
        .startShowCase([_phoneKey, _passwordKey, _loginButtonKey, _registerKey]);
  }

  void _skipTour() {
    ShowCaseWidget.of(context).dismiss();
    VoiceGuideService().stop();
    OnboardingService.markSeen('login');
    OnboardingNarrator.clear();
    setState(() => _tourActive = false);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    VoiceGuideService().stop();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your phone number';
    if (v.length < 10) return 'Enter a valid phone number';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter your password';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(
      _phoneController.text.trim(),
      _passwordController.text,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Login failed. Please try again.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.xxl),
                    Container(
                      width: 84,
                      height: 84,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        child: Image.asset(
                          'assets/icon/app_icon.png',
                          width: 84,
                          height: 84,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('WaterWali', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Sign in to order or deliver water tankers',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    Showcase(
                      key: _phoneKey,
                      description: 'Enter the phone number you signed up with.',
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        validator: _validatePhone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Showcase(
                      key: _passwordKey,
                      description: 'Enter your password here.',
                      child: TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        validator: _validatePassword,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                            onPressed: () =>
                                setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    Showcase(
                      key: _loginButtonKey,
                      description: 'Tap here to sign in to your account.',
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: authProvider.isLoading ? null : _submit,
                          child: authProvider.isLoading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5, color: Colors.white),
                                )
                              : const Text('LOGIN'),
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),
                    Showcase(
                      key: _registerKey,
                      description: "New to WaterWali? Tap here to create an account.",
                      child: TextButton(
                        onPressed: authProvider.isLoading
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (context) => const RegisterScreen()),
                                );
                              },
                        child: const Text("Don't have an account? Register"),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                        );
                      },
                      child: const Text('Forgot Password?'),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
            if (_tourActive)
              Positioned(
                top: AppSpacing.sm,
                right: AppSpacing.sm,
                child: SafeArea(
                  child: TextButton.icon(
                    onPressed: _skipTour,
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Skip'),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}