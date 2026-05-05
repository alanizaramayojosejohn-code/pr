import 'dart:math';
import 'package:flutter/material.dart';

import '../data/progress_repository.dart';

class WorkoutBarChart extends StatelessWidget {
  const WorkoutBarChart({super.key, required this.weeks, required this.color});
  final List<WeeklyCount> weeks;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final maxCount =
        weeks.isEmpty ? 0 : weeks.map((w) => w.count).reduce(max);
    if (maxCount == 0) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: Text(
            'Sin entrenamientos registrados aún',
            style: TextStyle(fontSize: 12, color: Color(0x80FFFFFF)),
          ),
        ),
      );
    }
    return SizedBox(
      height: 160,
      child: CustomPaint(
        painter: _BarPainter(weeks: weeks, maxCount: maxCount, color: color),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  const _BarPainter({
    required this.weeks,
    required this.maxCount,
    required this.color,
  });
  final List<WeeklyCount> weeks;
  final int maxCount;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (weeks.isEmpty) return;

    const labelH = 20.0;
    const topPad = 18.0;
    final chartH = size.height - labelH - topPad;
    final n = weeks.length;
    final slotW = size.width / n;
    final barW = (slotW * 0.55).clamp(4.0, 28.0);

    final fillPaint = Paint()..color = color;
    final emptyPaint = Paint()..color = color.withValues(alpha: 0.12);

    for (var i = 0; i < n; i++) {
      final w = weeks[i];
      final cx = slotW * i + slotW / 2;

      if (w.count > 0) {
        final barH = (w.count / maxCount) * chartH;
        final barTop = topPad + chartH - barH;

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - barW / 2, barTop, barW, barH),
            const Radius.circular(4),
          ),
          fillPaint,
        );

        // Count label above bar
        final tp = TextPainter(
          text: TextSpan(
            text: '${w.count}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(cx - tp.width / 2, barTop - tp.height - 2));
      } else {
        // Faint baseline tick for empty weeks
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - barW / 2, topPad + chartH - 3, barW, 3),
            const Radius.circular(2),
          ),
          emptyPaint,
        );
      }

      // X label (week start day)
      final ltp = TextPainter(
        text: TextSpan(
          text: w.weekLabel,
          style: TextStyle(
            fontSize: 9,
            color: Colors.white.withValues(alpha: 0.35),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      ltp.paint(
          canvas, Offset(cx - ltp.width / 2, topPad + chartH + 4));
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.weeks != weeks ||
      old.maxCount != maxCount ||
      old.color != color;
}
