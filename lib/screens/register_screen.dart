import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:showcaseview/showcaseview.dart';
import '../services/auth_provider.dart';
import '../services/onboarding_service.dart';
import '../services/onboarding_narrator.dart';
import '../services/voice_guide_service.dart';
import '../theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _role = 'CUSTOMER';
  bool _obscurePassword = true;

  final _nameKey = GlobalKey();
  final _phoneKey = GlobalKey();
  final _emailKey = GlobalKey();
  final _passwordKey = GlobalKey();
  final _roleKey = GlobalKey();
  final _createButtonKey = GlobalKey();
  bool _tourActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartTour());
  }

  Future<void> _maybeStartTour() async {
    final seen = await OnboardingService.hasSeen('register');
    if (seen || !mounted) return;

    // Spoken narration stays English-only — the on-device TTS engine can't
    // pronounce Urdu script correctly. The Urdu shown in each tooltip is
    // for reading, not for the voice to speak.
    OnboardingNarrator.register(
      narrations: {
        _nameKey: "Let's create your account. Start by entering your full name.",
        _phoneKey: 'Now enter your phone number. This is how you will log in.',
        _emailKey: "Add your email too. It's needed in case you ever forget your password.",
        _passwordKey: 'Choose a password with at least 6 characters.',
        _roleKey: 'Tell us if you are a Customer looking for water, or a Driver delivering it.',
        _createButtonKey: "When you're ready, tap here to create your account.",
      },
      lastKey: _createButtonKey,
      onFinished: () async {
        await OnboardingService.markSeen('register');
        if (mounted) setState(() => _tourActive = false);
      },
    );

    setState(() => _tourActive = true);
    ShowCaseWidget.of(context).startShowCase(
      [_nameKey, _phoneKey, _emailKey, _passwordKey, _roleKey, _createButtonKey],
    );
  }

  void _skipTour() {
    ShowCaseWidget.of(context).dismiss();
    VoiceGuideService().stop();
    OnboardingService.markSeen('register');
    OnboardingNarrator.clear();
    setState(() => _tourActive = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    VoiceGuideService().stop();
    super.dispose();
  }

  String? _validateName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your full name';
    if (v.length < 2) return 'Name is too short';
    return null;
  }

  String? _validatePhone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your phone number';
    if (v.length < 10) return 'Enter a valid phone number';
    return null;
  }

  String? _validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your email address';
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
    if (!valid) return 'Enter a valid email address';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter a password';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.register(
      _nameController.text.trim(),
      _phoneController.text.trim(),
      _passwordController.text,
      _role,
      _emailController.text.trim(),
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Could not create account. Please try again.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
    // On success we don't navigate manually — main.dart's Consumer<AuthProvider>
    // sees isAuthenticated flip to true and switches screens automatically.
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Showcase(
                      key: _nameKey,
                      description: 'Enter your full name.\nاپنا پورا نام یہاں درج کریں۔',
                      child: TextFormField(
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        validator: _validateName,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Showcase(
                      key: _phoneKey,
                      description:
                          'Enter your phone number. You will use it to log in.\nاپنا فون نمبر درج کریں، آپ اسی سے لاگ ان کریں گے۔',
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
                      key: _emailKey,
                      description:
                          'Add your email address.\nاپنا ای میل ایڈریس یہاں درج کریں۔',
                      child: TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: _validateEmail,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Showcase(
                      key: _passwordKey,
                      description:
                          'Choose a password (at least 6 characters).\nایک پاس ورڈ بنائیں (کم از کم 6 حروف)۔',
                      child: TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        validator: _validatePassword,
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
                    const SizedBox(height: AppSpacing.lg),

                    Text('I am a', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: AppSpacing.sm),
                    Showcase(
                      key: _roleKey,
                      description:
                          'Choose whether you are a Customer or a Driver.\nمنتخب کریں کہ آپ گاہک ہیں یا ڈرائیور۔',
                      child: Row(
                        children: [
                          Expanded(child: _RoleOption(
                            label: 'Customer',
                            icon: Icons.person_outline,
                            selected: _role == 'CUSTOMER',
                            onTap: () => setState(() => _role = 'CUSTOMER'),
                          )),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: _RoleOption(
                            label: 'Driver',
                            icon: Icons.local_shipping_outlined,
                            selected: _role == 'DRIVER',
                            onTap: () => setState(() => _role = 'DRIVER'),
                          )),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    Showcase(
                      key: _createButtonKey,
                      description:
                          'Tap here to create your account.\nاکاؤنٹ بنانے کے لیے یہاں ٹیپ کریں۔',
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
                              : const Text('CREATE ACCOUNT'),
                        ),
                      ),
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

class _RoleOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}