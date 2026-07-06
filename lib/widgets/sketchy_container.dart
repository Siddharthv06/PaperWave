import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class SketchyContainer extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final double borderWidth;
  final BorderRadius? borderRadius;
  final bool isCircle;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final AlignmentGeometry? alignment;
  final Offset shadowOffset;
  final bool hasPencilShading;

  const SketchyContainer({
    super.key,
    required this.child,
    this.backgroundColor,
    this.borderWidth = 2,
    this.borderRadius,
    this.isCircle = false,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.alignment,
    this.shadowOffset = const Offset(3, 3),
    this.hasPencilShading = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final lineColor = isDark
        ? const Color(0xFFE5E5DE)
        : const Color(0xff1E1E1E);

    final bg =
        backgroundColor ??
        (isDark ? const Color(0xff2A2A2A) : const Color(0xffFEFCF7));

    return Container(
      width: width,
      height: height,
      margin: margin,
      alignment: alignment,
      child: CustomPaint(
        painter: SketchyBoxPainter(
          backgroundColor: bg,
          lineColor: lineColor,
          borderWidth: borderWidth,
          borderRadius: borderRadius ?? BorderRadius.circular(22),
          shadowOffset: shadowOffset,
          isCircle: isCircle,
          hasPencilShading: hasPencilShading,
        ),
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ),
    );
  }
}

class SketchyBoxPainter extends CustomPainter {
  final Color backgroundColor;
  final Color lineColor;
  final double borderWidth;
  final BorderRadius borderRadius;
  final Offset shadowOffset;
  final bool isCircle;
  final bool hasPencilShading;

  SketchyBoxPainter({
    required this.backgroundColor,
    required this.lineColor,
    required this.borderWidth,
    required this.borderRadius,
    required this.shadowOffset,
    required this.isCircle,
    required this.hasPencilShading,
  });

  final math.Random random = math.Random(7);

  Path _createSketchPath(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();

    if (isCircle) {
      final radius = w / 2;
      final center = Offset(w / 2, h / 2);
      const steps = 32;
      double j() => (random.nextDouble() - .5) * 0.7;

      final startAngle = 0.0;
      final startX = center.dx + (radius + j()) * math.cos(startAngle);
      final startY = center.dy + (radius + j()) * math.sin(startAngle);
      path.moveTo(startX, startY);

      for (int i = 1; i <= steps; i++) {
        final angle = (i * 2 * math.pi) / steps;
        final x = center.dx + (radius + j()) * math.cos(angle);
        final y = center.dy + (radius + j()) * math.sin(angle);
        path.lineTo(x, y);
      }
      path.close();
      return path;
    }

    const radius = 22.0;
    const jitter = 0.7;

    double j() => (random.nextDouble() - .5) * jitter;

    // Start
    path.moveTo(radius + j(), j());

    // TOP
    for (double x = radius; x < w - radius; x += 18) {
      path.lineTo(x + j(), j());
    }

    // Top-right curve
    path.quadraticBezierTo(w + j(), j(), w + j(), radius + j());

    // RIGHT
    for (double y = radius; y < h - radius; y += 18) {
      path.lineTo(w + j(), y + j());
    }

    // Bottom-right curve
    path.quadraticBezierTo(w + j(), h + j(), w - radius + j(), h + j());

    // BOTTOM
    for (double x = w - radius; x > radius; x -= 18) {
      path.lineTo(x + j(), h + j());
    }

    // Bottom-left curve
    path.quadraticBezierTo(j(), h + j(), j(), h - radius + j());

    // LEFT
    for (double y = h - radius; y > radius; y -= 18) {
      path.lineTo(j(), y + j());
    }

    // Top-left curve
    path.quadraticBezierTo(j(), j(), radius + j(), j());

    path.close();

    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = _createSketchPath(size);

    // ==========================
    // Paper Grain
    // ==========================
    final grainPaint = Paint()
      ..color = lineColor.withValues(alpha: .02)
      ..style = PaintingStyle.fill;

    for (double x = 0; x < w; x += 8) {
      for (double y = 0; y < h; y += 8) {
        canvas.drawCircle(
          Offset(x + (random.nextDouble() * 2), y + (random.nextDouble() * 2)),
          .4,
          grainPaint,
        );
      }
    }

    // ==========================
    // Shadow
    // ==========================
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: .16)
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(shadowOffset.dx, shadowOffset.dy);
    canvas.drawPath(path, shadowPaint);

    canvas.translate(.8, .5);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();

