import '../models/water_level_log.dart';
import 'farmos_client.dart';

class WaterLevelService {
  final FarmosClient _client;

  WaterLevelService(this._client);

  /// Fetches the list of configured sensors from the farmOS module.
  Future<List<SensorInfo>> getSensors() async {
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
    final parsed = await _fetchAll(results: pageSize, sensorId: sensorId);
    parsed.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return parsed;
  }

  /// Fetches readings since a given time, optionally filtered by sensor.
  Future<List<WaterLevelLog>> getReadingsSince(
    DateTime since, {
    String? sensorId,
  }) async {
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
        if (sensorId != null) 'sensor_id': sensorId,
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
}
