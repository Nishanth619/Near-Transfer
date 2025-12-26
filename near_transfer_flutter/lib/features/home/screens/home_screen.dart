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
    // Max content width for better layout on web/desktop
    const double maxContentWidth = 700;
    
    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxContentWidth),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const SizedBox(height: 20),
                
                // App Title with Help Button
                FadeInDown(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.near_me, color: Colors.white, size: 32),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'NearTransfer',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
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
                
                const SizedBox(height: 60),
                
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
                
                const SizedBox(height: 20),
                
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
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.2),
                                Colors.white.withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
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
                                    color: Colors.white.withOpacity(0.9),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'How it works',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Connect devices on the same WiFi network and share files instantly without internet',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 13,
                                  height: 1.4,
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
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 20),
                
                // Banner Ad
                const Center(child: BannerAdWidget()),
                
                const SizedBox(height: 100), // Space for bottom nav
              ],
            ),
          ),
        ),
          ),
        ),
      ),
    );
  }
}
