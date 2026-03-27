import '../models/animal_asset.dart';
import 'farmos_client.dart';

class AnimalService {
  static const _resourceType = 'asset/animal';

  final FarmosClient _client;

  AnimalService(this._client);

  Future<List<AnimalAsset>> getAnimals({
    int page = 0,
    int pageSize = 25,
    String? searchQuery,
  }) async {
    final params = <String, String>{
      'page[limit]': pageSize.toString(),
      'page[offset]': (page * pageSize).toString(),
      'sort': '-created',
    };

    if (searchQuery != null && searchQuery.isNotEmpty) {
      params['filter[name][operator]'] = 'CONTAINS';
      params['filter[name][value]'] = searchQuery;
    }

    final data = await _client.getCollection(
      _resourceType,
      queryParameters: params,
    );
    return data.map((d) => AnimalAsset.fromJsonApi(d)).toList();
  }

  Future<AnimalAsset> getAnimal(String id) async {
    final data = await _client.getResource(_resourceType, id);
    return AnimalAsset.fromJsonApi(data);
  }

  Future<AnimalAsset> createAnimal(AnimalAsset animal) async {
    final data = await _client.createResource(
      _resourceType,
      animal.toCreatePayload(),
    );
    return AnimalAsset.fromJsonApi(data);
  }

  Future<AnimalAsset> updateAnimal(AnimalAsset animal) async {
    final data = await _client.updateResource(
      _resourceType,
      animal.id,
      animal.toUpdatePayload(),
    );
    return AnimalAsset.fromJsonApi(data);
  }

  Future<void> deleteAnimal(String id) async {
    await _client.deleteResource(_resourceType, id);
  }
}
