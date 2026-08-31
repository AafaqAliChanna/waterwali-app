import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:showcaseview/showcaseview.dart';
import '../models/order_model.dart';
import '../models/wallet_model.dart';
import '../services/driver_service.dart';
import '../services/wallet_service.dart';
import '../services/auth_provider.dart';
import '../services/notification_service.dart';
import '../services/onboarding_service.dart';
import '../services/onboarding_narrator.dart';
import '../services/voice_guide_service.dart';
import '../theme/app_theme.dart';
import 'order_history_screen.dart';
import 'active_order_screen.dart';
import 'settings_screen.dart';
import 'inbox_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final WalletService _walletService = WalletService();
  final DriverService _driverService = DriverService();
  final NotificationService _notificationService = NotificationService();
  int _unreadCount = 0;

  bool _isLoadingWallet = true;
  Wallet? _wallet;
  String? _walletError;

  bool _isTogglingOnline = false;
  String? _toggleError;

  bool _isLoadingOrders = false;
  List<Order> _nearbyOrders = [];
  final Set<String> _acceptingOrderIds = {};
  String? _ordersError;

  // A driver can only handle one delivery at a time — while this is
  // non-null, nearby orders are hidden entirely and this is shown instead.
  Order? _activeOrder;
  int _completedCount = 0;
  bool _isLoadingStats = true;

  final _walletCardKey = GlobalKey();
  final _onlineToggleKey = GlobalKey();
  final _historyIconKey = GlobalKey();
  bool _tourActive = false;

  String? get _token =>
      Provider.of<AuthProvider>(context, listen: false).token;

  @override
  void initState() {
    super.initState();
    _loadWallet();
    _loadUnreadCount();
    _loadDriverOrdersAndStats();
  }

  Future<void> _maybeStartTour() async {
    final seen = await OnboardingService.hasSeen('driver_home');
    if (seen || !mounted) return;

    OnboardingNarrator.register(
      narrations: {
        _walletCardKey:
            'This is your wallet. Keep at least 200 rupees here to go online, and top up any time.',
        _onlineToggleKey:
            'Flip this switch to go online. Once you are online, nearby delivery orders will appear here for you to accept.',
        _historyIconKey: 'Tap here to see your past and current deliveries.',
      },
      lastKey: _historyIconKey,
      onFinished: () async {
        await OnboardingService.markSeen('driver_home');
        if (mounted) setState(() => _tourActive = false);
      },
    );

    setState(() => _tourActive = true);
    ShowCaseWidget.of(context)
        .startShowCase([_walletCardKey, _onlineToggleKey, _historyIconKey]);
  }

  void _skipTour() {
    ShowCaseWidget.of(context).dismiss();
    VoiceGuideService().stop();
    OnboardingService.markSeen('driver_home');
    OnboardingNarrator.clear();
    setState(() => _tourActive = false);
  }

  Future<void> _loadUnreadCount() async {
    final token = _token;
    if (token == null) return;
    try {
      final notifications = await _notificationService.getNotifications(token);
      if (!mounted) return;
      setState(() => _unreadCount = notifications.where((n) => !n.read).length);
    } catch (_) {
      // Non-fatal — badge just won't refresh this time.
    }
  }

  Future<void> _openInbox() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const InboxScreen()),
    );
    _loadUnreadCount();
  }

  // Pulls the driver's own order history to find (a) any order currently
  // ACCEPTED/IN_PROGRESS — their one allowed active delivery — and
  // (b) a simple completed-deliveries count for the stats card.
  Future<void> _loadDriverOrdersAndStats() async {
    final token = _token;
    if (token == null) return;
    setState(() => _isLoadingStats = true);
    try {
      final orders = await _driverService.myOrders(token);
      if (!mounted) return;
      Order? active;
      for (final order in orders) {
        if (order.status == 'ACCEPTED' || order.status == 'IN_PROGRESS') {
          active = order;
          break;
        }
      }
      setState(() {
        _activeOrder = active;
        _completedCount = orders.where((o) => o.status == 'COMPLETED').length;
        _isLoadingStats = false;
      });
    } catch (_) {
      // Non-fatal — the driver can still use the rest of the screen even
      // if this particular fetch fails; they just won't see the active-
      // delivery banner or stats until the next successful refresh.
      if (!mounted) return;
      setState(() => _isLoadingStats = false);
    }
  }

  Future<void> _loadWallet() async {
    setState(() {
      _isLoadingWallet = true;
      _walletError = null;
    });
    try {
      final wallet = await _walletService.getWallet(_token!);
      if (!mounted) return;
      setState(() {
        _wallet = wallet;
        _isLoadingWallet = false;
      });
      if (wallet.isOnline && _activeOrder == null) _loadNearbyOrders();
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartTour());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _walletError = e.toString().replaceFirst('Exception: ', '');
        _isLoadingWallet = false;
      });
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadNearbyOrders(),
      _loadDriverOrdersAndStats(),
    ]);
  }

  Future<void> _toggleOnline(bool goOnline) async {
    setState(() {
      _isTogglingOnline = true;
      _toggleError = null;
    });
    try {
      final isOnline = goOnline
          ? await _driverService.goOnline(_token!)
          : await _driverService.goOffline(_token!);

      if (!mounted) return;
      setState(() {
        _wallet = Wallet(balance: _wallet!.balance, isOnline: isOnline);
        _isTogglingOnline = false;
        if (!isOnline) _nearbyOrders = [];
      });

      if (isOnline && _activeOrder == null) _loadNearbyOrders();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _toggleError = e.toString().replaceFirst('Exception: ', '');
        _isTogglingOnline = false;
      });
    }
  }

  Future<void> _loadNearbyOrders() async {
    if (_activeOrder != null) return; // can't accept another anyway
    setState(() {
      _isLoadingOrders = true;
      _ordersError = null;
    });
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final orders = await _driverService.nearbyOrders(
        _token!,
        position.latitude,
        position.longitude,
      );
      if (!mounted) return;
      setState(() {
        _nearbyOrders = orders;
        _isLoadingOrders = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ordersError = e.toString().replaceFirst('Exception: ', '');
        _isLoadingOrders = false;
      });
    }
  }

  Future<void> _acceptOrder(Order order) async {
    if (_acceptingOrderIds.contains(order.id)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Order'),
        content: Text(
          'Accept this ${order.tankerSize.asTankerSizeLabel} order for PKR ${order.price.toStringAsFixed(0)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _acceptingOrderIds.add(order.id));
    try {
      final accepted = await _driverService.acceptOrder(_token!, order.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order #${order.id} accepted!')),
      );
      setState(() => _activeOrder = accepted);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ActiveOrderScreen(orderId: accepted.id, initialOrder: accepted),
        ),
      );
      // Refresh once the driver comes back — the order may now be
      // completed/cancelled, freeing them up to accept a new one.
      _loadDriverOrdersAndStats();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _acceptingOrderIds.remove(order.id));
    }
  }

  Future<void> _showTopupDialog() async {
    final controller = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Top Up Wallet'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount (PKR)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              Navigator.of(context).pop(value);
            },
            child: const Text('Top Up'),
          ),
        ],
      ),
    );

    if (amount == null || amount <= 0 || !mounted) return;

    try {
      final wallet = await _walletService.topup(_token!, amount);
      if (!mounted) return;
      setState(() => _wallet = wallet);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'PENDING':
        return AppColors.warning;
      case 'ACCEPTED':
      case 'IN_PROGRESS':
        return AppColors.primary;
      case 'COMPLETED':
        return AppColors.success;
      case 'CANCELLED':
        return AppColors.danger;
      default:
        return AppColors.textSecondary;
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  void dispose() {
    VoiceGuideService().stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final name = auth.name?.trim().isNotEmpty == true ? auth.name!.trim() : 'Driver';
    final initial = name[0].toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Home'),
        actions: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: 'Inbox',
                onPressed: _openInbox,
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      _unreadCount > 9 ? '9+' : '$_unreadCount',
                      style: const TextStyle(color: Colors.white, fontSize: 9),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          Showcase(
            key: _historyIconKey,
            description:
                'See your past and current deliveries here.\nیہاں اپنی پرانی اور موجودہ ڈیلیوریز دیکھیں۔',
            child: IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'My Deliveries',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => OrderHistoryScreen(
                      title: 'My Deliveries',
                      fetchOrders: (token) => _driverService.myOrders(token),
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoadingWallet
          ? const Center(child: CircularProgressIndicator())
          : _walletError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_walletError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.danger)),
                        const SizedBox(height: AppSpacing.md),
                        ElevatedButton(
                          onPressed: _loadWallet,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: _refreshAll,
                      child: ListView(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: AppColors.primary,
                                child: Text(
                                  initial,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_greeting(),
                                        style: Theme.of(context).textTheme.bodySmall),
                                    Text(name,
                                        style: const TextStyle(
                                            fontSize: 17, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                              if (!_isLoadingStats) _buildCompletedStatPill(),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Showcase(
                            key: _walletCardKey,
                            description:
                                'This is your wallet. Keep at least PKR 200 here to go online.\nیہ آپ کا والٹ ہے۔ آن لائن ہونے کے لیے کم از کم 200 روپے رکھیں۔',
                            child: _buildWalletCard(),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Showcase(
                            key: _onlineToggleKey,
                            description:
                                'Flip this switch to go online and start receiving nearby orders.\nآرڈرز حاصل کرنے کے لیے یہ سوئچ آن کریں۔',
                            child: _buildOnlineToggleCard(),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          if (_activeOrder != null)
                            _buildActiveDeliveryBanner(_activeOrder!)
                          else if (_wallet!.isOnline)
                            _buildNearbyOrdersSection()
                          else
                            _buildOfflinePrompt(),
                        ],
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
    );
  }

  Widget _buildCompletedStatPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_shipping, size: 14, color: AppColors.success),
          const SizedBox(width: 4),
          Text(
            '$_completedCount delivered',
            style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  // Shown instead of nearby orders whenever the driver already has one
  // active delivery — they must finish it before accepting another.
  Widget _buildActiveDeliveryBanner(Order order) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(order.status,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'You have an active delivery',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(
            '${order.tankerSize.asTankerSizeLabel} (~${order.tankerSize.asGallons} gal) • PKR ${order.price.toStringAsFixed(0)}',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Finish this delivery before new orders can appear.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
              ),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        ActiveOrderScreen(orderId: order.id, initialOrder: order),
                  ),
                );
                _loadDriverOrdersAndStats();
              },
              child: const Text('COMPLETE THIS DELIVERY'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -16,
            child: Icon(Icons.water_drop,
                size: 100, color: Colors.white.withValues(alpha: 0.08)),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Wallet Balance',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  'PKR ${_wallet!.balance.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      minimumSize: const Size(64, 44),
                    ),
                    onPressed: _showTopupDialog,
                    child: const Text('Top Up'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineToggleCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: (_wallet!.isOnline ? AppColors.success : AppColors.textSecondary)
                            .withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _wallet!.isOnline ? Icons.bolt : Icons.bolt_outlined,
                        color: _wallet!.isOnline ? AppColors.success : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _wallet!.isOnline ? 'You\'re Online' : 'You\'re Offline',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: _wallet!.isOnline ? AppColors.success : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          _wallet!.isOnline
                              ? 'Receiving nearby orders'
                              : 'Go online to start earning',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
                _isTogglingOnline
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Switch(
                        value: _wallet!.isOnline,
                        activeThumbColor: AppColors.primary,
                        onChanged: (value) => _toggleOnline(value),
                      ),
              ],
            ),
            if (_toggleError != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_toggleError!, style: const TextStyle(color: AppColors.danger)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOfflinePrompt() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl, horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_shipping_outlined, color: AppColors.primary, size: 30),
          ),
          const SizedBox(height: AppSpacing.md),
          Text("You're currently offline",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            'Flip the switch above to start receiving nearby delivery orders.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyOrdersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Nearby Orders', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16)),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isLoadingOrders ? null : _loadNearbyOrders,
            ),
          ],
        ),
        if (_isLoadingOrders)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_ordersError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text(_ordersError!, style: const TextStyle(color: AppColors.danger)),
          )
        else if (_nearbyOrders.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            child: Column(
              children: [
                Icon(Icons.search_off, size: 40, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                const SizedBox(height: AppSpacing.sm),
                Text('No pending orders nearby right now.',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          )
        else
          ..._nearbyOrders.map((order) => Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: const Icon(Icons.local_shipping_outlined, color: AppColors.primary),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _statusColor(order.status),
                                    borderRadius: BorderRadius.circular(AppRadius.pill),
                                  ),
                                  child: Text(
                                    order.status,
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text('${order.tankerSize.asTankerSizeLabel} (~${order.tankerSize.asGallons} gal)'),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text('PKR ${order.price.toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _acceptingOrderIds.contains(order.id)
                            ? null
                            : () => _acceptOrder(order),
                        child: _acceptingOrderIds.contains(order.id)
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Accept'),
                      ),
                    ],
                  ),
                ),
              )),
      ],
    );
  }
}