import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated dotted/dashed arrow pointing directly from the explanation card
/// toward the highlighted target element.
class AnimatedCoachArrow extends StatelessWidget {
  final Offset start;
  final Offset end;
  final double animationValue;
  final double pulseValue;

  const AnimatedCoachArrow({
    super.key,
    required this.start,
    required this.end,
    required this.animationValue,
    this.pulseValue = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _DottedArrowPainter(
        start: start,
        end: end,
        dashPhase: animationValue,
        pulseOffset: pulseValue,
      ),
    );
  }
}

class _DottedArrowPainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final double dashPhase;
  final double pulseOffset;

  _DottedArrowPainter({
    required this.start,
    required this.end,
    required this.dashPhase,
    required this.pulseOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    // If points are practically identical, don't paint
    if (distance < 12.0) return;

    // Unit vector towards end
    final ux = dx / distance;
    final uy = dy / distance;

    // Apply subtle pulse along the vector (shifts tip 2-3px back & forth)
    final pulsedEnd = Offset(end.dx + ux * (pulseOffset * 3.0), end.dy + uy * (pulseOffset * 3.0));

    // Construct curve or straight path
    final path = Path();
    path.moveTo(start.dx, start.dy);

    // Slight elegant curve if there is horizontal offset
    if (dx.abs() > 15.0) {
      final controlX = start.dx + dx * 0.2;
      final controlY = start.dy + dy * 0.8;
      path.quadraticBezierTo(controlX, controlY, pulsedEnd.dx - ux * 8.0, pulsedEnd.dy - uy * 8.0);
    } else {
      path.lineTo(pulsedEnd.dx - ux * 8.0, pulsedEnd.dy - uy * 8.0);
    }

    // Paint configuration
    const dashLength = 4.5;
    const dashGap = 4.0;
    const totalDash = dashLength + dashGap;

    // Glowing outer shadow paint
    final glowPaint = Paint()
      ..color = const Color(0xFF06B6D4).withValues(alpha: 0.45)
      ..strokeWidth = 3.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

    // Main sharp cyan dash paint
    final linePaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Arrowhead paint
    final headPaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Draw marching dashes along the path
    for (final metric in path.computeMetrics()) {
      final pathLength = metric.length;
      final offsetPhase = (dashPhase * totalDash) % totalDash;

      double currentDistance = offsetPhase;
      while (currentDistance < pathLength) {
        final startDist = currentDistance;
        final endDist = math.min(currentDistance + dashLength, pathLength);

        if (endDist > startDist) {
          final dashSubPath = metric.extractPath(startDist, endDist);
          canvas.drawPath(dashSubPath, glowPaint);
          canvas.drawPath(dashSubPath, linePaint);
        }
        currentDistance += totalDash;
      }
    }

    // Draw Arrowhead at pulsedEnd pointing in (ux, uy) direction
    final angle = math.atan2(uy, ux);
    const arrowHeadLength = 8.5;
    const arrowHeadAngle = 0.52; // ~30 degrees

    final leftWing = Offset(
      pulsedEnd.dx - arrowHeadLength * math.cos(angle - arrowHeadAngle),
      pulsedEnd.dy - arrowHeadLength * math.sin(angle - arrowHeadAngle),
    );
    final rightWing = Offset(
      pulsedEnd.dx - arrowHeadLength * math.cos(angle + arrowHeadAngle),
      pulsedEnd.dy - arrowHeadLength * math.sin(angle + arrowHeadAngle),
    );

    final arrowHeadPath = Path()
      ..moveTo(leftWing.dx, leftWing.dy)
      ..lineTo(pulsedEnd.dx, pulsedEnd.dy)
      ..lineTo(rightWing.dx, rightWing.dy);

    // Glow and draw head
    canvas.drawPath(arrowHeadPath, glowPaint);
    canvas.drawPath(arrowHeadPath, headPaint);
  }

  @override
  bool shouldRepaint(covariant _DottedArrowPainter oldDelegate) {
    return oldDelegate.dashPhase != dashPhase ||
        oldDelegate.pulseOffset != pulseOffset ||
        oldDelegate.start != start ||
        oldDelegate.end != end;
  }
}
