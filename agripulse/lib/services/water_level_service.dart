import '../models/water_level_log.dart';
import 'farmos_client.dart';

class WaterLevelService {
  final FarmosClient _client;

  WaterLevelService(this._client);

  Future<WaterLevelLog?> getLatestReading() async {
    final sensors = await _fetchSensorReadings(results: 1);
    if (sensors.isEmpty) return null;
    final allReadings = sensors.expand((s) => s.readings).toList();
    if (allReadings.isEmpty) return null;
    allReadings.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return allReadings.first;
  }

  Future<List<WaterLevelLog>> getReadings({
    int page = 0,
    int pageSize = 50,
  }) async {
    final sensors = await _fetchSensorReadings(results: pageSize);
    final allReadings = sensors.expand((s) => s.readings).toList();
    allReadings.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return allReadings;
  }

  Future<List<WaterLevelLog>> getReadingsSince(DateTime since) async {
    final sensors = await _fetchSensorReadings(results: 500);
    final allReadings = sensors
        .expand((s) => s.readings)
        .where((r) => r.timestamp.isAfter(since))
        .toList();
    allReadings.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return allReadings;
  }

  Future<List<_SensorData>> _fetchSensorReadings({int? results}) async {
    final data = await _client.getCustom(
      '/farm/water-level/api/readings',
      queryParameters: {
        if (results != null) 'results': results.toString(),
      },
    );

    final sensors = (data['sensors'] as List?) ?? [];
    return sensors.map((s) {
      final sensorMap = s as Map<String, dynamic>;
      final sensorName = sensorMap['name'] as String? ?? '';
      final readings = (sensorMap['readings'] as List?) ?? [];
      return _SensorData(
        name: sensorName,
        readings: readings.map((r) {
          final rMap = r as Map<String, dynamic>;
          return WaterLevelLog(
            id: '${sensorMap['sensor_id']}_${rMap['entry_id']}',
            name: '$sensorName reading',
            timestamp: DateTime.tryParse(rMap['timestamp'] as String? ?? '')?.toUtc()
                ?? DateTime.now().toUtc(),
            status: 'done',
            value: (rMap['value'] as num?)?.toDouble(),
            units: rMap['units'] as String? ?? 'cm',
          );
        }).toList(),
      );
    }).toList();
  }
}

class _SensorData {
  final String name;
  final List<WaterLevelLog> readings;
  const _SensorData({required this.name, required this.readings});
}
