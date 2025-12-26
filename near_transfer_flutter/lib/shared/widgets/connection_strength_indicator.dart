import 'package:flutter/material.dart';

/// WiFi-style signal strength indicator
class ConnectionStrengthIndicator extends StatelessWidget {
  /// Strength from 0.0 to 1.0
  final double strength;
  final double size;
  final Color activeColor;
  final Color inactiveColor;

  const ConnectionStrengthIndicator({
    super.key,
    required this.strength,
    this.size = 24,
    this.activeColor = Colors.green,
    this.inactiveColor = Colors.white24,
  });

  @override
  Widget build(BuildContext context) {
    // Convert strength to bars (0-4)
    final bars = (strength * 4).ceil().clamp(0, 4);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (index) {
        final barHeight = size * (0.3 + (index * 0.175)); // Increasing heights
        final isActive = index < bars;
        
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: size * 0.05),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: size * 0.15,
            height: barHeight,
            decoration: BoxDecoration(
              color: isActive ? activeColor : inactiveColor,
              borderRadius: BorderRadius.circular(size * 0.05),
              boxShadow: isActive ? [
                BoxShadow(
                  color: activeColor.withOpacity(0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ] : null,
            ),
          ),
        );
      }),
    );
  }

  /// Get color based on strength level
  static Color getStrengthColor(double strength) {
    if (strength >= 0.7) return Colors.green;
    if (strength >= 0.4) return Colors.orange;
    return Colors.red;
  }

  /// Get label based on strength level
  static String getStrengthLabel(double strength) {
    if (strength >= 0.8) return 'Excellent';
    if (strength >= 0.6) return 'Good';
    if (strength >= 0.4) return 'Fair';
    if (strength >= 0.2) return 'Weak';
    return 'Poor';
  }
}

/// A styled connection indicator with label
class ConnectionStrengthBadge extends StatelessWidget {
  final double strength;
  final bool showLabel;

  const ConnectionStrengthBadge({
    super.key,
    required this.strength,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = ConnectionStrengthIndicator.getStrengthColor(strength);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConnectionStrengthIndicator(
            strength: strength,
            size: 16,
            activeColor: color,
          ),
          if (showLabel) ...[
            const SizedBox(width: 6),
            Text(
              ConnectionStrengthIndicator.getStrengthLabel(strength),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
