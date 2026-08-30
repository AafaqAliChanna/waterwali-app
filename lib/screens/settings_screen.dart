import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:showcaseview/showcaseview.dart';
import '../services/auth_provider.dart';
import '../services/onboarding_service.dart';
import '../services/onboarding_narrator.dart';
import '../services/voice_guide_service.dart';
import '../theme/app_theme.dart';
import 'about_screen.dart';
import '../data/legal_content.dart';
import 'legal_document_screen.dart';
import 'edit_email_screen.dart';
import 'edit_name_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isRefreshing = true;
  String? _refreshError;
  bool _isDeleting = false;

  final _profileCardKey = GlobalKey();
  final _settingsListKey = GlobalKey();
  final _dangerZoneKey = GlobalKey();
  bool _tourActive = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _maybeStartTour() async {
    final seen = await OnboardingService.hasSeen('settings');
    if (seen || !mounted) return;

    OnboardingNarrator.register(
      narrations: {
        _profileCardKey: 'This shows your account details.',
        _settingsListKey:
            'Here you can edit your name, email, and view our terms and policies.',
        _dangerZoneKey:
            'Be careful here — deleting your account permanently erases your data and cannot be undone.',
      },
      lastKey: _dangerZoneKey,
      onFinished: () async {
        await OnboardingService.markSeen('settings');
        if (mounted) setState(() => _tourActive = false);
      },
    );

    setState(() => _tourActive = true);
    ShowCaseWidget.of(context)
        .startShowCase([_profileCardKey, _settingsListKey, _dangerZoneKey]);
  }

  void _skipTour() {
    ShowCaseWidget.of(context).dismiss();
    VoiceGuideService().stop();
    OnboardingService.markSeen('settings');
    OnboardingNarrator.clear();
    setState(() => _tourActive = false);
  }

  Future<void> _refresh() async {
    setState(() {
      _isRefreshing = true;
      _refreshError = null;
    });
    try {
      await Provider.of<AuthProvider>(context, listen: false).refreshProfile();
      if (!mounted) return;
      setState(() => _isRefreshing = false);
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartTour());
    } catch (e) {
      if (!mounted) return;
      // Non-fatal — we still have whatever the provider already had cached
      // from login, so the screen stays usable, just possibly a bit stale.
      setState(() {
        _isRefreshing = false;
        _refreshError = 'Could not refresh profile. Showing last known info.';
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartTour());
    }
  }

  Future<void> _confirmLogout() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await auth.logout();
    if (!mounted) return;
    // logout() swaps AuthGate's content to LoginScreen underneath, but
    // SettingsScreen is a pushed route sitting on top of it — without this,
    // that swap is invisible and you're stuck looking at a now-empty
    // SettingsScreen instead of actually landing on the login screen.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _confirmDeleteAccount() async {
    final controller = TextEditingController();
    // Extra friction is intentional here — this is irreversible and wipes
    // a real person's order history, wallet, and account. A plain
    // Yes/Cancel dialog is too easy to tap through by accident.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final canConfirm = controller.text.trim() == 'DELETE';
          return AlertDialog(
            title: const Text('Delete Account'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This permanently deletes your account, order history, and wallet balance. This cannot be undone.',
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Type DELETE to confirm.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: 'DELETE'),
                  onChanged: (_) => setDialogState(() {}),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                onPressed: canConfirm ? () => Navigator.of(context).pop(true) : null,
                child: const Text('Delete Forever'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.deleteAccount();
    if (!mounted) return;
    setState(() => _isDeleting = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Could not delete account. Please try again.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    // deleteAccount() already ran logout() internally, which swaps
    // AuthGate's content underneath — same reasoning as _confirmLogout
    // above, this pop is what actually makes that visible.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  void dispose() {
    VoiceGuideService().stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final displayName = auth.name?.trim() ?? '';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Showcase(
                key: _profileCardKey,
                description:
                    'This shows your account details.\nیہاں آپ کی اکاؤنٹ کی تفصیلات ہیں۔',
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.primary,
                          child: Text(
                            initial,
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName.isNotEmpty ? displayName : 'WaterWali User',
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              if (_isRefreshing)
                                Text('Loading...', style: Theme.of(context).textTheme.bodySmall)
                              else
                                Text(
                                  auth.phone ?? 'Phone number unavailable',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(AppRadius.pill),
                                ),
                                child: Text(
                                  auth.isDriver ? 'Driver' : 'Customer',
                                  style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_refreshError != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(_refreshError!, style: const TextStyle(color: AppColors.warning, fontSize: 12)),
              ],
              const SizedBox(height: AppSpacing.lg),

              Showcase(
                key: _settingsListKey,
                description:
                    'Edit your name, email, and view our terms and policies here.\nیہاں اپنا نام، ای میل تبدیل کریں اور شرائط پڑھیں۔',
                child: Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.badge_outlined),
                        title: const Text('Edit Name'),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const EditNameScreen()),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.email_outlined),
                        title: const Text('Email Address'),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const EditEmailScreen()),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: const Text('About'),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const AboutScreen()),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: const Text('Terms of Service'),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const LegalDocumentScreen(
                                title: 'Terms of Service',
                                content: termsOfServiceText,
                              ),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.privacy_tip_outlined),
                        title: const Text('Privacy Policy'),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const LegalDocumentScreen(
                                title: 'Privacy Policy',
                                content: privacyPolicyText,
                              ),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.logout_outlined),
                        title: const Text('Logout'),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: _confirmLogout,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),
              Text(
                'DANGER ZONE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.danger.withValues(alpha: 0.8),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Showcase(
                key: _dangerZoneKey,
                description:
                    'Be careful here — deleting your account is permanent and cannot be undone.\nیہاں احتیاط کریں — اکاؤنٹ ڈیلیٹ کرنا مستقل ہے۔',
                child: Card(
                  child: ListTile(
                    leading: _isDeleting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.danger),
                          )
                        : const Icon(Icons.delete_forever_outlined, color: AppColors.danger),
                    title: const Text('Delete Account', style: TextStyle(color: AppColors.danger)),
                    subtitle: const Text('Permanently erase your account and data'),
                    onTap: _isDeleting ? null : _confirmDeleteAccount,
                  ),
                ),
              ),
            ],
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
    );
  }
}