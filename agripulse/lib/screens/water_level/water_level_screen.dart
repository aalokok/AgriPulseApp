import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/water_level_log.dart';
import '../../providers/settings_provider.dart';
import '../../providers/water_level_provider.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/water_level_card.dart';
import '../../widgets/water_level_chart.dart';

class WaterLevelScreen extends ConsumerStatefulWidget {
  const WaterLevelScreen({super.key});

  @override
  ConsumerState<WaterLevelScreen> createState() => _WaterLevelScreenState();
}

class _WaterLevelScreenState extends ConsumerState<WaterLevelScreen> {
  int _chartDays = 1;
  List<WaterLevelLog>? _chartData;
  bool _loadingChart = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(waterLevelProvider.notifier).loadData();
      _loadChartData();
    });
  }

  Future<void> _loadChartData() async {
    setState(() => _loadingChart = true);
    try {
      final data = await ref
          .read(waterLevelProvider.notifier)
          .getChartData(days: _chartDays);
      if (mounted) setState(() => _chartData = data);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingChart = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(waterLevelProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Water Level')),
      body: state.isLoading && state.recentReadings.isEmpty
          ? const LoadingIndicator(message: 'Loading water level data...')
          : state.error != null && state.recentReadings.isEmpty
              ? ErrorDisplay(
                  message: state.error!,
                  onRetry: () =>
                      ref.read(waterLevelProvider.notifier).loadData(),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(waterLevelProvider.notifier).refresh();
                    await _loadChartData();
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Sensor filter
                      if (state.sensors.length > 1) ...[
                        _SensorFilter(
                          sensors: state.sensors,
                          selectedId: state.selectedSensorId,
                          onChanged: (id) {
                            ref
                                .read(waterLevelProvider.notifier)
                                .selectSensor(id);
                            _loadChartData();
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Current reading
                      WaterLevelCard(
                        reading: state.latestReading,
                        threshold: settings.waterLevelThreshold,
                      ),
                      const SizedBox(height: 24),

                      // Chart section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Trend',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SegmentedButton<int>(
                            segments: const [
                              ButtonSegment(value: 1, label: Text('24h')),
                              ButtonSegment(value: 7, label: Text('7d')),
                              ButtonSegment(value: 30, label: Text('30d')),
                            ],
                            selected: {_chartDays},
                            onSelectionChanged: (selection) {
                              setState(() => _chartDays = selection.first);
                              _loadChartData();
                            },
                            style: ButtonStyle(
                              visualDensity: VisualDensity.compact,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_loadingChart)
                        const SizedBox(
                          height: 220,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else
                        WaterLevelChart(
                          readings: _chartData ?? state.recentReadings,
                          threshold: settings.waterLevelThreshold,
                        ),
                      const SizedBox(height: 24),

                      // Recent readings table
                      Text(
                        'Recent Readings',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (state.recentReadings.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'No readings recorded yet',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        )
                      else
                        Card(
                          clipBehavior: Clip.antiAlias,
                          child: DataTable(
                            columnSpacing: 24,
                            headingRowColor: WidgetStatePropertyAll(
                              theme.colorScheme.surfaceContainerHighest,
                            ),
                            columns: [
                              const DataColumn(label: Text('Time')),
                              const DataColumn(
                                  label: Text('Level'), numeric: true),
                              if (state.selectedSensorId == null)
                                const DataColumn(label: Text('Sensor')),
                              const DataColumn(label: Text('Status')),
                            ],
                            rows: state.recentReadings.take(20).map((log) {
                              final isLow = log.value != null &&
                                  log.value! <
                                      settings.waterLevelThreshold;
                              return DataRow(
                                cells: [
                                  DataCell(Text(
                                    DateFormat('MMM d, HH:mm')
                                        .format(log.timestamp.toLocal()),
                                    style: theme.textTheme.bodySmall,
                                  )),
                                  DataCell(Text(
                                    log.value != null
                                        ? '${log.value!.toStringAsFixed(1)} ${log.units}'
                                        : '\u2014',
                                    style:
                                        theme.textTheme.bodySmall?.copyWith(
                                      color: isLow
                                          ? Colors.red.shade700
                                          : null,
                                      fontWeight: isLow
                                          ? FontWeight.w600
                                          : null,
                                    ),
                                  )),
                                  if (state.selectedSensorId == null)
                                    DataCell(Text(
                                      log.sensorName,
                                      style: theme.textTheme.bodySmall,
                                    )),
                                  DataCell(Text(
                                    log.status,
                                    style: theme.textTheme.bodySmall,
                                  )),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _SensorFilter extends StatelessWidget {
  final List<SensorInfo> sensors;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  const _SensorFilter({
    required this.sensors,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Sensor',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedId ?? '_all',
          isExpanded: true,
          isDense: true,
          style: theme.textTheme.bodyLarge,
          items: [
            const DropdownMenuItem(
              value: '_all',
              child: Text('All sensors'),
            ),
            ...sensors.map((s) => DropdownMenuItem(
                  value: s.id,
                  child: Text('${s.name} (field ${s.fieldNumber})'),
                )),
          ],
          onChanged: (value) {
            onChanged(value == '_all' ? null : value);
          },
        ),
      ),
    );
  }
}