    // ==========================
    // Fill
    // ==========================
    final fillPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, fillPaint);

    // ==========================
    // Pencil Scribble
    // ==========================
    // ponytail: skip diagonal shading on web — (w+h)/4 drawLine calls per widget per frame
    if (!kIsWeb &&
        hasPencilShading &&
        backgroundColor != Colors.white &&
        backgroundColor != Colors.transparent) {
      canvas.save();
      canvas.clipPath(path);

      final shadePaint = Paint()
        ..color = lineColor.withValues(alpha: .12)
        ..strokeWidth = .9
        ..strokeCap = StrokeCap.round;

      for (double i = -h; i < w + h; i += 4) {
        final dx = (random.nextDouble() - .5) * 3;
        canvas.drawLine(Offset(i + dx, 0), Offset(i + h + dx, h), shadePaint);
      }

      for (double i = -h; i < w + h; i += 10) {
        final dx = (random.nextDouble() - .5) * 3;
        canvas.drawLine(Offset(i + dx, h), Offset(i + h + dx, 0), shadePaint);
      }

      canvas.restore();
    }

    // ==========================
    // Border
    // ==========================
    final borderPaint = Paint()
      ..color = lineColor
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final secondPaint = Paint()
      ..color = lineColor.withValues(alpha: .75)
      ..strokeWidth = borderWidth * .75
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final thirdPaint = Paint()
      ..color = lineColor.withValues(alpha: .45)
      ..strokeWidth = borderWidth * .55
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, borderPaint);

    canvas.save();
    canvas.translate(.8, -.6);
    canvas.drawPath(path, secondPaint);
    canvas.restore();

    canvas.save();
    canvas.translate(-.7, .9);
    canvas.drawPath(path, secondPaint);
    canvas.restore();

    canvas.save();
    canvas.translate(.4, .3);
    canvas.drawPath(path, thirdPaint);
    canvas.restore();

    // ==========================
    // Tiny Pencil Imperfections
    // ==========================
    final scratchPaint = Paint()
      ..color = lineColor.withValues(alpha: .18)
      ..strokeWidth = .6;

    for (int i = 0; i < 40; i++) {
      final x = random.nextDouble() * w;
      final y = random.nextDouble() * h;

      canvas.drawLine(
        Offset(x, y),
        Offset(x + random.nextDouble() * 4, y + random.nextDouble() * 4),
        scratchPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SketchyBoxPainter oldDelegate) {
    return oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.shadowOffset != shadowOffset ||
        oldDelegate.isCircle != isCircle ||
        oldDelegate.hasPencilShading != hasPencilShading;
  }
}

class SketchyLogo extends StatelessWidget {
  final double size;
  final Color? color;

  const SketchyLogo({
    super.key,
    this.size = 24.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = isDark ? const Color(0xFFFAF6EE) : const Color(0xFF1E1E1E);
    final paintColor = color ?? defaultColor;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LogoPainter(color: paintColor),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  final Color color;
  _LogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    final random = math.Random(12);
    double j() => (random.nextDouble() - 0.5) * 1.5;

    // Left note head (oval)
    final leftHeadPath = Path();
    leftHeadPath.moveTo(w * 0.25 + j(), h * 0.75 + j());
    leftHeadPath.quadraticBezierTo(w * 0.15 + j(), h * 0.70 + j(), w * 0.12 + j(), h * 0.80 + j());
    leftHeadPath.quadraticBezierTo(w * 0.15 + j(), h * 0.90 + j(), w * 0.28 + j(), h * 0.85 + j());
    leftHeadPath.quadraticBezierTo(w * 0.32 + j(), h * 0.75 + j(), w * 0.25 + j(), h * 0.75 + j());
    leftHeadPath.close();

    // Right note head (oval)
    final rightHeadPath = Path();
    rightHeadPath.moveTo(w * 0.65 + j(), h * 0.65 + j());
    rightHeadPath.quadraticBezierTo(w * 0.55 + j(), h * 0.60 + j(), w * 0.52 + j(), h * 0.70 + j());
    rightHeadPath.quadraticBezierTo(w * 0.55 + j(), h * 0.80 + j(), w * 0.68 + j(), h * 0.75 + j());
    rightHeadPath.quadraticBezierTo(w * 0.72 + j(), h * 0.65 + j(), w * 0.65 + j(), h * 0.65 + j());
    rightHeadPath.close();

    // Fill note heads
    canvas.drawPath(leftHeadPath, fillPaint);
    canvas.drawPath(rightHeadPath, fillPaint);

    // Draw note heads borders
    canvas.drawPath(leftHeadPath, paint);
    canvas.drawPath(rightHeadPath, paint);

    // Stems
    final leftStem = Path();
    leftStem.moveTo(w * 0.28 + j(), h * 0.80 + j());
    leftStem.lineTo(w * 0.28 + j(), h * 0.20 + j());
    canvas.drawPath(leftStem, paint);
    
    final rightStem = Path();
    rightStem.moveTo(w * 0.68 + j(), h * 0.70 + j());
    rightStem.lineTo(w * 0.68 + j(), h * 0.10 + j());
    canvas.drawPath(rightStem, paint);

    // Beam
    final beam = Path();
    beam.moveTo(w * 0.28 + j(), h * 0.20 + j());
    beam.lineTo(w * 0.68 + j(), h * 0.10 + j());
    
    paint.strokeWidth = 3.5;
    canvas.drawPath(beam, paint);
    paint.strokeWidth = 2.0;

    // Small sketchy sound wave ripples
    final ripple1 = Path()
      ..moveTo(w * 0.80 + j(), h * 0.25 + j())
      ..quadraticBezierTo(w * 0.88 + j(), h * 0.35 + j(), w * 0.82 + j(), h * 0.45 + j());
    canvas.drawPath(ripple1, paint);

    final ripple2 = Path()
      ..moveTo(w * 0.86 + j(), h * 0.20 + j())
      ..quadraticBezierTo(w * 0.95 + j(), h * 0.35 + j(), w * 0.88 + j(), h * 0.50 + j());
    canvas.drawPath(ripple2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
