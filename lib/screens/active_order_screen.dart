import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/order_model.dart';
import '../services/order_service.dart';
import '../services/driver_service.dart';
import '../services/auth_provider.dart';
import '../services/location_socket_service.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import 'driver_profile_screen.dart';
import 'file_complaint_screen.dart';
import 'leave_review_screen.dart';

class ActiveOrderScreen extends StatefulWidget {
  final String orderId;
  final Order? initialOrder;
  const ActiveOrderScreen({super.key, required this.orderId, this.initialOrder});
  @override
  State<ActiveOrderScreen> createState() => _ActiveOrderScreenState();
}

class _ActiveOrderScreenState extends State<ActiveOrderScreen> {
  final OrderService _orderService = OrderService();
  final DriverService _driverService = DriverService();
  final LocationSocketService _locationSocket = LocationSocketService();

  bool _isLoading = true;
  Order? _order;
  String? _error;
  bool _isCompleting = false;
  bool _isCancelling = false;
  bool _isConfirming = false;
  bool _hasReviewed = false;

  bool _locationTrackingStarted = false;
  ll.LatLng? _driverLocation;
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionStream;

  // Client-side-only countdown for UX — the real 30s window enforcement
  // happens server-side via cancelDeadline. This just drives the button
  // label/visibility so the customer sees it counting down live.
  Timer? _cancelWindowTimer;
  int _cancelSecondsRemaining = 0;

  String? get _token => Provider.of<AuthProvider>(context, listen: false).token;
  bool get _isDriver => Provider.of<AuthProvider>(context, listen: false).isDriver;

  @override
  void initState() {
    super.initState();
    if (widget.initialOrder != null) {
      _order = widget.initialOrder;
      _isLoading = false;
      _syncLocationTracking();
      _syncCancelWindowTimer();
    } else {
      _loadOrder();
    }
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
      _syncLocationTracking();
      _syncCancelWindowTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _syncLocationTracking() {
    final status = _order?.status;
    final isActive = status == 'ACCEPTED' || status == 'IN_PROGRESS';

    if (isActive && !_locationTrackingStarted) {
      _locationTrackingStarted = true;
      _isDriver ? _startSendingLocation() : _startReceivingLocation();
    } else if (!isActive && _locationTrackingStarted) {
      _stopLocationTracking();
    }
  }

  // Drives the live "Cancel Order (27s)" countdown shown to the customer
  // during the 30s window after driver confirmation. Restarts cleanly
  // whenever the order data changes (confirm/cancel/reload).
  void _syncCancelWindowTimer() {
    _cancelWindowTimer?.cancel();
    final deadlineStr = _order?.cancelDeadline;
    if (_isDriver || deadlineStr == null) {
      setState(() => _cancelSecondsRemaining = 0);
      return;
    }
    final deadline = DateTime.tryParse(deadlineStr);
    if (deadline == null) {
      setState(() => _cancelSecondsRemaining = 0);
      return;
    }
    void tick() {
      if (!mounted) return;
      final remaining = deadline.difference(DateTime.now()).inSeconds;
      setState(() => _cancelSecondsRemaining = remaining > 0 ? remaining : 0);
      if (remaining <= 0) _cancelWindowTimer?.cancel();
    }

    tick();
    _cancelWindowTimer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  void _startReceivingLocation() {
    _locationSocket.connect(
      token: _token!,
      orderId: widget.orderId,
      onConnected: () {},
      onLocationReceived: (update) {
        if (!mounted) return;
        final position = ll.LatLng(update.latitude, update.longitude);
        setState(() => _driverLocation = position);
        _mapController.move(position, _mapController.camera.zoom);
      },
      onError: (error) {},
    );
  }

  void _startSendingLocation() {
    _locationSocket.connect(
      token: _token!,
      orderId: widget.orderId,
      onConnected: () {
        _positionStream = Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 20,
          ),
        ).listen((position) {
          _locationSocket.sendLocation(
            widget.orderId,
            position.latitude,
            position.longitude,
          );
        });
      },
      onError: (error) {},
    );
  }

