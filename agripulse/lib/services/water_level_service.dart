import '../models/water_level_log.dart';
import 'farmos_client.dart';

class WaterLevelService {
  final FarmosClient _client;
  final bool _demoMode;
  static const List<SensorInfo> _demoSensors = [
    SensorInfo(id: 's-pond-1', name: 'North Pond', fieldNumber: 1),
    SensorInfo(id: 's-trough-2', name: 'Main Trough', fieldNumber: 2),
  ];
  static final List<WaterLevelLog> _demoReadings = _buildDemoReadings();

  WaterLevelService(this._client, {bool demoMode = false})
      : _demoMode = demoMode;

  /// Fetches the list of configured sensors from the farmOS module.
  Future<List<SensorInfo>> getSensors() async {
    if (_demoMode) return _demoSensors;

    final data = await _client.getCustom(
      '/farm/water-level/api/readings',
      queryParameters: {'results': '1'},
    );
    final sensors = (data['sensors'] as List?) ?? [];
    return sensors.map((s) {
      final m = s as Map<String, dynamic>;
      return SensorInfo(
        id: m['sensor_id'] as String? ?? '',
        name: m['name'] as String? ?? '',
        fieldNumber: m['field_number'] as int? ?? 1,
      );
    }).toList();
  }

  /// Fetches the latest reading across all sensors, or for a specific one.
  Future<WaterLevelLog?> getLatestReading({String? sensorId}) async {
    if (_demoMode) {
      final filtered = _filterDemoReadings(sensorId: sensorId);
      if (filtered.isEmpty) return null;
      filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return filtered.first;
    }

    final parsed = await _fetchAll(results: 1, sensorId: sensorId);
    if (parsed.isEmpty) return null;
    parsed.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return parsed.first;
  }

  /// Fetches recent readings, optionally filtered by sensor.
  Future<List<WaterLevelLog>> getReadings({
    int pageSize = 50,
    String? sensorId,
  }) async {
    if (_demoMode) {
      final filtered = _filterDemoReadings(sensorId: sensorId);
      filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return filtered.take(pageSize).toList();
    }

    final parsed = await _fetchAll(results: pageSize, sensorId: sensorId);
    parsed.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return parsed;
  }

  /// Fetches readings since a given time, optionally filtered by sensor.
  Future<List<WaterLevelLog>> getReadingsSince(
    DateTime since, {
    String? sensorId,
  }) async {
    if (_demoMode) {
      final filtered = _filterDemoReadings(sensorId: sensorId)
          .where((r) => r.timestamp.isAfter(since))
          .toList();
      filtered.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return filtered;
    }

    final parsed = await _fetchAll(results: 500, sensorId: sensorId);
    final filtered = parsed.where((r) => r.timestamp.isAfter(since)).toList();
    filtered.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return filtered;
  }

  Future<List<WaterLevelLog>> _fetchAll({
    int? results,
    String? sensorId,
  }) async {
    final data = await _client.getCustom(
      '/farm/water-level/api/readings',
      queryParameters: {
        if (results != null) 'results': results.toString(),
        ...?sensorId == null ? null : {'sensor_id': sensorId},
      },
    );

    final sensors = (data['sensors'] as List?) ?? [];
    final allReadings = <WaterLevelLog>[];

    for (final s in sensors) {
      final sensorMap = s as Map<String, dynamic>;
      final sid = sensorMap['sensor_id'] as String? ?? '';
      final sensorName = sensorMap['name'] as String? ?? '';
      final readings = (sensorMap['readings'] as List?) ?? [];

      for (final r in readings) {
        final rMap = r as Map<String, dynamic>;
        allReadings.add(WaterLevelLog(
          id: '${sid}_${rMap['entry_id']}',
          name: '$sensorName reading',
          timestamp:
              DateTime.tryParse(rMap['timestamp'] as String? ?? '')?.toUtc() ??
                  DateTime.now().toUtc(),
          status: 'done',
          value: (rMap['value'] as num?)?.toDouble(),
          units: rMap['units'] as String? ?? 'cm',
          sensorId: sid,
          sensorName: sensorName,
        ));
      }
    }

    return allReadings;
  }

  List<WaterLevelLog> _filterDemoReadings({String? sensorId}) {
    if (sensorId == null) return List<WaterLevelLog>.from(_demoReadings);
    return _demoReadings.where((r) => r.sensorId == sensorId).toList();
  }

  static List<WaterLevelLog> _buildDemoReadings() {
    final now = DateTime.now().toUtc();
    final readings = <WaterLevelLog>[];

    for (var i = 0; i < 72; i++) {
      final timestamp = now.subtract(Duration(hours: i));
      final northValue = 80.0 - (i * 0.18) + ((i % 4) * 0.35);
      final troughValue = 65.0 - (i * 0.12) + ((i % 5) * 0.28);

      readings.add(
        WaterLevelLog(
          id: 'north-$i',
          name: 'North Pond reading',
          timestamp: timestamp,
          value: northValue,
          units: 'cm',
          sensorId: 's-pond-1',
          sensorName: 'North Pond',
        ),
      );
      readings.add(
        WaterLevelLog(
          id: 'trough-$i',
          name: 'Main Trough reading',
          timestamp: timestamp,
          value: troughValue,
          units: 'cm',
          sensorId: 's-trough-2',
          sensorName: 'Main Trough',
        ),
      );
    }

    return readings;
  }
}
