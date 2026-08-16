// mini_charts.dart
//
// Small self-contained charts for the Overview screen: a two-line trend
// chart (income vs expense) and a category donut. Built with
// CustomPainter instead of a charting package so there's no new pubspec
// dependency to add — same approach the app already uses for
// WaveBackground.

import 'package:flutter/material.dart';

import 'app_background_controller.dart';
import 'glass.dart';

class TrendPoint {
  final String label;
  final double income;
  final double expense;
  const TrendPoint({required this.label, required this.income, required this.expense});
}

/// Two-line trend chart (income vs expense) over a series of months.
class IncomeExpenseTrendChart extends StatelessWidget {
  const IncomeExpenseTrendChart({super.key, required this.points, this.height = 200});

  final List<TrendPoint> points;
  final double height;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      borderRadius: BorderRadius.circular(18),
      child: AdaptiveBackgroundText(
        child: Builder(builder: (context) {
          final textColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Income vs Expenses', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  _LegendDot(color: Colors.green, label: 'Income'),
                  const SizedBox(width: 12),
                  _LegendDot(color: Colors.redAccent, label: 'Expenses'),
                ],
              ),
              const SizedBox(height: 12),
              if (points.every((p) => p.income == 0 && p.expense == 0))
                SizedBox(
                  height: height,
                  child: Center(child: Text('No data yet', style: TextStyle(color: textColor.withOpacity(0.6)))),
                )
              else
                SizedBox(
                  height: height,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _TrendPainter(points: points, labelColor: textColor),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<TrendPoint> points;
  final Color labelColor;

  _TrendPainter({required this.points, required this.labelColor});

  @override
  void paint(Canvas canvas, Size size) {
    const leftAxisWidth = 6.0;
    const bottomLabelHeight = 20.0;
    final chartWidth = size.width - leftAxisWidth;
    final chartHeight = size.height - bottomLabelHeight;

    final maxVal = points
        .expand((p) => [p.income, p.expense])
        .fold<double>(0, (m, v) => v > m ? v : m);
    final ceiling = maxVal <= 0 ? 1.0 : maxVal * 1.15;

    // Gridlines
    final gridPaint = Paint()
      ..color = labelColor.withOpacity(0.08)
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final y = chartHeight * i / 3;
      canvas.drawLine(Offset(leftAxisWidth, y), Offset(size.width, y), gridPaint);
    }

    Offset pointAt(int i, double value) {
      final dx = points.length <= 1 ? leftAxisWidth : leftAxisWidth + chartWidth * i / (points.length - 1);
      final dy = chartHeight - (value / ceiling) * chartHeight;
      return Offset(dx, dy);
    }

    void drawSeries(double Function(TrendPoint) getVal, Color color) {
      final linePath = Path();
      final fillPath = Path();
      for (int i = 0; i < points.length; i++) {
        final p = pointAt(i, getVal(points[i]));
        if (i == 0) {
          linePath.moveTo(p.dx, p.dy);
          fillPath.moveTo(p.dx, chartHeight);
          fillPath.lineTo(p.dx, p.dy);
        } else {
          linePath.lineTo(p.dx, p.dy);
          fillPath.lineTo(p.dx, p.dy);
        }
      }
      if (points.isNotEmpty) {
        fillPath.lineTo(pointAt(points.length - 1, getVal(points.last)).dx, chartHeight);
        fillPath.close();
      }
      canvas.drawPath(fillPath, Paint()..color = color.withOpacity(0.08));
      canvas.drawPath(
        linePath,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      for (int i = 0; i < points.length; i++) {
        final p = pointAt(i, getVal(points[i]));
        canvas.drawCircle(p, 3, Paint()..color = color);
        canvas.drawCircle(p, 3, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.2);
      }
    }

    drawSeries((p) => p.expense, Colors.redAccent);
    drawSeries((p) => p.income, Colors.green);

    // Month labels
    for (int i = 0; i < points.length; i++) {
      final p = pointAt(i, 0);
      final tp = TextPainter(
        text: TextSpan(text: points[i].label, style: TextStyle(color: labelColor.withOpacity(0.6), fontSize: 10.5)),
        textDirection: TextDirection.ltr,
      )..layout();
      // Skip labels that would overlap on a dense series.
      if (points.length <= 8 || i % ((points.length / 8).ceil()) == 0) {
        tp.paint(canvas, Offset(p.dx - tp.width / 2, chartHeight + 4));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.labelColor != labelColor;
}

class CategorySlice {
  final String label;
  final double value;
  final Color color;
  const CategorySlice({required this.label, required this.value, required this.color});
}

/// Donut chart for expense-category breakdown, with a legend list.
class CategoryDonutChart extends StatelessWidget {
  const CategoryDonutChart({super.key, required this.slices, this.size = 150});

  final List<CategorySlice> slices;
  final double size;

  static const List<Color> palette = [
    Colors.blue,
    Colors.deepOrange,
    Colors.purple,
    Colors.teal,
    Colors.brown,
    Colors.indigo,
    Colors.pink,
    Colors.amber,
  ];

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (sum, s) => sum + s.value);

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(18),
      child: AdaptiveBackgroundText(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Expenses by Category', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (total <= 0)
              SizedBox(height: size, child: const Center(child: Text('No expenses yet')))
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: size,
                    height: size,
                    child: CustomPaint(painter: _DonutPainter(slices: slices, total: total)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: slices.take(6).map((s) {
                        final pct = total == 0 ? 0 : (s.value / total * 100);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Container(width: 9, height: 9, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Expanded(child: Text(s.label, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall)),
                              Text('${pct.toStringAsFixed(0)}%', style: Theme.of(context).textTheme.labelSmall),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<CategorySlice> slices;
  final double total;

  _DonutPainter({required this.slices, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 18.0;
    double startAngle = -1.5708; // -90deg

    for (final slice in slices) {
      final sweep = (slice.value / total) * 6.28319;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweep - 0.03,
        false,
        Paint()
          ..color = slice.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => oldDelegate.slices != slices;
}
