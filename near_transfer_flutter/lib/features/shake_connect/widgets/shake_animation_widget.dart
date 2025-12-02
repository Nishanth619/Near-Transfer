import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Animated widget showing phone shaking
class ShakeAnimationWidget extends StatefulWidget {
  final bool isShaking;
  final double size;

  const ShakeAnimationWidget({
    super.key,
    this.isShaking = false,
    this.size = 120,
  });

  @override
  State<ShakeAnimationWidget> createState() => _ShakeAnimationWidgetState();
}

class _ShakeAnimationWidgetState extends State<ShakeAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticIn),
    );
  }

  @override
  void didUpdateWidget(ShakeAnimationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isShaking && !oldWidget.isShaking) {
      _controller.repeat(reverse: true);
    } else if (!widget.isShaking && oldWidget.isShaking) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.rotate(
          angle: widget.isShaking ? _shakeAnimation.value * math.pi / 180 : 0,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.phone_android,
              size: widget.size * 0.6,
              color: const Color(0xFF6C63FF),
            ),
          ),
        );
      },
    );
  }
}
