import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/order_model.dart';
import '../services/auth_provider.dart';
import 'active_order_screen.dart';

// One shared screen for both roles — the customer's "My Orders" and the
// driver's "My Deliveries" only differ in which API call fetches the list,
// so that's passed in rather than duplicating this whole screen twice.
class OrderHistoryScreen extends StatefulWidget {
  final String title;
  final Future<List<Order>> Function(String token) fetchOrders;

  const OrderHistoryScreen({
    super.key,
    required this.title,
    required this.fetchOrders,
  });

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  bool _isLoading = true;
  List<Order> _orders = [];
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
      final orders = await widget.fetchOrders(_token!);
      if (!mounted) return;
      setState(() {
        _orders = orders;
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
        title: Text(widget.title),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
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
                        ElevatedButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _orders.isEmpty
                  ? const Center(
                      child: Text('No orders yet.', style: TextStyle(color: Colors.black54)),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _orders.length,
                        itemBuilder: (context, index) {
                          final order = _orders[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => ActiveOrderScreen(
                                      orderId: order.id,
                                      initialOrder: order,
                                    ),
                                  ),
                                );
                              },
                              title: Text(order.tankerSize.asTankerSizeLabel),
                              subtitle: Text(
                                  'PKR ${order.price.toStringAsFixed(0)} • ${order.createdAt}'),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _statusColor(order.status),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(order.status,
                                    style: const TextStyle(color: Colors.white, fontSize: 12)),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}