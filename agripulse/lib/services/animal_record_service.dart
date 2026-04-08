import '../models/animal_record.dart';
import 'farmos_client.dart';

class AnimalRecordService {
  final FarmosClient _client;

  AnimalRecordService(this._client);

  Future<List<AnimalRecord>> getRecordsForAnimal(
    String animalId, {
    int limitPerType = 5,
  }) async {
    final all = <AnimalRecord>[];

    for (final type in AnimalRecordType.values) {
      try {
        final rows = await _client.getCollection(
          'log/${type.apiPath}',
          queryParameters: {
            'filter[asset.id]': animalId,
            'sort': '-timestamp',
            'page[limit]': '$limitPerType',
          },
        );
        all.addAll(rows.map((r) => AnimalRecord.fromJsonApi(r, type)));
      } catch (_) {
        // Some farmOS instances may not have all log bundles enabled.
      }
    }

    all.sort((a, b) {
      final aTs = a.timestamp?.millisecondsSinceEpoch ?? 0;
      final bTs = b.timestamp?.millisecondsSinceEpoch ?? 0;
      return bTs.compareTo(aTs);
    });
    return all;
  }

  Future<void> createRecord({
    required String animalId,
    required AnimalRecordType type,
    required String title,
    DateTime? timestamp,
    String? notes,
  }) async {
    final ts = timestamp ?? DateTime.now();
    final tsFormatted = _formatFarmOsTimestamp(ts);
    final attrs = <String, dynamic>{
      'name': title,
      'status': 'done',
      'timestamp': tsFormatted,
      if (notes != null && notes.trim().isNotEmpty)
        'notes': {'value': notes.trim(), 'format': 'default'},
    };

    await _client.createResource(
      'log/${type.apiPath}',
      {
        'data': {
          'type': 'log--${type.apiPath}',
          'attributes': attrs,
          'relationships': {
            'asset': {
              'data': [
                {'type': 'asset--animal', 'id': animalId}
              ],
            },
          },
        },
      },
    );
  }

  String _formatFarmOsTimestamp(DateTime dt) {
    final local = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-${two(local.day)}'
        'T${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }
}
