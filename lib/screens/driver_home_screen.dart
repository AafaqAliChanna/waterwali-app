import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../models/order_model.dart';
import '../models/wallet_model.dart';
import '../services/driver_service.dart';
import '../services/wallet_service.dart';
import '../services/auth_provider.dart';
import 'order_history_screen.dart';
import 'active_order_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final WalletService _walletService = WalletService();
  final DriverService _driverService = DriverService();

  bool _isLoadingWallet = true;
  Wallet? _wallet;
  String? _walletError;

  bool _isTogglingOnline = false;
  String? _toggleError;

  bool _isLoadingOrders = false;
  List<Order> _nearbyOrders = [];
  final Set<String> _acceptingOrderIds = {};
  String? _ordersError;

  String? get _token =>
      Provider.of<AuthProvider>(context, listen: false).token;

  @override
  void initState() {
    super.initState();
    _loadWallet();
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
      // If the driver was already online from a previous session, load
      // nearby orders right away.
      if (wallet.isOnline) _loadNearbyOrders();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _walletError = e.toString().replaceFirst('Exception: ', '');
        _isLoadingWallet = false;
      });
    }
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
        if (!isOnline) _nearbyOrders = []; // clear list when going offline
      });

      if (isOnline) _loadNearbyOrders();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _toggleError = e.toString().replaceFirst('Exception: ', '');
        _isTogglingOnline = false;
      });
    }
  }

  Future<void> _loadNearbyOrders() async {
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
    if (_acceptingOrderIds.contains(order.id)) return; // already in flight
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
      _loadNearbyOrders(); // refresh list — that order is no longer PENDING
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ActiveOrderScreen(orderId: accepted.id, initialOrder: accepted),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFD32F2F),
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
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'PENDING':
        return const Color(0xFFF57C00);
      case 'ACCEPTED':
      case 'IN_PROGRESS':
        return const Color(0xFF1E88E5);
      case 'COMPLETED':
        return const Color(0xFF2E7D32);
      case 'CANCELLED':
        return const Color(0xFFD32F2F);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        title: const Text('Driver Home'),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
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
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => auth.logout(),
          ),
        ],
      ),
      
      body: _isLoadingWallet
          ? const Center(child: CircularProgressIndicator())
          : _walletError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_walletError!,
                            style: const TextStyle(color: Color(0xFFD32F2F))),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadWallet,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNearbyOrders,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildWalletCard(),
                      const SizedBox(height: 16),
                      _buildOnlineToggleCard(),
                      const SizedBox(height: 16),
                      if (_wallet!.isOnline) _buildNearbyOrdersSection(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildWalletCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Wallet Balance',
                    style: TextStyle(color: Colors.black54, fontSize: 13)),
                Text(
                  'PKR ${_wallet!.balance.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _showTopupDialog,
              child: const Text('Top Up'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnlineToggleCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _wallet!.isOnline ? 'You are ONLINE' : 'You are OFFLINE',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _wallet!.isOnline
                        ? const Color(0xFF2E7D32)
                        : Colors.black54,
                  ),
                ),
                _isTogglingOnline
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Switch(
                        value: _wallet!.isOnline,
                        activeThumbColor: const Color(0xFF1E88E5),
                        onChanged: (value) => _toggleOnline(value),
                      ),
              ],
            ),
            if (_toggleError != null) ...[
              const SizedBox(height: 8),
              Text(_toggleError!,
                  style: const TextStyle(color: Color(0xFFD32F2F))),
            ],
          ],
        ),
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
            const Text('Nearby Orders',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isLoadingOrders ? null : _loadNearbyOrders,
            ),
          ],
        ),
        if (_isLoadingOrders)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_ordersError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_ordersError!,
                style: const TextStyle(color: Color(0xFFD32F2F))),
          )
        else if (_nearbyOrders.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('No pending orders nearby right now.',
                  style: TextStyle(color: Colors.black54)),
            ),
          )
        else
          ..._nearbyOrders.map((order) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _statusColor(order.status),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    order.status,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 11),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(order.tankerSize.asTankerSizeLabel),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('PKR ${order.price.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E88E5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _acceptingOrderIds.contains(order.id)
                            ? null
                            : () => _acceptOrder(order),
                        child: _acceptingOrderIds.contains(order.id)
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
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