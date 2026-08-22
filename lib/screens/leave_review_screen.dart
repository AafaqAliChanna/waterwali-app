import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/review_service.dart';
import '../services/auth_provider.dart';

class LeaveReviewScreen extends StatefulWidget {
  final String orderId;
  const LeaveReviewScreen({super.key, required this.orderId});

  @override
  State<LeaveReviewScreen> createState() => _LeaveReviewScreenState();
}

class _LeaveReviewScreenState extends State<LeaveReviewScreen> {
  final ReviewService _reviewService = ReviewService();
  final TextEditingController _commentController = TextEditingController();
  int _rating = 0;
  bool _isSubmitting = false;
  String? _error;

  Future<void> _submit() async {
    if (_rating == 0) {
      setState(() => _error = 'Please select a star rating.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    try {
      await _reviewService.submitReview(
        token!,
        widget.orderId,
        _rating,
        _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true); // true = review submitted successfully
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave a Review'),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('How was your delivery?', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starValue = index + 1;
                return IconButton(
                  iconSize: 40,
                  icon: Icon(
                    starValue <= _rating ? Icons.star : Icons.star_border,
                    color: const Color(0xFFF57C00),
                  ),
                  onPressed: () => setState(() => _rating = starValue),
                );
              }),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _commentController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Write a comment (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Color(0xFFD32F2F))),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isSubmitting ? null : _submit,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('SUBMIT REVIEW'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}