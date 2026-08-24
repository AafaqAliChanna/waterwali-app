import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/profile_service.dart';
import '../services/auth_provider.dart';
import '../theme/app_theme.dart';

class EditEmailScreen extends StatefulWidget {
  const EditEmailScreen({super.key});

  @override
  State<EditEmailScreen> createState() => _EditEmailScreenState();
}

class _EditEmailScreenState extends State<EditEmailScreen> {
  final ProfileService _profileService = ProfileService();
  final TextEditingController _emailController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;
  String? _saveError;
  String? _successMessage;

  String? get _token => Provider.of<AuthProvider>(context, listen: false).token;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final profile = await _profileService.getProfile(_token!);
      if (!mounted) return;
      setState(() {
        _emailController.text = profile.email ?? '';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  bool _isValidEmail(String value) {
    // Simple, deliberately permissive check — full RFC email validation is
    // notoriously overkill and rejects real addresses. The backend is the
    // real source of truth for whether an email is acceptable.
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  Future<void> _save() async {
    final email = _emailController.text.trim();
    if (email.isNotEmpty && !_isValidEmail(email)) {
      setState(() => _saveError = 'Please enter a valid email address.');
      return;
    }
    setState(() {
      _isSaving = true;
      _saveError = null;
      _successMessage = null;
    });
    try {
      await _profileService.updateEmail(_token!, email);
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _successMessage = 'Email updated.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Email Address')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_loadError!, style: const TextStyle(color: AppColors.danger)),
                        const SizedBox(height: AppSpacing.md),
                        ElevatedButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Adding an email is optional. We may use it for account '
                        'recovery and receipts in the future.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email address'),
                      ),
                      if (_saveError != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(_saveError!, style: const TextStyle(color: AppColors.danger)),
                      ],
                      if (_successMessage != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(_successMessage!, style: const TextStyle(color: AppColors.success)),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('SAVE'),
                      ),
                    ],
                  ),
                ),
    );
  }
}