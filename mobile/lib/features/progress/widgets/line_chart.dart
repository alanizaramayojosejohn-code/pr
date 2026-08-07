import 'dart:math';

import 'package:flutter/material.dart';

class ChartPoint {
  const ChartPoint({required this.date, required this.value});
  final String date;
  final double value;
}

class ChartSeries {
  const ChartSeries({
    required this.label,
    required this.color,
    required this.points,
  });
  final String label;
  final Color color;
  final List<ChartPoint> points;
}

class LineChart extends StatefulWidget {
  const LineChart({super.key, required this.series, this.unit = ''});
  final List<ChartSeries> series;
  final String unit;

  @override
  State<LineChart> createState() => _LineChartState();
}

class _LineChartState extends State<LineChart> {
  int? _hoverIdx;
  Size? _paintSize;

  int get _maxLen =>
      widget.series.fold(0, (m, s) => max(m, s.points.length));

  void _onTap(Offset local) {
    final size = _paintSize;
    if (size == null) return;
    const leftPad = 48.0;
    const rightPad = 16.0;
    final plotW = size.width - leftPad - rightPad;
    final n = _maxLen;
    if (n == 0) return;
    final relX = local.dx - leftPad;
    final step = n > 1 ? plotW / (n - 1) : plotW;
    final idx = (relX / step).round().clamp(0, n - 1);
    setState(() => _hoverIdx = idx);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textColor = cs.onSurfaceVariant;
    final gridColor = cs.outlineVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTapDown: (d) => _onTap(d.localPosition),
          onPanUpdate: (d) => _onTap(d.localPosition),
          onPanEnd: (_) => setState(() => _hoverIdx = null),
          onTapUp: (_) => Future.delayed(
            const Duration(seconds: 2),
            () { if (mounted) setState(() => _hoverIdx = null); },
          ),
          child: AspectRatio(
            aspectRatio: 2.6,
            child: LayoutBuilder(
              builder: (_, constraints) {
                _paintSize = constraints.biggest;
                return CustomPaint(
                  painter: _ChartPainter(
                    series: widget.series,
                    hoverIdx: _hoverIdx,
                    textColor: textColor,
                    gridColor: gridColor,
                  ),
                );
              },
            ),
          ),
        ),
        if (_hoverIdx != null) _TooltipRow(
          hoverIdx: _hoverIdx!,
          series: widget.series,
          unit: widget.unit,
        ),
        if (widget.series.length > 1) ...[
          const SizedBox(height: 6),
          _Legend(series: widget.series),
        ],
      ],
    );
  }
}

// ─── CustomPainter ───────────────────────────────────────────────────────────

class _ChartPainter extends CustomPainter {
  const _ChartPainter({
    required this.series,
    required this.hoverIdx,
    required this.textColor,
    required this.gridColor,
  });

  final List<ChartSeries> series;
  final int? hoverIdx;
  final Color textColor;
  final Color gridColor;

  static const _leftPad = 48.0;
  static const _rightPad = 16.0;
  static const _topPad = 14.0;
  static const _bottomPad = 36.0;

