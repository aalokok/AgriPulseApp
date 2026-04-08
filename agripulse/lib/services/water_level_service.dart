import '../models/water_level_log.dart';
import 'farmos_client.dart';

class WaterLevelService {
  static const _resourceType = 'log/water_level';

  final FarmosClient _client;

  WaterLevelService(this._client);

  Future<WaterLevelLog?> getLatestReading() async {
    final data = await _client.getCollection(
      _resourceType,
      queryParameters: {
        'sort': '-timestamp',
        'page[limit]': '1',
        'include': 'quantity',
      },
    );
    if (data.isEmpty) return null;
    return WaterLevelLog.fromJsonApi(data.first);
  }

  Future<List<WaterLevelLog>> getReadings({
    int page = 0,
    int pageSize = 50,
  }) async {
    final data = await _client.getCollection(
      _resourceType,
      queryParameters: {
        'sort': '-timestamp',
        'page[limit]': pageSize.toString(),
        'page[offset]': (page * pageSize).toString(),
        'include': 'quantity',
      },
    );
    return data.map((d) => WaterLevelLog.fromJsonApi(d)).toList();
  }

  /// Returns readings within the given time window.
  Future<List<WaterLevelLog>> getReadingsSince(DateTime since) async {
    final data = await _client.getCollection(
      _resourceType,
      queryParameters: {
        'sort': 'timestamp',
        'filter[timestamp][operator]': '>=',
        'filter[timestamp][value]': (since.millisecondsSinceEpoch ~/ 1000).toString(),
        'include': 'quantity',
      },
    );
    return data.map((d) => WaterLevelLog.fromJsonApi(d)).toList();
  }
}
