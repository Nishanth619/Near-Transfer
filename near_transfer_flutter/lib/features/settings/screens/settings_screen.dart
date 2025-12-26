import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../shared/providers/settings_provider.dart';
import '../../../shared/services/subscription_service.dart';
import '../../../shared/widgets/help_button.dart';
import '../widgets/settings_tile.dart';
import '../widgets/theme_mode_selector.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = '';
  final TextEditingController _deviceNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  @override
  void dispose() {
    _deviceNameController.dispose();
    super.dispose();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
      });
    } catch (e) {
      setState(() {
        _appVersion = '1.0.0';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        actions: const [
          HelpButton(
            featureName: 'Settings',
            helpText: 'Customize your NearTransfer experience.\n\n• Device: Set your device name and visibility\n• Transfer: Configure download location and file handling\n• Notifications: Control alerts and sounds\n• Theme: Switch between light and dark mode',
            iconColor: Colors.black87,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Device Section
          _buildSectionHeader('Device'),
          const SizedBox(height: 8),
          _buildCard([
            SettingsTile(
              icon: Icons.smartphone,
              title: 'Device Name',
              subtitle: settingsProvider.deviceName,
              trailing: const Icon(Icons.edit, size: 20),
              onTap: () => _showDeviceNameDialog(context, settingsProvider),
            ),
            const Divider(height: 1),
            SettingsTile(
              icon: Icons.visibility,
              title: 'Visible to Others',
              subtitle: 'Allow others to discover this device',
              trailing: Switch(
                value: settingsProvider.discoveryVisible,
                onChanged: (value) => settingsProvider.setDiscoveryVisible(value),
                activeColor: primaryColor,
              ),
            ),
          ]),

          const SizedBox(height: 24),

          // Transfer Section
          _buildSectionHeader('Transfer'),
          const SizedBox(height: 8),
          _buildCard([
            SettingsTile(
              icon: Icons.folder,
              title: 'Download Location',
              subtitle: settingsProvider.downloadPath.split('/').last,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showDownloadPathDialog(context, settingsProvider),
            ),
            const Divider(height: 1),
            SettingsTile(
              icon: Icons.check_circle,
              title: 'Auto Accept Files',
              subtitle: 'Accept files automatically from all devices',
              trailing: Switch(
                value: settingsProvider.autoAccept,
                onChanged: (value) => settingsProvider.setAutoAccept(value),
                activeColor: primaryColor,
              ),
            ),
            const Divider(height: 1),
            SettingsTile(
              icon: Icons.speed,
              title: 'Concurrent Transfers',
              subtitle: '${settingsProvider.maxConcurrentTransfers} files at once',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showConcurrentTransfersDialog(context, settingsProvider),
            ),
            const Divider(height: 1),
            SettingsTile(
              icon: Icons.compress,
              title: 'Compress Files',
              subtitle: 'Compress before sending (slower but smaller)',
              trailing: Switch(
                value: settingsProvider.compressionEnabled,
                onChanged: (value) => settingsProvider.setCompressionEnabled(value),
                activeColor: primaryColor,
              ),
            ),
            const Divider(height: 1),
            SettingsTile(
              icon: Icons.delete_sweep,
              title: 'Delete After Send',
              subtitle: 'Remove files after successful transfer',
              trailing: Switch(
                value: settingsProvider.deleteAfterSend,
                onChanged: (value) => settingsProvider.setDeleteAfterSend(value),
                activeColor: primaryColor,
              ),
            ),
          ]),

          const SizedBox(height: 24),

          // Receiving Section
          _buildSectionHeader('Receiving'),
          const SizedBox(height: 8),
          _buildCard([
            SettingsTile(
              icon: Icons.photo_library,
              title: 'Save to Gallery',
              subtitle: 'Save media files to gallery automatically',
              trailing: Switch(
                value: settingsProvider.saveToGallery,
                onChanged: (value) => settingsProvider.setSaveToGallery(value),
                activeColor: primaryColor,
              ),
            ),
            const Divider(height: 1),
            SettingsTile(
              icon: Icons.open_in_new,
              title: 'Auto Open Files',
              subtitle: 'Open files after receiving',
              trailing: Switch(
                value: settingsProvider.autoOpenFiles,
                onChanged: (value) => settingsProvider.setAutoOpenFiles(value),
                activeColor: primaryColor,
              ),
            ),
            const Divider(height: 1),
            SettingsTile(
              icon: Icons.preview,
              title: 'Show Preview',
              subtitle: 'Show file preview during transfer',
              trailing: Switch(
                value: settingsProvider.showPreview,
                onChanged: (value) => settingsProvider.setShowPreview(value),
                activeColor: primaryColor,
              ),
            ),
          ]),

          const SizedBox(height: 24),

          // Connection Section
          _buildSectionHeader('Connection'),
          const SizedBox(height: 8),
          _buildCard([
            SettingsTile(
              icon: Icons.wifi,
              title: 'WiFi Only',
              subtitle: 'Transfer only when connected to WiFi',
              trailing: Switch(
                value: settingsProvider.wifiOnly,
                onChanged: (value) => settingsProvider.setWifiOnly(value),
                activeColor: primaryColor,
              ),
            ),
            const Divider(height: 1),
            SettingsTile(
              icon: Icons.link,
              title: 'Auto Connect',
              subtitle: 'Automatically connect to known devices',
              trailing: Switch(
                value: settingsProvider.autoConnect,
                onChanged: (value) => settingsProvider.setAutoConnect(value),
                activeColor: primaryColor,
              ),
            ),
            const Divider(height: 1),
            SettingsTile(
              icon: Icons.screen_lock_portrait,
              title: 'Keep Screen On',
              subtitle: 'Prevent screen from sleeping during transfer',
              trailing: Switch(
                value: settingsProvider.keepScreenOn,
                onChanged: (value) => settingsProvider.setKeepScreenOn(value),
                activeColor: primaryColor,
              ),
            ),
          ]),

          const SizedBox(height: 24),

          // Security Section
          _buildSectionHeader('Security'),
          const SizedBox(height: 8),
          _buildCard([
            SettingsTile(
              icon: Icons.lock,
              title: 'Encryption',
              subtitle: 'Encrypt files during transfer',
              trailing: Switch(
                value: settingsProvider.encryptionEnabled,
                onChanged: (value) => settingsProvider.setEncryptionEnabled(value),
                activeColor: primaryColor,
              ),
            ),
          ]),

          const SizedBox(height: 24),

          // Notifications Section
          _buildSectionHeader('Notifications'),
          const SizedBox(height: 8),
          _buildCard([
            SettingsTile(
              icon: Icons.notifications,
              title: 'Push Notifications',
              subtitle: 'Receive transfer notifications',
              trailing: Switch(
                value: settingsProvider.showNotifications,
                onChanged: (value) => settingsProvider.setShowNotifications(value),
                activeColor: primaryColor,
              ),
            ),
            const Divider(height: 1),
            SettingsTile(
              icon: Icons.volume_up,
              title: 'Sound',
              subtitle: 'Play sound on transfer complete',
              trailing: Switch(
                value: settingsProvider.soundEnabled,
                onChanged: (value) => settingsProvider.setSoundEnabled(value),
                activeColor: primaryColor,
              ),
            ),
            const Divider(height: 1),
            SettingsTile(
              icon: Icons.vibration,
              title: 'Vibration',
              subtitle: 'Vibrate on transfer complete',
              trailing: Switch(
                value: settingsProvider.vibrationEnabled,
                onChanged: (value) => settingsProvider.setVibrationEnabled(value),
                activeColor: primaryColor,
              ),
            ),
          ]),

          const SizedBox(height: 24),

          // Appearance Section
          _buildSectionHeader('Appearance'),
          const SizedBox(height: 8),
          _buildCard([
            SettingsTile(
              icon: Icons.brightness_6,
              title: 'Theme',
              subtitle: _getThemeModeText(themeProvider.themeMode),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showThemeModeSelector(context),
            ),
          ]),

          const SizedBox(height: 24),

          // Storage Section
          _buildSectionHeader('Storage'),
          const SizedBox(height: 8),
          _buildCard([
            SettingsTile(
              icon: Icons.cleaning_services,
              title: 'Clear Cache',
              subtitle: 'Free up space',
              onTap: () => _showClearCacheDialog(context),
            ),
            const Divider(height: 1),
            SettingsTile(
              icon: Icons.history,
              title: 'Clear History',
              subtitle: 'Delete all transfer history',
              onTap: () => _showClearHistoryDialog(context),
            ),
          ]),

          const SizedBox(height: 24),

          // Premium Section
          _buildSectionHeader('Premium'),
          const SizedBox(height: 8),
          _buildCard([
            SettingsTile(
              icon: Icons.workspace_premium,
              title: SubscriptionService().isPremium ? 'Premium Active' : 'Go Premium',
              subtitle: SubscriptionService().isPremium 
                ? 'Enjoying ad-free experience' 
                : 'Remove all ads',
              trailing: SubscriptionService().isPremium 
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'ACTIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.amber.shade400, Colors.orange.shade600],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'UPGRADE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              onTap: () => context.push('/premium'),
            ),
          ]),

          const SizedBox(height: 24),

          // Help Section
          _buildSectionHeader('Help & Support'),
          const SizedBox(height: 8),
          _buildCard([
            SettingsTile(
              icon: Icons.help_outline,
              title: 'Help Center',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showHelpDialog(context),
            ),
            const Divider(height: 1),
            SettingsTile(
              icon: Icons.bug_report,
              title: 'Report a Bug',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showReportBugDialog(context),
            ),
            const Divider(height: 1),
            SettingsTile(
              icon: Icons.share,
              title: 'Share App',
              onTap: () => Share.share(
                'Check out NearTransfer - Fast file sharing app!\nhttps://play.google.com/store/apps/details?id=com.neartransfer.app',
              ),
            ),
            const Divider(height: 1),
            SettingsTile(
              icon: Icons.star,
              title: 'Rate Us',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showRateDialog(context),
            ),
          ]),

          const SizedBox(height: 24),

          // About Section
          _buildSectionHeader('About'),
          const SizedBox(height: 8),
          _buildCard([
            SettingsTile(
              icon: Icons.info_outline,
              title: 'Version',
              subtitle: _appVersion,
            ),
            const Divider(height: 1),
            SettingsTile(
              icon: Icons.description_outlined,
              title: 'Licenses',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'NearTransfer',
                applicationVersion: _appVersion,
                applicationIcon: Container(
                  padding: const EdgeInsets.all(16),
                  child: Icon(
                    Icons.near_me,
                    size: 48,
                    color: primaryColor,
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            SettingsTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showPrivacyPolicyDialog(context),
            ),
            const Divider(height: 1),
            SettingsTile(
              icon: Icons.article_outlined,
              title: 'Terms of Service',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showTermsDialog(context),
            ),
          ]),

          const SizedBox(height: 24),

          // Reset Section
          _buildCard([
            SettingsTile(
              icon: Icons.restore,
              title: 'Reset All Settings',
              subtitle: 'Reset to default settings',
              onTap: () => _showResetSettingsDialog(context, settingsProvider),
            ),
          ]),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  String _getThemeModeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System default';
    }
  }

  void _showThemeModeSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const ThemeModeSelector(),
    );
  }

  void _showDeviceNameDialog(BuildContext context, SettingsProvider settings) {
    _deviceNameController.text = settings.deviceName;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Device Name'),
        content: TextField(
          controller: _deviceNameController,
          decoration: const InputDecoration(
            hintText: 'Enter device name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_deviceNameController.text.trim().isNotEmpty) {
                settings.setDeviceName(_deviceNameController.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDownloadPathDialog(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Download Location',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('NearTransfer'),
              subtitle: const Text('/Download/NearTransfer'),
              trailing: settings.downloadPath.contains('NearTransfer')
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                settings.setDownloadPath('/storage/emulated/0/Download/NearTransfer');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Downloads'),
              subtitle: const Text('/Download'),
              trailing: settings.downloadPath == '/storage/emulated/0/Download'
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                settings.setDownloadPath('/storage/emulated/0/Download');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.sd_storage),
              title: const Text('Documents'),
              subtitle: const Text('/Documents'),
              trailing: settings.downloadPath.contains('Documents')
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                settings.setDownloadPath('/storage/emulated/0/Documents');
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showConcurrentTransfersDialog(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Concurrent Transfers',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Maximum number of files to transfer at once',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ...List.generate(5, (index) {
              final value = index + 1;
              return ListTile(
                title: Text('$value ${value == 1 ? 'file' : 'files'}'),
                trailing: settings.maxConcurrentTransfers == value
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () {
                  settings.setMaxConcurrentTransfers(value);
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text('Are you sure you want to clear all cached data?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache cleared successfully')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showClearHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text('Are you sure you want to delete all transfer history? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('History cleared successfully')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showResetSettingsDialog(BuildContext context, SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text('Are you sure you want to reset all settings to their default values?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              settings.resetToDefaults();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings reset to defaults')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          child: ListView(
            controller: scrollController,
            children: [
              const Text(
                'Help Center',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              _buildHelpItem(
                'How to send files?',
                '1. Tap "Send Files" on the home screen\n2. Select files you want to send\n3. Choose a nearby device\n4. Wait for the transfer to complete',
              ),
              _buildHelpItem(
                'How to receive files?',
                '1. Tap "Receive Files" on the home screen\n2. Your device will be visible to others\n3. Accept incoming file requests\n4. Files will be saved to your download folder',
              ),
              _buildHelpItem(
                'Shake to Connect',
                'Shake your phone while the other person does the same to quickly connect and transfer files.',
              ),
              _buildHelpItem(
                'Troubleshooting',
                '• Make sure both devices are on the same WiFi network\n• Enable WiFi and location services\n• Grant all required permissions\n• Try restarting the app',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHelpItem(String title, String content) {
    return ExpansionTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(content),
        ),
      ],
    );
  }

  void _showReportBugDialog(BuildContext context) {
    final TextEditingController bugController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report a Bug'),
        content: TextField(
          controller: bugController,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Describe the issue you encountered...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Thank you for your feedback!')),
              );
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _showRateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rate NearTransfer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('If you enjoy using NearTransfer, please take a moment to rate us!'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (index) => IconButton(
                  icon: const Icon(Icons.star, size: 36),
                  color: Colors.amber,
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Thank you for your rating!')),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicyDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          child: ListView(
            controller: scrollController,
            children: const [
              Text(
                'Privacy Policy',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                'Last updated: December 2024\n\n'
                'NearTransfer respects your privacy and is committed to protecting your personal data.\n\n'
                '1. DATA COLLECTION\n'
                'We do not collect or store any personal information. All file transfers occur directly between devices without going through our servers.\n\n'
                '2. PERMISSIONS\n'
                'The app requires certain permissions (WiFi, Storage, Location) solely for the purpose of file discovery and transfer. We do not access your data for any other purpose.\n\n'
                '3. LOCAL STORAGE\n'
                'App settings and transfer history are stored locally on your device and are never uploaded.\n\n'
                '4. THIRD PARTY\n'
                'We do not share any data with third parties.\n\n'
                '5. CONTACT\n'
                'If you have questions about this policy, please contact us.',
                style: TextStyle(height: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTermsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          child: ListView(
            controller: scrollController,
            children: const [
              Text(
                'Terms of Service',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                'Last updated: December 2024\n\n'
                'By using NearTransfer, you agree to these terms.\n\n'
                '1. USE OF SERVICE\n'
                'NearTransfer is provided for personal, non-commercial use. You may use it to transfer files between your devices.\n\n'
                '2. USER RESPONSIBILITIES\n'
                'You are responsible for the content you transfer. Do not use the app for illegal activities or to share copyrighted content without permission.\n\n'
                '3. DISCLAIMER\n'
                'The app is provided "as is" without warranties. We are not responsible for data loss during transfers.\n\n'
                '4. UPDATES\n'
                'We may update these terms from time to time. Continued use of the app constitutes acceptance of new terms.\n\n'
                '5. CONTACT\n'
                'For questions about these terms, please contact us.',
                style: TextStyle(height: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
