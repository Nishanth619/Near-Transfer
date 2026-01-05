import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:glassmorphism/glassmorphism.dart';
import '../../../core/constants.dart';

class HomeActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const HomeActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;
    
    // Responsive sizes
    final cardHeight = isDesktop ? 150.0 : 120.0;
    final iconSize = isDesktop ? 52.0 : 40.0;
    final iconContainerPadding = isDesktop ? 16.0 : 12.0;
    final titleFontSize = isDesktop ? 30.0 : 24.0;
    final subtitleFontSize = isDesktop ? 16.0 : 14.0;
    final arrowSize = isDesktop ? 20.0 : 16.0;
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GlassmorphicContainer(
          width: double.infinity,
          height: cardHeight,
          borderRadius: AppConstants.radiusLarge,
          blur: 20,
          alignment: Alignment.center,
          border: 2,
          linearGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.1),
              Colors.white.withValues(alpha: 0.05),
            ],
          ),
          borderGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.5),
              Colors.white.withValues(alpha: 0.1),
            ],
          ),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? AppConstants.spacingLg : AppConstants.spacingMd,
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(iconContainerPadding),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: iconSize),
                ),
                SizedBox(width: isDesktop ? 24 : 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: isDesktop ? 6 : 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: subtitleFontSize,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, 
                  color: Colors.white.withValues(alpha: 0.3), 
                  size: arrowSize
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
