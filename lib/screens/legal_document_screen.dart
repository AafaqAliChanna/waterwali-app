import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// One reusable screen for any legal document — Terms of Service, Privacy
// Policy, etc. all render through this, so there's a single place to fix
// formatting instead of duplicating a screen per document.
class LegalDocumentScreen extends StatelessWidget {
  final String title;
  final String content;

  const LegalDocumentScreen({super.key, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: const Text(
              'Draft document — not yet reviewed by a lawyer. Provided as-is '
              'while WaterWali is in development.',
              style: TextStyle(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(content, style: const TextStyle(height: 1.5)),
        ],
      ),
    );
  }
}