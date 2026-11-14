import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';

/// Main settings hub page.
/// Provides navigation to all settings categories.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = [
      _SettingsCategory(
        title: 'Display & Theme',
        icon: Icons.brightness_6_rounded,
        children: [
          _SettingsItem(
            title: 'Theme',
            icon: Icons.palette_rounded,
            onTap: () => _showComingSoonDialog(context, 'Theme'),
          ),
          _SettingsItem(
            title: 'Dark Mode',
            icon: Icons.dark_mode_rounded,
            onTap: () => _showComingSoonDialog(context, 'Dark Mode'),
          ),
          _SettingsItem(
            title: 'Accent Color',
            icon: Icons.color_lens_rounded,
            onTap: () => _showComingSoonDialog(context, 'Accent Color'),
          ),
        ],
      ),
      _SettingsCategory(
        title: 'Fonts',
        icon: Icons.text_fields_rounded,
        children: [
          _SettingsItem(
            title: 'Font Size',
            icon: Icons.text_fields_rounded,
            onTap: () => _showComingSoonDialog(context, 'Font Size'),
          ),
          _SettingsItem(
            title: 'Font Family',
            icon: Icons.font_download_rounded,
            onTap: () => _showComingSoonDialog(context, 'Font Family'),
          ),
        ],
      ),
      _SettingsCategory(
        title: 'Notifications',
        icon: Icons.notifications_rounded,
        children: [
          _SettingsItem(
            title: 'Enable Notifications',
            icon: Icons.notifications_active_rounded,
            onTap: () => _showComingSoonDialog(context, 'Enable Notifications'),
          ),
          _SettingsItem(
            title: 'Notification Sounds',
            icon: Icons.volume_up_rounded,
            onTap: () => _showComingSoonDialog(context, 'Notification Sounds'),
          ),
          _SettingsItem(
            title: 'Vibration',
            icon: Icons.vibration_rounded,
            onTap: () => _showComingSoonDialog(context, 'Vibration'),
          ),
        ],
      ),
      _SettingsCategory(
        title: 'Reminders',
        icon: Icons.timer_rounded,
        children: [
          _SettingsItem(
            title: 'Default Focus Duration',
            icon: Icons.hourglass_top_rounded,
            onTap: () => _showComingSoonDialog(context, 'Focus Duration'),
          ),
          _SettingsItem(
            title: 'Default Break Duration',
            icon: Icons.hourglass_bottom_rounded,
            onTap: () => _showComingSoonDialog(context, 'Break Duration'),
          ),
        ],
      ),
      _SettingsCategory(
        title: 'Health',
        icon: Icons.health_and_safety_rounded,
        children: [
          _SettingsItem(
            title: 'Hydration',
            icon: Icons.local_drink_rounded,
            onTap: () => context.push('/settings/hydration'),
          ),
        ],
      ),
      _SettingsCategory(
        title: 'Calendar',
        icon: Icons.calendar_month_rounded,
        children: [
          _SettingsItem(
            title: 'Week Start Day',
            icon: Icons.calendar_today_rounded,
            onTap: () => _showComingSoonDialog(context, 'Week Start Day'),
          ),
          _SettingsItem(
            title: 'View Mode',
            icon: Icons.view_agenda_rounded,
            onTap: () => _showComingSoonDialog(context, 'View Mode'),
          ),
        ],
      ),
      _SettingsCategory(
        title: 'Accessibility',
        icon: Icons.accessibility_new_rounded,
        children: [
          _SettingsItem(
            title: 'High Contrast Mode',
            icon: Icons.contrast_rounded,
            onTap: () => _showComingSoonDialog(context, 'High Contrast Mode'),
          ),
          _SettingsItem(
            title: 'Text Scaling',
            icon: Icons.text_increase_rounded,
            onTap: () => _showComingSoonDialog(context, 'Text Scaling'),
          ),
          _SettingsItem(
            title: 'Screen Reader',
            icon: Icons.record_voice_over_rounded,
            onTap: () => _showComingSoonDialog(context, 'Screen Reader'),
          ),
        ],
      ),
      _SettingsCategory(
        title: 'Database',
        icon: Icons.storage_rounded,
        children: [
          _SettingsItem(
            title: 'Vacuum Database',
            icon: Icons.cleaning_services_rounded,
            onTap: () => _showComingSoonDialog(context, 'Vacuum Database'),
          ),
          _SettingsItem(
            title: 'Reset App Data',
            icon: Icons.delete_forever_rounded,
            onTap: () => _showComingSoonDialog(context, 'Reset App Data'),
          ),
        ],
      ),
      _SettingsCategory(
        title: 'About',
        icon: Icons.info_rounded,
        children: [
          _SettingsItem(
            title: 'Version',
            icon: Icons.info_rounded,
            onTap: () => _showVersionDialog(context),
          ),
          _SettingsItem(
            title: 'License',
            icon: Icons.balance_rounded,
            onTap: () => _showLicenseDialog(context),
          ),
          _SettingsItem(
            title: 'Privacy Policy',
            icon: Icons.privacy_tip_rounded,
            onTap: () => _showPrivacyDialog(context),
          ),
          _SettingsItem(
            title: 'Terms of Service',
            icon: Icons.description_rounded,
            onTap: () => _showTermsDialog(context),
          ),
        ],
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 16),
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          ...categories.map(
            (category) => Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(category.icon, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        category.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...category.children.map(
                    (item) => Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        leading: Icon(item.icon, color: AppColors.primary),
                        title: Text(item.title),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: item.onTap,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
          const Text(
            'Powered by Systum',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showComingSoonDialog(BuildContext context, String settingName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(settingName),
        content: const Text('This setting is not available yet.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showVersionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Version'),
        content: const Text('Systum v0.1.0'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showLicenseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('License'),
        content: const Text(
          'License information will be published before public release.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const Text(
          'Systum collects no personal data. All data is stored locally on your device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms of Service'),
        content: const Text(
          'By using Systum, you agree to our terms of service.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _SettingsCategory {
  final String title;
  final IconData icon;
  final List<_SettingsItem> children;

  _SettingsCategory({
    required this.title,
    required this.icon,
    required this.children,
  });
}

class _SettingsItem {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  _SettingsItem({required this.title, required this.icon, required this.onTap});
}
