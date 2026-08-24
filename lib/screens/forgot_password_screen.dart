import 'package:flutter/material.dart';
import '../services/password_reset_service.dart';
import '../theme/app_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final PasswordResetService _resetService = PasswordResetService();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();

  // Step 1 = enter phone, request code. Step 2 = enter code + new password.
  int _step = 1;
  bool _isLoading = false;
  String? _error;
  String? _successMessage;

  Future<void> _requestCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Please enter your phone number.');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await _resetService.requestOtp(phone);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _step = 2;
        _successMessage = 'If that number is registered, a code has been sent to its email.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _resetPassword() async {
    final otp = _otpController.text.trim();
    final newPassword = _newPasswordController.text;
    if (otp.isEmpty || newPassword.isEmpty) {
      setState(() => _error = 'Please fill in both fields.');
      return;
    }
    if (newPassword.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await _resetService.resetPassword(
        _phoneController.text.trim(),
        otp,
        newPassword,
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _successMessage = 'Password reset! You can now log in.';
      });
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_step == 1) ...[
              const Text(
                "Enter your phone number and we'll send a verification code "
                "to the email address on your account.",
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone Number'),
              ),
            ] else ...[
              const Text(
                'Enter the code sent to your email and choose a new password.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Verification Code'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            if (_successMessage != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_successMessage!, style: const TextStyle(color: AppColors.success)),
            ],
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : (_step == 1 ? _requestCode : _resetPassword),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(_step == 1 ? 'SEND CODE' : 'RESET PASSWORD'),
            ),
            if (_step == 2) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () => setState(() {
                          _step = 1;
                          _error = null;
                          _successMessage = null;
                        }),
                child: const Text('Use a different number'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}