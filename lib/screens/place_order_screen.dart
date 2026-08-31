import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
import 'package:showcaseview/showcaseview.dart';
import '../models/order_model.dart';
import '../services/order_service.dart';
import '../services/auth_provider.dart';
import '../services/onboarding_service.dart';
import '../services/onboarding_narrator.dart';
import '../services/voice_guide_service.dart';
import '../theme/app_theme.dart';
import 'active_order_screen.dart';
import '../models/pricing_model.dart';
import '../services/pricing_service.dart';

class PlaceOrderScreen extends StatefulWidget {
  const PlaceOrderScreen({super.key});

  @override
  State<PlaceOrderScreen> createState() => _PlaceOrderScreenState();
}

class _PlaceOrderScreenState extends State<PlaceOrderScreen> {
  final OrderService _orderService = OrderService();
  final MapController _mapController = MapController();
  Timer? _idleDebounce;

  // The delivery point is always "whatever's under the pin in the center of
  // the screen" (Uber-style). We track it separately from the camera so we
  // know exactly what to send to the backend when the user confirms.
  ll.LatLng? _selectedLocation;
  TankerSize _selectedSize = TankerSize.size1000L;

  bool _isLoadingLocation = true; // initial GPS fetch = allowed full-screen blocker
  String? _locationError;

  bool _isPlacingOrder = false;
  String? _orderError;

  // Reverse-geocoded address shown above the pin. _addressRequestId guards
  // against a slow, stale lookup overwriting a newer one if the user drags
  // the map again before the first lookup returns.
  String? _address;
  bool _isLoadingAddress = false;
  bool _addressUnavailable = false;
  int _addressRequestId = 0;

  final _addressPillKey = GlobalKey();
  final _tankerSizeKey = GlobalKey();
  final _placeOrderButtonKey = GlobalKey();
  bool _tourActive = false;

  final PricingService _pricingService = PricingService();
  TankerPricing? _pricing; // null while loading, or if the fetch failed —
                            // ordering still works fine without a preview.

    @override
  void initState() {
    super.initState();
    _determinePosition();
    _loadPricing();
  }

