import 'package:flutter/material.dart';

class AmbientBackground extends StatelessWidget {
  final String style; // 'Grid', 'Ruled', 'Dotted', 'Blank'

  const AmbientBackground({super.key, required this.style});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox.expand(
      child: CustomPaint(
        painter: GridPaperPainter(isDark: isDark, style: style),
      ),
    );
  }
}

class GridPaperPainter extends CustomPainter {
  final bool isDark;
  final String style;

  GridPaperPainter({required this.isDark, required this.style});

  @override
  void paint(Canvas canvas, Size size) {
    final paperColor = isDark ? const Color(0xFF1B1C1E) : const Color(0xFFFAF8F3);
    canvas.drawColor(paperColor, BlendMode.src);

    final gridPaint = Paint()
      ..color = isDark 
          ? const Color(0xFF26262B) 
          : const Color(0xFFEBE8DF) 
      ..strokeWidth = 1.0;

    const step = 24.0;

    if (style == 'Grid') {
      for (double x = 0.0; x < size.width; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
      for (double y = 0.0; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
    } else if (style == 'Ruled') {
      for (double y = 48.0; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
    } else if (style == 'Dotted') {
      for (double x = step; x < size.width; x += step) {
        for (double y = step; y < size.height; y += step) {
          canvas.drawCircle(Offset(x, y), 1.2, gridPaint);
        }
      }
    }

    // Always draw red notebook margins except in fully Blank mode
    if (style != 'Blank') {
      final marginPaint = Paint()
        ..color = isDark 
            ? const Color(0xFF332B2B) 
            : const Color(0xFFF3B0B0) 
        ..strokeWidth = 1.2;

      canvas.drawLine(const Offset(48, 0), Offset(48, size.height), marginPaint);
      canvas.drawLine(const Offset(51, 0), Offset(51, size.height), marginPaint);
    }
  }

  @override
  bool shouldRepaint(covariant GridPaperPainter oldDelegate) {
    return oldDelegate.isDark != isDark || oldDelegate.style != style;
  }
}
