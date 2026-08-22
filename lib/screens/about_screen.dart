import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _openPhoneDialer(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openWebLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About WaterWali')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: const Icon(Icons.water_drop, color: Colors.white, size: 48),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text('WaterWali',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                // TODO: keep this in sync with pubspec.yaml's version line by hand,
                // or add package_info_plus later to read it automatically.
                Text('Version 1.0.0', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('About the App',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16)),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'WaterWali connects households and businesses in Karachi with '
                    'nearby water tanker drivers — book a delivery in a few taps, '
                    'track your driver live, and pay cash on delivery.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('About the Builder',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16)),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'WaterWali is being built by Muhammad Ismail Channa, mostly known as '
                    'Aafaq Ali Channa, a Software Engineering student at DHA Suffa '
                    'University, Karachi.\n\n'
                    'Alongside university, he founded and runs Nizamix Technologies, '
                    'building software for real-world organizations, including '
                    'multi-tenant school and clinic ERP systems.\n\n'
                    'His current stack is Java, Spring Boot, Flutter/Dart, and '
                    'PostgreSQL. He also writes and publishes articles, explores '
                    'independent research, and plays competitive chess, currently '
                    'rated 1700+ on Chess.com.\n\n'
                    'WaterWali is a practical attempt to solve a real problem in '
                    'Karachi while learning what it takes to turn software from an '
                    'idea into something people can actually use.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _SocialLink(
                        icon: FontAwesomeIcons.linkedinIn,
                        label: 'LinkedIn',
                        onTap: () => _openWebLink(
                            'https://www.linkedin.com/in/aafaq-ali-channa'),
                      ),
                      _SocialLink(
                        icon: FontAwesomeIcons.github,
                        label: 'GitHub',
                        onTap: () => _openWebLink(
                            'https://github.com/AafaqAliChanna?tab=overview&from=2026-07-01&to=2026-07-10'),
                      ),
                      _SocialLink(
                        icon: FontAwesomeIcons.chess,
                        label: 'Chess.com',
                        onTap: () => _openWebLink(
                            'https://www.chess.com/member/aafaqalichanna'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.email_outlined, size: 20),
                    title: const Text('Contact the builder', style: TextStyle(fontSize: 14)),
                    subtitle: const Text('muhammadismailchanna777@gmail.com',
                        style: TextStyle(fontSize: 12)),
                    onTap: () => _openEmail('muhammadismailchanna777@gmail.com'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.phone_outlined),
                  title: const Text('Contact / Support'),
                  // TODO: replace with your real support number.
                  subtitle: const Text('+92 300 0000000'),
                  onTap: () => _openPhoneDialer('+923000000000'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('Support Email'),
                  subtitle: const Text('nizamixtechnologies@gmail.com'),
                  onTap: () => _openEmail('nizamixtechnologies@gmail.com'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialLink extends StatelessWidget {
  final FaIconData icon;
  final String label;
  final VoidCallback onTap;

  const _SocialLink({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: FaIcon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}