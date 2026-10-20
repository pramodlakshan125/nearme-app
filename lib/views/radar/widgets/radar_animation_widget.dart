import 'dart:math' as math;
import 'package:flutter/material.dart';

class RadarAnimationWidget extends StatefulWidget {
  final bool isScanning;
  final Widget child;

  const RadarAnimationWidget({
    super.key,
    required this.isScanning,
    required this.child,
  });

  @override
  State<RadarAnimationWidget> createState() => _RadarAnimationWidgetState();
}

class _RadarAnimationWidgetState extends State<RadarAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    if (widget.isScanning) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant RadarAnimationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isScanning && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isScanning && _controller.isAnimating) {
      _controller.stop();
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
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _RadarPainter(
            angle: _controller.value * 2 * math.pi,
            isScanning: widget.isScanning,
          ),
          child: widget.child,
        );
      },
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double angle;
  final bool isScanning;

  _RadarPainter({required this.angle, required this.isScanning});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2;

    final circlePaint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final axisPaint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw concentric radar circles
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, (maxRadius / 4) * i, circlePaint);
    }

    // Draw axis lines
    canvas.drawLine(Offset(center.dx - maxRadius, center.dy),
        Offset(center.dx + maxRadius, center.dy), axisPaint);
    canvas.drawLine(Offset(center.dx, center.dy - maxRadius),
        Offset(center.dx, center.dy + maxRadius), axisPaint);

    // Draw sweeping radar line and gradient arc if scanning
    if (isScanning) {
      final sweepPaint = Paint()
        ..shader = SweepGradient(
          center: Alignment.center,
          startAngle: 0.0,
          endAngle: math.pi / 2,
          colors: [
            Colors.cyanAccent.withOpacity(0.0),
            Colors.cyanAccent.withOpacity(0.35),
          ],
          transform: GradientRotation(angle),
        ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

      canvas.drawCircle(center, maxRadius, sweepPaint);

      // Radar sweep line
      final lineX = center.dx + maxRadius * math.cos(angle);
      final lineY = center.dy + maxRadius * math.sin(angle);
      final linePaint = Paint()
        ..color = Colors.cyanAccent
        ..strokeWidth = 2.0;

      canvas.drawLine(center, Offset(lineX, lineY), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return oldDelegate.angle != angle || oldDelegate.isScanning != isScanning;
  }
}
