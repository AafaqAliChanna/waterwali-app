import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/order_model.dart';
import '../services/order_service.dart';
import '../services/driver_service.dart';
import 'chat_screen.dart';
import '../services/auth_provider.dart';

class ActiveOrderScreen extends StatefulWidget {
  final int orderId;
  const ActiveOrderScreen({super.key, required this.orderId});

  @override
  State<ActiveOrderScreen> createState() => _ActiveOrderScreenState();
}

class _ActiveOrderScreenState extends State<ActiveOrderScreen> {
  final OrderService _orderService = OrderService();
  final DriverService _driverService = DriverService();

  bool _isLoading = true;
  Order? _order;
  String? _error;
  bool _isCompleting = false;

  String? get _token => Provider.of<AuthProvider>(context, listen: false).token;
  bool get _isDriver => Provider.of<AuthProvider>(context, listen: false).isDriver;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final order = await _orderService.getOrder(_token!, widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = order;
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

  Future<void> _callOtherParty() async {
    final phone = _isDriver ? _order!.customerPhone : _order!.driverPhone;
    if (phone == null) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the phone dialer.')),
      );
    }
  }

  Future<void> _markAsDelivered() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Delivered'),
        content: const Text(
          'Confirm this order has been delivered and paid for in cash? '
          'This cannot be undone, and a 7% commission will be deducted from your wallet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isCompleting = true);
    try {
      final order = await _driverService.completeOrder(_token!, widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = order;
        _isCompleting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order marked as delivered!')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCompleting = false);
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
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        title: const Text('Order Details'),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadOrder),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, style: const TextStyle(color: Color(0xFFD32F2F))),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _loadOrder, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _buildOrderDetails(),
    );
  }

  Widget _buildOrderDetails() {
    final order = _order!;
    final otherPhone = _isDriver ? order.customerPhone : order.driverPhone;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Order #${order.id}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor(order.status),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(order.status,
                          style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text('Tanker: ${order.tankerSize.asTankerSizeLabel}'),
                const SizedBox(height: 4),
                Text('Price: PKR ${order.price.toStringAsFixed(0)} (Cash on Delivery)'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (otherPhone != null) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _callOtherParty,
              icon: const Icon(Icons.call),
              label: Text(_isDriver ? 'Call Customer' : 'Call Driver'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1E88E5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => ChatScreen(orderId: order.id)),
                );
              },
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Chat'),
            ),
          ),
        ] else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Contact number will appear once a driver accepts this order.',
              style: TextStyle(color: Colors.black54),
            ),
          ),
        if (_isDriver && (order.status == 'ACCEPTED' || order.status == 'IN_PROGRESS')) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isCompleting ? null : _markAsDelivered,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _isCompleting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('MARK AS DELIVERED'),
              ),
            ),
          ),
        ],
      ],
    );
  }
}