import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_profile_model.dart';
import '../services/profile_service.dart';
import '../services/auth_provider.dart';
import '../theme/app_theme.dart';

class EditNameScreen extends StatefulWidget {
  const EditNameScreen({super.key});

  @override
  State<EditNameScreen> createState() => _EditNameScreenState();
}

class _EditNameScreenState extends State<EditNameScreen> {
  final ProfileService _profileService = ProfileService();
  final TextEditingController _nameController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUndoing = false;
  String? _loadError;
  String? _actionError;
  String? _successMessage;
  UserProfile? _profile;

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
        _profile = profile;
        _nameController.text = profile.name;
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

  // Purely a UX hint for the user — the server is the real source of truth
  // (429 if this is wrong for any reason, e.g. clock drift or an admin
  // manually resetting the cooldown).
  bool get _within30Days {
    final last = _profile?.lastNameChangeAt;
    if (last == null) return false;
    try {
      final lastDate = DateTime.parse(last);
      return DateTime.now().difference(lastDate).inDays < 30;
    } catch (_) {
      return false;
    }
  }

  bool get _canUndo {
    final deadline = _profile?.undoDeadline;
    if (deadline == null) return false;
    try {
      return DateTime.now().isBefore(DateTime.parse(deadline));
    } catch (_) {
      return false;
    }
  }

  String get _nextAllowedDateText {
    final last = _profile?.lastNameChangeAt;
    if (last == null) return '';
    try {
      final nextDate = DateTime.parse(last).add(const Duration(days: 30));
      return '${nextDate.day}/${nextDate.month}/${nextDate.year}';
    } catch (_) {
      return '';
    }
  }

  Future<void> _save() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      setState(() => _actionError = 'Name cannot be empty.');
      return;
    }
    setState(() {
      _isSaving = true;
      _actionError = null;
      _successMessage = null;
    });
    try {
      final updated = await _profileService.updateName(_token!, newName);
      if (!mounted) return;
      setState(() {
        _profile = updated;
        _isSaving = false;
        _successMessage = 'Name updated. You can undo this within 24 hours if needed.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _actionError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _undo() async {
    setState(() {
      _isUndoing = true;
      _actionError = null;
      _successMessage = null;
    });
    try {
      final reverted = await _profileService.undoNameChange(_token!);
      if (!mounted) return;
      setState(() {
        _profile = reverted;
        _nameController.text = reverted.name;
        _isUndoing = false;
        _successMessage = 'Name change undone.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUndoing = false;
        _actionError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Name')),
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
                      TextField(
                        controller: _nameController,
                        enabled: !_within30Days,
                        decoration: const InputDecoration(labelText: 'Full Name'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (_within30Days)
                        Text(
                          'You can next change your name on $_nextAllowedDateText.',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        )
                      else
                        const Text(
                          'You can change your name once every 30 days.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      if (_actionError != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(_actionError!, style: const TextStyle(color: AppColors.danger)),
                      ],
                      if (_successMessage != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(_successMessage!, style: const TextStyle(color: AppColors.success)),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      if (!_within30Days)
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
                      if (_canUndo) ...[
                        const SizedBox(height: AppSpacing.sm),
                        OutlinedButton(
                          onPressed: _isUndoing ? null : _undo,
                          child: _isUndoing
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('UNDO LAST CHANGE'),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}