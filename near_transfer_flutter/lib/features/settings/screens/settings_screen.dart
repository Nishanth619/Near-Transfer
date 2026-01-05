import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../shared/providers/settings_provider.dart';
import '../../../shared/services/subscription_service.dart';
import '../../../shared/widgets/help_button.dart';
import '../../../shared/widgets/banner_ad_widget.dart';
import '../widgets/settings_tile.dart';
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.go('/home');
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: const Text(
            'Settings',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/home'),
          ),
          actions: const [
            HelpButton(
              featureName: 'Settings',
              helpText: 'Customize your NearTransfer experience.\n\n• Device: Set your device name and visibility\n• Transfer: Configure download location and file handling\n• Notifications: Control alerts and sounds',
              iconColor: Colors.black87,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
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
              icon: Icons.notifications,
              title: 'Notifications',
              subtitle: 'Receive transfer notifications',
              trailing: Switch(
                value: settingsProvider.showNotifications,
                onChanged: (value) => settingsProvider.setShowNotifications(value),
                activeColor: primaryColor,
              ),
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

          // Support Section
          _buildSectionHeader('Support'),
          const SizedBox(height: 8),
          _buildCard([
            SettingsTile(
              icon: Icons.share,
              title: 'Share App',
              subtitle: 'Share with friends',
              onTap: () => Share.share(
                'Check out NearTransfer - Fast file sharing app!\nhttps://play.google.com/store/apps/details?id=com.neartransfer.app',
              ),
            ),
            const Divider(height: 1),
            SettingsTile(
              icon: Icons.star,
              title: 'Rate Us',
              subtitle: 'Love the app? Rate us!',
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

          const SizedBox(height: 40),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: const BannerAdWidget(),
            ),
          ],
        ),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
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
                'Effective Date: January 1, 2026\n\n'
                'NearTransfer ("we," "our," or "us") respects your privacy and is committed to protecting your personal data.\n\n'
                '1. INFORMATION WE DO NOT COLLECT\n'
                '• We do NOT collect the content of files you transfer\n'
                '• We do NOT collect your contacts or location\n'
                '• We do NOT require login credentials\n'
                '• All file transfers happen directly between devices\n\n'
                '2. PERMISSIONS USED\n'
                '• Internet: Display advertisements\n'
                '• WiFi/Network: Discover nearby devices, transfer files\n'
                '• Storage: Access files to send, save received files\n'
                '• Contacts: Only when you use Contact Sharing feature\n'
                '• Query All Packages: Only for App Sharing feature\n\n'
                'Note: Contacts are accessed only when you explicitly choose to use the Contact Sharing feature and are never collected, stored, or transmitted to our servers.\n\n'
                'Important: NearTransfer does not track app usage or analytics related to installed applications. Installed app information is used only for user-initiated sharing.\n\n'
                '3. ADVERTISING\n'
                'We use Google AdMob to display ads. AdMob may collect device identifiers for personalized advertising. You can opt out in your device\'s Google settings.\n\n'
                '4. IN-APP PURCHASES\n'
                'Premium purchases are processed through Google Play Billing. We receive only purchase confirmation, not your payment details.\n\n'
                '5. DATA SECURITY\n'
                'All transfers happen over your local WiFi network. Files are NOT routed through our servers. We recommend using secure networks.\n\n'
                '6. CHILDREN\'S PRIVACY\n'
                'NearTransfer is not intended for children under 13.\n\n'
                '7. CONTACT US\n'
                'Email: agnishanth609@gmail.com\n'
                'We aim to respond within 48 hours.',
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
                'Effective Date: January 1, 2026\n\n'
                'By using NearTransfer, you agree to these terms.\n\n'
                '1. DESCRIPTION OF SERVICE\n'
                'NearTransfer is a cross-platform file sharing app that enables seamless transfer between Android and Windows devices on the same WiFi network. Features include: File Transfer, App Sharing, Contact Sharing, Shake Connect, Group Transfer, Clipboard Sync, and Speed Test.\n\n'
                '2. USER RESPONSIBILITIES\n'
                'You are solely responsible for files you transfer and must ensure you have legal rights to share any content.\n\n'
                '3. PROHIBITED CONTENT\n'
                'You must NOT use NearTransfer to transfer:\n'
                '• Copyrighted material without authorization\n'
                '• Malware, viruses, or harmful software\n'
                '• Illegal content of any kind\n'
                '• Content exploiting minors\n\n'
                'Security Notice: Installing APK files from external sources may pose security risks. Verify the source before installation.\n\n'
                '4. PREMIUM FEATURES\n'
                '"Remove Ads" is a one-time purchase. All purchases and refunds are handled by Google Play in accordance with their refund policies.\n\n'
                '5. DISCLAIMER\n'
                'The app is provided "as is" without warranties. We are not responsible for data loss during transfers or unauthorized access on unsecured networks.\n\n'
                '6. LIMITATION OF LIABILITY\n'
                'We shall not be liable for any indirect, incidental, or consequential damages.\n\n'
                '7. GOVERNING LAW\n'
                'These terms are governed by the laws of India.\n\n'
                '8. CONTACT US\n'
                'Email: agnishanth609@gmail.com\n'
                'We aim to respond within 48 hours.',
                style: TextStyle(height: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
