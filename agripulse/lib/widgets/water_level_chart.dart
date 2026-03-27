import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/water_level_log.dart';

class WaterLevelChart extends StatelessWidget {
  final List<WaterLevelLog> readings;
  final double? threshold;

  const WaterLevelChart({
    super.key,
    required this.readings,
    this.threshold,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (readings.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'No chart data available',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final sorted = List<WaterLevelLog>.from(readings)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final spots = <FlSpot>[];
    for (int i = 0; i < sorted.length; i++) {
      if (sorted[i].value != null) {
        spots.add(FlSpot(i.toDouble(), sorted[i].value!));
      }
    }

    if (spots.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text('No valid readings to chart',
              style: theme.textTheme.bodyMedium),
        ),
      );
    }

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.15;

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: _niceInterval(maxY - minY),
            getDrawingHorizontalLine: (value) => FlLine(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (value, meta) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    value.toStringAsFixed(0),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: (spots.length / 5).ceilToDouble().clamp(1, 100),
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= sorted.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat('HH:mm').format(sorted[idx].timestamp.toLocal()),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minY: (minY - padding).clamp(0, double.infinity),
          maxY: maxY + padding,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              preventCurveOverShooting: true,
              color: Colors.blue.shade600,
              barWidth: 2.5,
              dotData: FlDotData(
                show: spots.length <= 30,
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                  radius: 3,
                  color: Colors.blue.shade600,
                  strokeWidth: 0,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blue.shade100.withValues(alpha: 0.4),
              ),
            ),
          ],
          extraLinesData: threshold != null
              ? ExtraLinesData(horizontalLines: [
                  HorizontalLine(
                    y: threshold!,
                    color: Colors.red.shade400,
                    strokeWidth: 1.5,
                    dashArray: [6, 4],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      style: TextStyle(
                        color: Colors.red.shade400,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      labelResolver: (_) =>
                          'Threshold: ${threshold!.toStringAsFixed(0)} cm',
                    ),
                  ),
                ])
              : null,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((spot) {
                final idx = spot.spotIndex;
                final reading = sorted[idx];
                return LineTooltipItem(
                  '${reading.value?.toStringAsFixed(1)} cm\n',
                  TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  children: [
                    TextSpan(
                      text: DateFormat('MMM d, HH:mm')
                          .format(reading.timestamp.toLocal()),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.normal,
                        fontSize: 11,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  double _niceInterval(double range) {
    if (range <= 0) return 10;
    final rough = range / 5;
    final magnitude = _pow10(rough);
    final fraction = rough / magnitude;
    if (fraction <= 1.5) return magnitude;
    if (fraction <= 3) return 2 * magnitude;
    if (fraction <= 7) return 5 * magnitude;
    return 10 * magnitude;
  }

  double _pow10(double value) {
    if (value <= 0) return 1;
    var p = 1.0;
    while (p * 10 <= value) {
      p *= 10;
    }
    while (p > value) {
      p /= 10;
    }
    return p;
  }
}
