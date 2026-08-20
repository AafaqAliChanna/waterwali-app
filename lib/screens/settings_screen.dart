import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isRefreshing = true;
  String? _refreshError;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _refresh();
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
    } catch (e) {
      if (!mounted) return;
      // Non-fatal — we still have whatever the provider already had cached
      // from login, so the screen stays usable, just possibly a bit stale.
      setState(() {
        _isRefreshing = false;
        _refreshError = 'Could not refresh profile. Showing last known info.';
      });
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
    if (confirmed == true) await auth.logout();
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
    }
    // On success, AuthProvider.logout() already ran inside deleteAccount(),
    // so main.dart's Consumer<AuthProvider> will switch back to the login
    // screen automatically — no manual navigation needed here.
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final initial = (auth.name ?? '?').trim().isNotEmpty
        ? auth.name!.trim()[0].toUpperCase()
        : '?';

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Card(
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
                          auth.name ?? 'WaterWali User',
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
          if (_refreshError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_refreshError!, style: const TextStyle(color: AppColors.warning, fontSize: 12)),
          ],
          const SizedBox(height: AppSpacing.lg),

          Card(
            child: ListTile(
              leading: const Icon(Icons.logout_outlined),
              title: const Text('Logout'),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: _confirmLogout,
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
          Card(
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
        ],
      ),
    );
  }
}