  void _stopLocationTracking() {
    _positionStream?.cancel();
    _positionStream = null;
    _locationSocket.disconnect();
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

  Future<void> _confirmOrder() async {
    setState(() => _isConfirming = true);
    try {
      final order = await _driverService.confirmOrder(_token!, widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = order;
        _isConfirming = false;
      });
      _syncCancelWindowTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order confirmed with customer.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isConfirming = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ),
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
      _syncLocationTracking();
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

  Future<void> _cancelOrder({String? confirmMessage}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: Text(
          confirmMessage ??
              'Are you sure you want to cancel this order? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Order'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isCancelling = true);
    try {
      final order = await _orderService.cancelOrder(_token!, widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = order;
        _isCancelling = false;
      });
      _syncLocationTracking();
      _syncCancelWindowTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order cancelled.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCancelling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  void dispose() {
    _stopLocationTracking();
    _cancelWindowTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadOrder),
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
    final showLiveMap =
        !_isDriver && (order.status == 'ACCEPTED' || order.status == 'IN_PROGRESS');
    final canMarkDelivered = _isDriver &&
        ((order.status == 'ACCEPTED' && order.confirmedAt != null) ||
            order.status == 'IN_PROGRESS');

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Order #${order.id}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16)),
                    Text(
                      'PKR ${order.price.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${order.tankerSize.asTankerSizeLabel} tanker • Cash on Delivery',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                if (order.status == 'CANCELLED')
                  _buildCancelledBanner()
                else
                  _OrderStatusTimeline(status: order.status),
              ],
            ),
          ),
        ),
        if (showLiveMap) ...[
          const SizedBox(height: AppSpacing.md),
          _buildLiveMap(order),
        ],
        const SizedBox(height: AppSpacing.md),
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
          if (!_isDriver && order.driverId != null) ...[
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
                    MaterialPageRoute(
                      builder: (context) => DriverProfileScreen(driverId: order.driverId!),
                    ),
                  );
                },
                icon: const Icon(Icons.person_outline),
                label: const Text('View Driver Profile'),
              ),
            ),
          ],
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
        ] else if (order.status != 'CANCELLED')
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(
              'Contact number will appear once a driver accepts this order.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),

        // Driver must confirm (or give up and cancel) before the order can
        // proceed — see _confirmOrder/_cancelOrder for why this stage exists.
        if (_isDriver && order.status == 'ACCEPTED' && order.confirmedAt == null) ...[
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isConfirming ? null : _confirmOrder,
              icon: _isConfirming
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: const Text('CONFIRMED WITH CUSTOMER'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger, width: 1.5),
              ),
              onPressed: _isCancelling
                  ? null
                  : () => _cancelOrder(
                      confirmMessage:
                          "Cancel this order because the customer couldn't be reached?"),
              child: _isCancelling
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: AppColors.danger, strokeWidth: 2),
                    )
                  : const Text('CUSTOMER UNREACHABLE — CANCEL'),
            ),
          ),
        ],

        if (canMarkDelivered) ...[
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isCompleting ? null : _markAsDelivered,
              child: _isCompleting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('MARK AS DELIVERED'),
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.md),
        Center(
          child: TextButton.icon(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => FileComplaintScreen(orderId: order.id),
                ),
              );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Complaint submitted. Our team will review it.')),
              );
            },
            icon: const Icon(Icons.flag_outlined, size: 18, color: AppColors.textSecondary),
            label: const Text('Report a problem', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ),
        if (!_isDriver && order.status == 'COMPLETED' && !_hasReviewed) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFF57C00),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final submitted = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (context) => LeaveReviewScreen(orderId: order.id)),
                );
                if (submitted == true && mounted) {
                  setState(() => _hasReviewed = true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Thanks for your review!')),
                  );
                }
              },
              icon: const Icon(Icons.star_outline),
              label: const Text('Leave a Review'),
            ),
          ),
        ],
        if (!_isDriver && order.status == 'PENDING') ...[
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger, width: 1.5),
              ),
              onPressed: _isCancelling ? null : () => _cancelOrder(),
              child: _isCancelling
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: AppColors.danger, strokeWidth: 2),
                    )
                  : const Text('CANCEL ORDER'),
            ),
          ),
        ],
        // Customer's 30s cancel window after the driver confirms.
        if (!_isDriver && order.status == 'ACCEPTED' && order.confirmedAt == null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your driver will call to confirm the order shortly.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (!_isDriver &&
            order.status == 'ACCEPTED' &&
            order.confirmedAt != null &&
            _cancelSecondsRemaining > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger, width: 1.5),
              ),
              onPressed: _isCancelling ? null : () => _cancelOrder(),
              child: _isCancelling
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: AppColors.danger, strokeWidth: 2),
                    )
                  : Text('CANCEL ORDER (${_cancelSecondsRemaining}s)'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCancelledBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.cancel_outlined, color: AppColors.danger),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text('This order was cancelled.', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveMap(Order order) {
    final destination = ll.LatLng(order.latitude, order.longitude);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        height: 220,
        child: _driverLocation == null
            ? Container(
                color: AppColors.surface,
                child: Center(
                  child: Text('Waiting for driver location...', style: Theme.of(context).textTheme.bodySmall),
                ),
              )
            : FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _driverLocation!,
                  initialZoom: 14,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.waterwali_app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _driverLocation!,
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.local_shipping, color: AppColors.primary, size: 32),
                      ),
                      Marker(
                        point: destination,
                        width: 36,
                        height: 36,
                        child: const Icon(Icons.location_pin, color: AppColors.danger, size: 34),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

// A 4-step horizontal progress tracker: Pending → Accepted → On the way →
// Delivered. Each step is either done (filled, checked), current (filled,
// highlighted), or upcoming (outlined, greyed).
class _OrderStatusTimeline extends StatelessWidget {
  final String status;
  const _OrderStatusTimeline({required this.status});

  static const _steps = [
    (label: 'Pending', icon: Icons.hourglass_empty, statuses: ['PENDING']),
    (label: 'Accepted', icon: Icons.check, statuses: ['ACCEPTED']),
    (label: 'On the way', icon: Icons.local_shipping_outlined, statuses: ['IN_PROGRESS']),
    (label: 'Delivered', icon: Icons.home_outlined, statuses: ['COMPLETED']),
  ];

  int get _currentIndex {
    switch (status) {
      case 'PENDING':
        return 0;
      case 'ACCEPTED':
        return 1;
      case 'IN_PROGRESS':
        return 2;
      case 'COMPLETED':
        return 3;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentIndex;
    return Row(
      children: List.generate(_steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final leftStepIndex = i ~/ 2;
          final isFilled = leftStepIndex < current;
          return Expanded(
            child: Container(
              height: 2,
              color: isFilled ? AppColors.primary : AppColors.border,
            ),
          );
        }
        final stepIndex = i ~/ 2;
        final step = _steps[stepIndex];
        final isDone = stepIndex < current;
        final isCurrent = stepIndex == current;
        final isFilled = isDone || isCurrent;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isFilled ? AppColors.primary : AppColors.background,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isFilled ? AppColors.primary : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: Icon(
                isDone ? Icons.check : step.icon,
                size: 15,
                color: isFilled ? Colors.white : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 60,
              child: Text(
                step.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                  color: isFilled ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}