  @override
  void paint(Canvas canvas, Size size) {
    final allValues =
        series.expand((s) => s.points.map((p) => p.value)).toList();
    if (allValues.isEmpty) return;

    final plotLeft = _leftPad;
    final plotRight = size.width - _rightPad;
    final plotTop = _topPad;
    final plotBottom = size.height - _bottomPad;
    final plotW = plotRight - plotLeft;
    final plotH = plotBottom - plotTop;

    var minV = allValues.reduce(min);
    var maxV = allValues.reduce(max);
    if (minV == maxV) {
      final d = max(1.0, minV.abs() * 0.1);
      minV -= d;
      maxV += d;
    } else {
      final span = maxV - minV;
      minV -= span * 0.1;
      maxV += span * 0.1;
    }

    double xPx(int i, int total) {
      if (total <= 1) return plotLeft + plotW / 2;
      return plotLeft + (i / (total - 1)) * plotW;
    }

    double yPx(double v) {
      if (maxV == minV) return plotTop + plotH / 2;
      return plotTop + plotH - ((v - minV) / (maxV - minV)) * plotH;
    }

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;

    final labelStyle = TextStyle(
      color: textColor,
      fontSize: 9,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    // Y gridlines + labels
    for (var i = 0; i <= 4; i++) {
      final v = minV + (maxV - minV) / 4 * i;
      final y = yPx(v);
      canvas.drawLine(Offset(plotLeft, y), Offset(plotRight, y), gridPaint);
      final tp = TextPainter(
        text: TextSpan(text: _fmtVal(v), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(plotLeft - 4 - tp.width, y - tp.height / 2));
    }

    // Lines
    for (final s in series) {
      if (s.points.length < 2) continue;
      final n = s.points.length;
      final path = Path();
      for (var i = 0; i < n; i++) {
        final p = Offset(xPx(i, n), yPx(s.points[i].value));
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = s.color
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Dots
    for (final s in series) {
      final n = s.points.length;
      for (var i = 0; i < n; i++) {
        final p = Offset(xPx(i, n), yPx(s.points[i].value));
        canvas.drawCircle(
          p,
          hoverIdx == i ? 5.0 : 3.0,
          Paint()..color = s.color,
        );
      }
    }

    // X axis labels
    final maxLen = series.fold<int>(0, (m, s) => max(m, s.points.length));
    final primary = series.firstOrNull;
    if (primary != null && maxLen > 0) {
      final n = min(5, maxLen);
      for (var i = 0; i < n; i++) {
        final idx = n <= 1 ? 0 : (i / (n - 1) * (maxLen - 1)).round();
        if (idx >= primary.points.length) continue;
        final label = _shortDate(primary.points[idx].date);
        final x = xPx(idx, maxLen);
        final tp = TextPainter(
          text: TextSpan(text: label, style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
            canvas, Offset(x - tp.width / 2, size.height - _bottomPad + 6));
      }
    }

    // Cursor
    if (hoverIdx != null && maxLen > 0) {
      canvas.drawLine(
        Offset(xPx(hoverIdx!, maxLen), plotTop),
        Offset(xPx(hoverIdx!, maxLen), plotBottom),
        Paint()
          ..color = Colors.white24
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.hoverIdx != hoverIdx ||
      old.series != series ||
      old.textColor != textColor;
}

// ─── Tooltip ─────────────────────────────────────────────────────────────────

class _TooltipRow extends StatelessWidget {
  const _TooltipRow({
    required this.hoverIdx,
    required this.series,
    required this.unit,
  });
  final int hoverIdx;
  final List<ChartSeries> series;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Find date from first series with this index
    String date = '';
    for (final s in series) {
      if (hoverIdx < s.points.length) {
        date = _shortDate(s.points[hoverIdx].date);
        break;
      }
    }

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            date,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(width: 12),
          ...series.expand((s) {
            if (hoverIdx >= s.points.length) return <Widget>[];
            final v = s.points[hoverIdx].value;
            return [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 4),
                decoration:
                    BoxDecoration(color: s.color, shape: BoxShape.circle),
              ),
              Text(
                '${_fmtVal(v)} $unit',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 10),
            ];
          }),
        ],
      ),
    );
  }
}

// ─── Legend ──────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  const _Legend({required this.series});
  final List<ChartSeries> series;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: series.expand((s) => [
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 4),
              decoration:
                  BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(2)),
            ),
            Text(
              s.label,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(width: 16),
          ]).toList(),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

String _fmtVal(double v) {
  if (!v.isFinite) return '—';
  if (v.abs() >= 100) return v.toStringAsFixed(0);
  if (v.abs() >= 10) return v.toStringAsFixed(1);
  return v.toStringAsFixed(2);
}

String _shortDate(String iso) {
  final parts = iso.split('-');
  if (parts.length < 3) return iso;
  return '${parts[2]}/${parts[1]}';
}
