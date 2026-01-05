import 'package:flutter/material.dart';
import 'dart:math' as math;

/// A circular progress indicator with percentage display
/// Similar to Xender/ShareIt style
class CircularTransferProgress extends StatelessWidget {
  final double progress;
  final double size;
  final double strokeWidth;
  final Color progressColor;
  final Color backgroundColor;
  final Widget? centerWidget;
  final bool showPercentage;
  final String? speedText;
  final String? etaText;

  const CircularTransferProgress({
    super.key,
    required this.progress,
    this.size = 150,
    this.strokeWidth = 10,
    this.progressColor = Colors.green,
    this.backgroundColor = Colors.white24,
    this.centerWidget,
    this.showPercentage = true,
    this.speedText,
    this.etaText,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          CustomPaint(
            size: Size(size, size),
            painter: _CircularProgressPainter(
              progress: progress,
              strokeWidth: strokeWidth,
              progressColor: progressColor,
              backgroundColor: backgroundColor,
            ),
          ),
          // Center content
          if (centerWidget != null)
            centerWidget!
          else if (showPercentage)
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${(progress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: size * 0.2,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (speedText != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    speedText!,
                    style: TextStyle(
                      fontSize: size * 0.09,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (etaText != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    etaText!,
                    style: TextStyle(
                      fontSize: size * 0.08,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color progressColor;
  final Color backgroundColor;

  _CircularProgressPainter({
    required this.progress,
    required this.strokeWidth,
    required this.progressColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background arc
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: [
          progressColor.withValues(alpha: 0.6),
          progressColor,
          progressColor,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Start from top
      sweepAngle,
      false,
      progressPaint,
    );

    // Glow effect at progress tip
    if (progress > 0.01) {
      final tipAngle = -math.pi / 2 + sweepAngle;
      final tipX = center.dx + radius * math.cos(tipAngle);
      final tipY = center.dy + radius * math.sin(tipAngle);
      
      final glowPaint = Paint()
        ..color = progressColor.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      
      canvas.drawCircle(Offset(tipX, tipY), strokeWidth / 2, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Animated circular progress with pulse effect
class AnimatedCircularProgress extends StatefulWidget {
  final double progress;
  final double size;
  final Color progressColor;
  final String? speedText;
  final String? etaText;
  final bool isPaused;

  const AnimatedCircularProgress({
    super.key,
    required this.progress,
    this.size = 150,
    this.progressColor = Colors.green,
    this.speedText,
    this.etaText,
    this.isPaused = false,
  });

  @override
  State<AnimatedCircularProgress> createState() => _AnimatedCircularProgressState();
}

class _AnimatedCircularProgressState extends State<AnimatedCircularProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    // Only start animation if not paused
    if (!widget.isPaused) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AnimatedCircularProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPaused != widget.isPaused) {
      if (widget.isPaused) {
        _pulseController.stop();
      } else {
        _pulseController.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseScale = 1.0 + _pulseController.value * 0.03;
        return Transform.scale(
          scale: pulseScale,
          child: CircularTransferProgress(
            progress: widget.progress,
            size: widget.size,
            progressColor: widget.progressColor,
            speedText: widget.speedText,
            etaText: widget.etaText,
          ),
        );
      },
    );
  }
}
