import 'dart:math' as math;
import 'package:flutter/material.dart';

class CustomSpinner extends StatefulWidget {
  final double size;
  final Color color;
  final Duration duration;

  const CustomSpinner({
    super.key,
    this.size = 50.0,
    this.color = Colors.blue,
    this.duration = const Duration(milliseconds: 1200),
  });

  @override
  State<CustomSpinner> createState() => _CustomSpinnerState();
}

class _CustomSpinnerState extends State<CustomSpinner> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 2 * math.pi,
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: SpinnerPainter(color: widget.color),
          ),
        );
      },
    );
  }
}

class SpinnerPainter extends CustomPainter {
  final Color color;

  SpinnerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = radius * 0.15
      ..strokeCap = StrokeCap.round;

    // Draw 12 spokes with varying opacity
    for (int i = 0; i < 12; i++) {
      final angle = (i * 30) * math.pi / 180;
      final opacity = 1.0 - (i / 12);
      paint.color = color.withValues(alpha: opacity);

      final startPoint = Offset(
        center.dx + radius * 0.3 * math.cos(angle),
        center.dy + radius * 0.3 * math.sin(angle),
      );

      final endPoint = Offset(
        center.dx + radius * 0.7 * math.cos(angle),
        center.dy + radius * 0.7 * math.sin(angle),
      );

      canvas.drawLine(startPoint, endPoint, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}