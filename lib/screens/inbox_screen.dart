import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../services/auth_provider.dart';
import '../theme/app_theme.dart';
import 'active_order_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final NotificationService _notificationService = NotificationService();

  bool _isLoading = true;
  List<AppNotification> _notifications = [];
  String? _error;

  String? get _token => Provider.of<AuthProvider>(context, listen: false).token;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final notifications = await _notificationService.getNotifications(_token!);
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted) return;
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    final hasUnread = _notifications.any((n) => !n.read);
    if (!hasUnread) return;
    // Optimistic update — the list feels instant, and we just re-load
    // quietly in the background in case the server disagrees.
    setState(() {
      _notifications = _notifications.map((n) => n.copyWith(read: true)).toList();
    });
    try {
      await _notificationService.markAllAsRead(_token!);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      _load(); // fall back to the real server state
    }
  }

  Future<void> _handleTap(AppNotification notification) async {
    if (!notification.read) {
      setState(() {
        _notifications = _notifications
            .map((n) => n.id == notification.id ? n.copyWith(read: true) : n)
            .toList();
      });
      // Fire-and-forget — worst case the badge count is off by one until
      // the next load, not worth blocking navigation over.
      _notificationService.markAsRead(_token!, notification.id).catchError((_) {});
    }
    if (notification.orderId != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ActiveOrderScreen(orderId: notification.orderId!),
        ),
      );
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'ORDER_ACCEPTED':
        return Icons.check_circle_outline;
      case 'ORDER_DELIVERED':
        return Icons.home_outlined;
      case 'ORDER_CANCELLED':
        return Icons.cancel_outlined;
      case 'WALLET_TOPUP':
        return Icons.account_balance_wallet_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'ORDER_ACCEPTED':
        return AppColors.primary;
      case 'ORDER_DELIVERED':
        return AppColors.success;
      case 'ORDER_CANCELLED':
        return AppColors.danger;
      case 'WALLET_TOPUP':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  String _formatDate(String createdAt) {
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _notifications.any((n) => !n.read);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, style: const TextStyle(color: AppColors.danger)),
                        const SizedBox(height: AppSpacing.md),
                        ElevatedButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _notifications.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.notifications_none, size: 48, color: AppColors.textSecondary),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              "You're all caught up. Nothing here yet.",
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: _notifications.length,
                        separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) => _buildNotificationTile(_notifications[index]),
                      ),
                    ),
    );
  }

  Widget _buildNotificationTile(AppNotification n) {
    final color = _colorFor(n.type);
    return Material(
      color: n.read ? AppColors.surface : AppColors.primary.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => _handleTap(n),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(_iconFor(n.type), color: color, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            n.title,
                            style: TextStyle(
                              fontWeight: n.read ? FontWeight.w500 : FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (!n.read)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: AppSpacing.xs),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(n.body, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(n.createdAt),
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}