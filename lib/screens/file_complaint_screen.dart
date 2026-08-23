import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/complaint_service.dart';
import '../services/auth_provider.dart';
import '../theme/app_theme.dart';

class FileComplaintScreen extends StatefulWidget {
  final String orderId;
  const FileComplaintScreen({super.key, required this.orderId});

  @override
  State<FileComplaintScreen> createState() => _FileComplaintScreenState();
}

class _FileComplaintScreenState extends State<FileComplaintScreen> {
  static const _categories = {
    'LATE_DELIVERY': 'Late delivery',
    'RUDE_BEHAVIOR': 'Rude behavior',
    'WRONG_AMOUNT': 'Wrong amount / short delivery',
    'SAFETY_CONCERN': 'Safety concern',
    'OTHER': 'Other',
  };

  final ComplaintService _complaintService = ComplaintService();
  final TextEditingController _descriptionController = TextEditingController();
  String _category = 'LATE_DELIVERY';
  bool _isSubmitting = false;
  String? _error;

  Future<void> _submit() async {
    if (_descriptionController.text.trim().isEmpty) {
      setState(() => _error = 'Please describe what happened.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    try {
      await _complaintService.fileComplaint(
        token!,
        widget.orderId,
        _category,
        _descriptionController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
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
      appBar: AppBar(title: const Text('File a Complaint')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('What went wrong?', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: _category,
              items: _categories.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _descriptionController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Describe what happened',
                alignLabelWithHint: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('SUBMIT COMPLAINT'),
            ),
          ],
        ),
      ),
    );
  }
}