  Future<void> _loadPricing() async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) return;
    try {
      final pricing = await _pricingService.getTodaysPricing(token);
      if (!mounted) return;
      setState(() => _pricing = pricing);
    } catch (_) {
      // Non-fatal — the price preview just won't show; the real price is
      // still calculated and shown by the backend once the order is placed.
    }
  }

  Future<void> _maybeStartTour() async {
    final seen = await OnboardingService.hasSeen('place_order');
    if (seen || !mounted) return;

    OnboardingNarrator.register(
      narrations: {
        _addressPillKey:
            'This shows your delivery address. Drag the map so the pin marks exactly where you want your water delivered.',
        _tankerSizeKey: 'Choose how much water you need here.',
        _placeOrderButtonKey: 'When you are ready, tap here to place your order.',
      },
      lastKey: _placeOrderButtonKey,
      onFinished: () async {
        await OnboardingService.markSeen('place_order');
        if (mounted) setState(() => _tourActive = false);
      },
    );

    setState(() => _tourActive = true);
    ShowCaseWidget.of(context)
        .startShowCase([_addressPillKey, _tankerSizeKey, _placeOrderButtonKey]);
  }

  void _skipTour() {
    ShowCaseWidget.of(context).dismiss();
    VoiceGuideService().stop();
    OnboardingService.markSeen('place_order');
    OnboardingNarrator.clear();
    setState(() => _tourActive = false);
  }

  Future<void> _determinePosition() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception(
          'Location services are turned off. Please enable GPS and try again.',
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception(
            'Location permission denied. WaterWali needs your location to deliver water to you.',
          );
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is permanently denied. Please enable it from app settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;
      setState(() {
        _selectedLocation = ll.LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });
      _reverseGeocode(_selectedLocation!);
      // Tour can only start once the map/form actually exists on screen —
      // wait one frame after this rebuild so the Showcase keys are attached.
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartTour());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationError = e.toString().replaceFirst('Exception: ', '');
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _recenterOnMyLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final here = ll.LatLng(position.latitude, position.longitude);
      _mapController.move(here, _mapController.camera.zoom);
      setState(() => _selectedLocation = here);
      _reverseGeocode(here);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not get your current location.')),
      );
    }
  }

  // flutter_map fires this continuously while dragging, with no built-in
  // "camera idle" event like Google Maps had. We fake one with a short
  // debounce: every move restarts a 400ms timer, and only once the map has
  // been still that long do we actually look up the address — otherwise a
  // single drag would trigger dozens of wasted geocoding calls.
  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    _selectedLocation = camera.center;
    if (!hasGesture) return;
    _idleDebounce?.cancel();
    _idleDebounce = Timer(const Duration(milliseconds: 400), () {
      if (_selectedLocation != null) _reverseGeocode(_selectedLocation!);
    });
  }

  Future<void> _reverseGeocode(ll.LatLng location) async {
    final requestId = ++_addressRequestId;
    setState(() {
      _isLoadingAddress = true;
      _addressUnavailable = false;
    });
    try {
      final placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );
      if (!mounted || requestId != _addressRequestId) return; // stale result

      if (placemarks.isEmpty) {
        setState(() {
          _address = null;
          _addressUnavailable = true;
          _isLoadingAddress = false;
        });
        return;
      }

      final p = placemarks.first;
      final parts = [p.street, p.subLocality, p.locality]
          .where((s) => s != null && s.trim().isNotEmpty)
          .toSet() // drop duplicate segments some devices return
          .toList();

      setState(() {
        _address = parts.isNotEmpty ? parts.join(', ') : null;
        _addressUnavailable = parts.isEmpty;
        _isLoadingAddress = false;
      });
    } catch (e) {
      // Reverse geocoding can fail (no native geocoder on some platforms, or
      // no internet) — that's non-fatal, the order still submits fine using
      // raw coordinates. We just can't show a friendly address.
      if (!mounted || requestId != _addressRequestId) return;
      setState(() {
        _address = null;
        _addressUnavailable = true;
        _isLoadingAddress = false;
      });
    }
  }

  Future<void> _confirmAndPlaceOrder() async {
    if (_selectedLocation == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Order'),
        content: Text(
          'Place an order for a ${_selectedSize.label} tanker to '
          '${_address ?? 'this location'}?\n\n'
          'The final price will be calculated by WaterWali and shown once your order is placed. Payment is Cash on Delivery.',
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

    setState(() {
      _isPlacingOrder = true;
      _orderError = null;
    });

    // listen: false because we're inside a callback, not the build method.
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;

    if (token == null) {
      setState(() {
        _isPlacingOrder = false;
        _orderError = 'You are not logged in. Please log in again.';
      });
      return;
    }

    try {
      final order = await _orderService.placeOrder(
        token: token,
        latitude: _selectedLocation!.latitude,
        longitude: _selectedLocation!.longitude,
        tankerSize: _selectedSize,
      );

      if (!mounted) return;
      setState(() => _isPlacingOrder = false);

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Order Placed!'),
          content: Text(
            'Your order #${order.id} has been placed.\n\n'
            'Price: PKR ${order.price.toStringAsFixed(0)}\n'
            'Status: ${order.status}\n\n'
            'A nearby driver will accept it shortly. Pay cash on delivery.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ActiveOrderScreen(orderId: order.id, initialOrder: order),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isPlacingOrder = false;
        _orderError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Place Your Order')),
      body: _isLoadingLocation
          ? const Center(child: CircularProgressIndicator())
          : _locationError != null
              ? _buildLocationError()
              : _buildMapAndForm(),
    );
  }

  Widget _buildLocationError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 48, color: AppColors.danger),
            const SizedBox(height: AppSpacing.md),
            Text(
              _locationError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.danger),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _determinePosition,
                child: const Text('Try Again'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapAndForm() {
    return Stack(
      children: [
        Column(
          children: [
            // Map takes the top portion of the screen; the pin is drawn as a
            // fixed overlay so it always points at the exact map center.
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _selectedLocation!,
                      initialZoom: 16,
                      onPositionChanged: _onPositionChanged,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.waterwali_app',
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 36),
                    child: Icon(
                      Icons.location_pin,
                      size: 44,
                      color: AppColors.danger,
                    ),
                  ),
                  Positioned(
                    top: AppSpacing.md,
                    left: AppSpacing.md,
                    right: AppSpacing.md,
                    child: Showcase(
                      key: _addressPillKey,
                      description:
                          'This is your delivery address. Drag the map so the pin marks exactly where you want your water delivered.\nیہ آپ کا ڈیلیوری پتہ ہے۔ نقشے کو حرکت دے کر پن کو صحیح جگہ پر رکھیں۔',
                      child: _buildAddressPill(),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton.small(
                      heroTag: 'recenter',
                      backgroundColor: Colors.white,
                      onPressed: _recenterOnMyLocation,
                      child: const Icon(Icons.my_location, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            // Order controls panel below the map.
            Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2)),
                ],
              ),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tanker Size', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16)),
                  const SizedBox(height: AppSpacing.sm),
                                    if (_pricing?.effectiveDate != null) ...[
                    Text(
                      "Today's prices (${_pricing!.effectiveDate})",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  Showcase(
                    key: _tankerSizeKey,
                    description:
                        'Choose how much water you need.\nآپ کو کتنے پانی کی ضرورت ہے یہاں منتخب کریں۔',
                    child: GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: AppSpacing.sm,
                      crossAxisSpacing: AppSpacing.sm,
                      childAspectRatio: 2.0,
                      children: TankerSize.values.map((size) {
                        return _TankerSizeCard(
                          size: size,
                          selected: size == _selectedSize,
                          todaysPrice: _pricing?.priceFor(size),
                          onTap: () => setState(() => _selectedSize = size),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Price is calculated automatically based on tanker size and distance.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_orderError != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(_orderError!, style: const TextStyle(color: AppColors.danger)),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Showcase(
                    key: _placeOrderButtonKey,
                    description:
                        'When you are ready, tap here to place your order.\nجب تیار ہوں تو آرڈر دینے کے لیے یہاں ٹیپ کریں۔',
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isPlacingOrder ? null : _confirmAndPlaceOrder,
                        child: _isPlacingOrder
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('PLACE ORDER'),
                      ),
                    ),
                  ),
                ],
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
    );
  }

  Widget _buildAddressPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.place_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _isLoadingAddress
                ? Text('Finding address...', style: Theme.of(context).textTheme.bodySmall)
                : Text(
                    _addressUnavailable || _address == null
                        ? 'Move the map to set delivery pin'
                        : _address!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _idleDebounce?.cancel();
    VoiceGuideService().stop();
    super.dispose();
  }
}

// A selectable card for one tanker size, with a small row of water-drop
// icons to give a quick visual sense of relative scale (1 drop = smallest).
class _TankerSizeCard extends StatelessWidget {
  final TankerSize size;
  final bool selected;
  final double? todaysPrice;
  final VoidCallback onTap;

  const _TankerSizeCard({
    required this.size,
    required this.selected,
    this.todaysPrice,
    required this.onTap,
  });

  int get _dropCount {
    switch (size) {
      case TankerSize.size1000L:
        return 1;
      case TankerSize.size2000L:
        return 2;
      case TankerSize.size3000L:
        return 3;
      case TankerSize.size5000L:
        return 4;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: List.generate(
                      _dropCount,
                      (i) => Icon(
                        Icons.water_drop,
                        size: 12,
                        color: selected ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                  ),
                                    const SizedBox(height: 2),
                  Text(
                    size.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: selected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '~${size.gallons} gal',
                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                  ),
                  if (todaysPrice != null)
                    Text(
                      'PKR ${todaysPrice!.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}