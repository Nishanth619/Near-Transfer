import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../../core/constants.dart';

class AnimatedBackground extends StatelessWidget {
  final Widget child;

  const AnimatedBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background Gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1A237E), // Deep Blue
                Color(0xFF283593),
                Color(0xFF00695C), // Teal-ish
              ],
            ),
          ),
        ),
        
        // Animated Blobs
        Positioned(
          top: -100,
          left: -100,
          child: FadeIn(
            duration: const Duration(seconds: 2),
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentStart.withOpacity(0.3),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentStart.withOpacity(0.3),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -50,
          right: -50,
          child: FadeIn(
            duration: const Duration(seconds: 2),
            delay: const Duration(milliseconds: 500),
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentEnd.withOpacity(0.3),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentEnd.withOpacity(0.3),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Glass Overlay (Optional, if we want full screen glass)
        // For now, we'll just let the content sit on top
        
        SafeArea(child: child),
      ],
    );
  }
}
