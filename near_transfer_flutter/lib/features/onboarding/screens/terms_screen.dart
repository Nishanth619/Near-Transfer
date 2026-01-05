import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TermsAndConditionsScreen extends StatefulWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  State<TermsAndConditionsScreen> createState() => _TermsAndConditionsScreenState();
}

class _TermsAndConditionsScreenState extends State<TermsAndConditionsScreen> {
  bool _hasScrolledToEnd = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 50) {
      if (!_hasScrolledToEnd) {
        setState(() => _hasScrolledToEnd = true);
      }
    }
  }

  Future<void> _acceptTerms() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('terms_accepted', true);
    if (mounted) {
      context.go('/home');
    }
  }

  void _declineTerms() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit App?'),
        content: Text(
          kIsWeb 
            ? 'You must accept the Terms and Conditions to use NearTransfer. Please close this browser tab to exit.'
            : 'You must accept the Terms and Conditions to use NearTransfer. Are you sure you want to exit?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (!kIsWeb)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                SystemNavigator.pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Exit', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Max width for content on larger screens
    const double maxContentWidth = 700;
    
    return Scaffold(
      body: Container(
        // Full-screen gradient background
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A237E),
              Color(0xFF283593),
              Color(0xFF00695C),
            ],
          ),
        ),
        child: SafeArea(
          // Center the content with max width
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxContentWidth),
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.description_outlined,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Terms & Conditions',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please read and accept to continue',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Terms Content
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSection(
                                'Welcome to NearTransfer',
                                'By downloading, installing, or using NearTransfer ("the App"), you agree to be bound by these Terms and Conditions. If you do not agree to these terms, please do not use the App.',
                              ),
                              _buildSection(
                                '1. Description of Service',
                                'NearTransfer is a peer-to-peer file sharing application that allows users to transfer files between devices connected to the same local WiFi network. The App does not require internet connectivity for file transfers and operates entirely on your local network.',
                              ),
                              _buildSection(
                                '2. User Responsibilities',
                                '• You are solely responsible for any files you share or receive using this App.\n'
                                '• You agree not to use the App to share illegal, harmful, or copyrighted content without authorization.\n'
                                '• You agree not to use the App for any unlawful purpose or in violation of any applicable laws.\n'
                                '• You are responsible for ensuring you have the necessary rights to share any content.',
                              ),
                              _buildSection(
                                '3. Privacy & Data Collection',
                                '• NearTransfer operates locally on your device and network.\n'
                                '• We do not collect, store, or transmit your personal files to any external servers.\n'
                                '• File transfers occur directly between devices without passing through our servers.\n'
                                '• We may collect anonymous usage statistics to improve the App (can be disabled in Settings).',
                              ),
                              _buildSection(
                                '4. Permissions',
                                'The App requires the following permissions to function:\n\n'
                                'REQUIRED PERMISSIONS:\n'
                                '• Storage Access: To read and write files for sharing\n'
                                '• WiFi/Network Access: To discover devices and transfer files\n\n'
                                'OPTIONAL PERMISSIONS:\n'
                                '• Camera: For QR code scanning to connect devices\n'
                                '• Contacts: For contact sharing feature\n'
                                '• Photos & Videos: For media sharing\n\n'
                                'You may deny optional permissions, but some features may not work.',
                              ),
                              _buildSection(
                                '5. Disclaimer of Warranties',
                                'THE APP IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND. WE DO NOT GUARANTEE THAT:\n'
                                '• The App will meet your specific requirements\n'
                                '• File transfers will be uninterrupted or error-free\n'
                                '• Files will not be corrupted during transfer\n'
                                '\nYou use the App at your own risk.',
                              ),
                              _buildSection(
                                '6. Limitation of Liability',
                                'To the maximum extent permitted by law, we shall not be liable for any indirect, incidental, special, consequential, or punitive damages, including but not limited to loss of data, loss of profits, or business interruption arising out of the use or inability to use the App.',
                              ),
                              _buildSection(
                                '7. Intellectual Property',
                                'All intellectual property rights in the App, including but not limited to the design, graphics, and source code, are owned by NearTransfer. You may not copy, modify, distribute, or reverse engineer the App without our written consent.',
                              ),
                              _buildSection(
                                '8. Third-Party Services',
                                'The App may display advertisements provided by Google AdMob. These ads are subject to Google\'s privacy policy and terms of service. We are not responsible for the content of third-party advertisements.',
                              ),
                              _buildSection(
                                '9. Updates & Changes',
                                'We reserve the right to modify these Terms and Conditions at any time. Continued use of the App after changes constitutes acceptance of the new terms. We may also update the App with new features, bug fixes, or security patches.',
                              ),
                              _buildSection(
                                '10. Contact Information',
                                'If you have any questions about these Terms and Conditions, please contact us through the App\'s feedback feature in Settings.',
                              ),
                              const SizedBox(height: 20),
                              Center(
                                child: Text(
                                  'Last Updated: January 2026',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Action Buttons
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _declineTerms,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white70),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Decline',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _acceptTerms,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF1A237E),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'I Accept',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A237E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
