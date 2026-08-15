import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../models/order_model.dart';
import '../services/order_service.dart';
import '../services/auth_provider.dart';
import 'active_order_screen.dart';

class PlaceOrderScreen extends StatefulWidget {
  const PlaceOrderScreen({super.key});

  @override
  State<PlaceOrderScreen> createState() => _PlaceOrderScreenState();
}

class _PlaceOrderScreenState extends State<PlaceOrderScreen> {
  final OrderService _orderService = OrderService();
  GoogleMapController? _mapController;

  // The delivery point is always "whatever's under the pin in the center of
  // the screen" (Uber-style). We track it separately from the camera so we
  // know exactly what to send to the backend when the user confirms.
  LatLng? _selectedLocation;
  TankerSize _selectedSize = TankerSize.size1000L;

  bool _isLoadingLocation = true; // initial GPS fetch = allowed full-screen blocker
  String? _locationError;

  bool _isPlacingOrder = false;
  String? _orderError;

  @override
  void initState() {
    super.initState();
    _determinePosition();
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
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationError = e.toString().replaceFirst('Exception: ', '');
        _isLoadingLocation = false;
      });
    }
  }

  // Called continuously as the user drags the map, so _selectedLocation
  // always matches whatever is currently under the fixed center pin.
  void _onCameraMove(CameraPosition position) {
    _selectedLocation = position.target;
  }

  Future<void> _confirmAndPlaceOrder() async {
    if (_selectedLocation == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Order'),
        content: Text(
          'Place an order for a ${_selectedSize.label} tanker to this location?\n\n'
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
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        title: const Text('Place Your Order'),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
      ),
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
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 48, color: Color(0xFFD32F2F)),
            const SizedBox(height: 16),
            Text(
              _locationError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFD32F2F)),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _determinePosition,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Try Again'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapAndForm() {
    return Column(
      children: [
        // Map takes the top portion of the screen; the pin is drawn as a
        // fixed overlay so it always points at the exact map center.
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _selectedLocation!,
                  zoom: 16,
                ),
                onMapCreated: (controller) => _mapController = controller,
                onCameraMove: _onCameraMove,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: false,
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 36),
                child: Icon(
                  Icons.location_pin,
                  size: 44,
                  color: Color(0xFFD32F2F),
                ),
              ),
            ],
          ),
        ),
        // Order controls panel below the map.
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2)),
            ],
          ),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tanker Size',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: TankerSize.values.map((size) {
                  final selected = size == _selectedSize;
                  return ChoiceChip(
                    label: Text(size.label),
                    selected: selected,
                    selectedColor: const Color(0xFF1E88E5),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : Colors.black87,
                    ),
                    onSelected: (_) => setState(() => _selectedSize = size),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              const Text(
                'Move the map so the pin marks your delivery address. Price is calculated automatically.',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
              if (_orderError != null) ...[
                const SizedBox(height: 10),
                Text(
                  _orderError!,
                  style: const TextStyle(color: Color(0xFFD32F2F)),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E88E5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _isPlacingOrder ? null : _confirmAndPlaceOrder,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: _isPlacingOrder
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('PLACE ORDER'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
