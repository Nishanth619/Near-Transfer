import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import '../../../shared/widgets/animated_background.dart';
import '../../../shared/widgets/help_button.dart';
import '../../../shared/widgets/banner_ad_widget.dart';
import '../../../core/constants.dart';

class MoreFeaturesScreen extends StatelessWidget {
  const MoreFeaturesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final features = [
      _FeatureItem(
        title: 'Browse Files',
        subtitle: 'Explore & manage files',
        icon: Icons.folder_rounded,
        color: const Color(0xFF3B82F6),
        route: '/file-manager',
      ),
      _FeatureItem(
        title: 'Share Apps',
        subtitle: 'Send installed apps',
        icon: Icons.apps_rounded,
        color: const Color(0xFF8B5CF6),
        route: '/app-manager',
      ),
      _FeatureItem(
        title: 'Clipboard',
        subtitle: 'Sync & share text',
        icon: Icons.content_paste_rounded,
        color: const Color(0xFFA855F7),
        route: '/clipboard',
      ),
      _FeatureItem(
        title: 'Contacts',
        subtitle: 'Share your contacts',
        icon: Icons.contacts_rounded,
        color: const Color(0xFFF97316),
        route: '/contact-manager',
      ),
      _FeatureItem(
        title: 'Shake',
        subtitle: 'Quick connect',
        icon: Icons.vibration_rounded,
        color: const Color(0xFF14B8A6),
        route: '/shake-connect',
      ),
      _FeatureItem(
        title: 'Speed Test',
        subtitle: 'Check connection',
        icon: Icons.speed_rounded,
        color: const Color(0xFFEF4444),
        route: '/speed-test',
      ),
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: AnimatedBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: FadeInDown(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.grid_view_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'More Features',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Explore all tools',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const HelpButton(
                      featureName: 'More Features',
                      helpText: 'Access additional NearTransfer tools:\n\n• Browse Files: Select files to share\n• Share Apps: Send installed apps to other devices\n• Clipboard: Sync copied text between devices\n• Contacts: Share contact cards\n• Shake: Quick connect by shaking phones\n• Speed Test: Check transfer speed',
                    ),
                  ],
                ),
              ),
            ),
            
            // Features Grid
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: features.length,
                  itemBuilder: (context, index) {
                    return FadeInUp(
                      delay: Duration(milliseconds: 100 * index),
                      child: _buildFeatureCard(
                        context,
                        feature: features[index],
                      ),
                    );
                  },
                ),
              ),
            ),
            
            // Banner Ad at bottom
            SafeArea(
              top: false,
              child: const BannerAdWidget(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required _FeatureItem feature,
  }) {
    return GestureDetector(
      onTap: () => context.push(feature.route),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.15),
                  Colors.white.withOpacity(0.05),
                ],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Stack(
              children: [
                // Background accent
                Positioned(
                  top: -15,
                  right: -15,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: feature.color.withOpacity(0.3),
                    ),
                  ),
                ),
                
                // Content
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon container
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: feature.color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: feature.color.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          feature.icon,
                          size: 28,
                          color: feature.color,
                        ),
                      ),
                      
                      const SizedBox(height: 10),
                      
                      // Title
                      Text(
                        feature.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 2),
                      
                      // Subtitle
                      Text(
                        feature.subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;

  const _FeatureItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
  });
}
