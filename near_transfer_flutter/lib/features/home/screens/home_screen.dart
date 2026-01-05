import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/widgets/animated_background.dart';
import '../../../shared/widgets/help_button.dart';
import '../../../shared/widgets/banner_ad_widget.dart';
import '../widgets/home_action_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _infoCardDismissedKey = 'home_info_card_dismissed';
  bool _showInfoCard = true;

  @override
  void initState() {
    super.initState();
    _loadInfoCardState();
  }

  Future<void> _loadInfoCardState() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool(_infoCardDismissedKey) ?? false;
    if (mounted) {
      setState(() => _showInfoCard = !dismissed);
    }
  }

  Future<void> _dismissInfoCard() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_infoCardDismissedKey, true);
    if (mounted) {
      setState(() => _showInfoCard = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;
    
    // Responsive max content width
    final maxContentWidth = isDesktop ? 900.0 : 700.0;
    final horizontalPadding = isDesktop ? 40.0 : 24.0;
    final titleFontSize = isDesktop ? 36.0 : 28.0;
    final appIconSize = isDesktop ? 40.0 : 32.0;
    final spacingAfterHeader = isDesktop ? 80.0 : 60.0;
    final cardSpacing = isDesktop ? 28.0 : 20.0;
    
    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: Column(
                children: [
                  // Scrollable content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(horizontalPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                    const SizedBox(height: 20),
                    
                    // App Title with Help Button
                    FadeInDown(
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(isDesktop ? 12 : 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
                            ),
                            child: Icon(Icons.near_me, color: Colors.white, size: appIconSize),
                          ),
                          SizedBox(width: isDesktop ? 20 : 16),
                          Expanded(
                            child: Text(
                              'NearTransfer',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: titleFontSize,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          const HelpButton(
                            featureName: 'NearTransfer',
                            helpText: 'Welcome to NearTransfer! Share files with nearby devices on the same WiFi network instantly - no internet needed.\n\n• Send Files: Select files and find nearby devices\n• Receive Files: Wait for incoming files from others\n\nMake sure both devices are on the same WiFi!',
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: spacingAfterHeader),
                    
                    // Send Files Card
                    FadeInUp(
                      delay: const Duration(milliseconds: 200),
                      child: HomeActionCard(
                        title: 'Send Files',
                        subtitle: 'Share files with nearby devices',
                        icon: Icons.send,
                        color: Colors.blue,
                        onTap: () => context.push('/discovery'),
                      ),
                    ),
                    
                    SizedBox(height: cardSpacing),
                    
                    // Receive Files Card
                    FadeInUp(
                      delay: const Duration(milliseconds: 300),
                      child: HomeActionCard(
                        title: 'Receive Files',
                        subtitle: 'Get files from nearby devices',
                        icon: Icons.download,
                        color: Colors.green,
                        onTap: () => context.push('/receive'),
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Dismissible Info Card
                    if (_showInfoCard)
                      FadeInUp(
                        delay: const Duration(milliseconds: 400),
                        child: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.2),
                                    Colors.white.withValues(alpha: 0.1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: Colors.white.withValues(alpha: 0.9),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'How it works',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.9),
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Connect devices on the same WiFi network and share files instantly without internet',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      fontSize: 12,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Dismiss button
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: _dismissInfoCard,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 80), // Space for bottom nav
                  ],
                ),
                    ),
                  ),
                  
                  // Fixed Banner Ad at bottom (not scrollable)
                  SafeArea(
                    top: false,
                    child: const BannerAdWidget(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
