import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/driver_profile_model.dart';
import '../models/review_model.dart';
import '../services/driver_profile_service.dart';
import '../services/auth_provider.dart';

class DriverProfileScreen extends StatefulWidget {
  final String driverId;
  const DriverProfileScreen({super.key, required this.driverId});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  final DriverProfileService _service = DriverProfileService();

  bool _isLoading = true;
  DriverProfile? _profile;
  List<Review> _reviews = [];
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
      final profile = await _service.getDriverProfile(_token!, widget.driverId);
      final reviews = await _service.getDriverReviews(_token!, widget.driverId);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _reviews = reviews;
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

  Widget _buildStars(double rating, {double size = 18}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        IconData icon;
        if (rating >= index + 1) {
          icon = Icons.star;
        } else if (rating > index) {
          icon = Icons.star_half;
        } else {
          icon = Icons.star_border;
        }
        return Icon(icon, size: size, color: const Color(0xFFF57C00));
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        title: const Text('Driver Profile'),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
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
              : _buildProfile(),
    );
  }

  Widget _buildProfile() {
    final profile = _profile!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: CircleAvatar(
            radius: 48,
            backgroundColor: const Color(0xFF1E88E5),
            backgroundImage:
                profile.photoUrl != null ? NetworkImage(profile.photoUrl!) : null,
            child: profile.photoUrl == null
                ? Text(
                    profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 32, color: Colors.white),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(profile.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 6),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStars(profile.averageRating),
              const SizedBox(width: 6),
              Text('${profile.averageRating.toStringAsFixed(1)} (${profile.totalReviews})',
                  style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ),
        if (profile.vehicleModel != null || profile.vehiclePlateNumber != null) ...[
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Vehicle', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (profile.vehicleModel != null) Text(profile.vehicleModel!),
                  if (profile.vehiclePlateNumber != null)
                    Text('Plate: ${profile.vehiclePlateNumber}'),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        const Text('Reviews', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        if (_reviews.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No reviews yet.', style: TextStyle(color: Colors.black54)),
          )
        else
          ..._reviews.map((review) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(review.customerName,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          _buildStars(review.rating.toDouble(), size: 14),
                        ],
                      ),
                      if (review.comment != null && review.comment!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(review.comment!),
                      ],
                    ],
                  ),
                ),
              )),
      ],
    );
  }
}