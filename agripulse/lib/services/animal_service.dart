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
    final animalTypeName = animal.animalType?.trim();
    if (animalTypeName == null || animalTypeName.isEmpty) {
      throw Exception('Breed / Type is required.');
    }
    final animalTypeTermId = await _resolveAnimalTypeTermId(animalTypeName);
    final data = await _client.createResource(
      _resourceType,
      animal.toCreatePayload(animalTypeTermId: animalTypeTermId),
    );
    return AnimalAsset.fromJsonApi(data);
  }

  Future<AnimalAsset> updateAnimal(AnimalAsset animal) async {
    final animalTypeName = animal.animalType?.trim();
    String? animalTypeTermId;
    if (animalTypeName != null && animalTypeName.isNotEmpty) {
      animalTypeTermId = await _resolveAnimalTypeTermId(animalTypeName);
    }
    final data = await _client.updateResource(
      _resourceType,
      animal.id,
      animal.toUpdatePayload(animalTypeTermId: animalTypeTermId),
    );
    return AnimalAsset.fromJsonApi(data);
  }

  Future<void> deleteAnimal(String id) async {
    await _client.deleteResource(_resourceType, id);
  }

  Future<String> _resolveAnimalTypeTermId(String name) async {
    final terms = await _client.getCollection(
      'taxonomy_term/animal_type',
      queryParameters: {
        'filter[name][operator]': 'CONTAINS',
        'filter[name][value]': name,
        'page[limit]': '50',
      },
    );

    if (terms.isEmpty) {
      throw Exception(
        'Unknown Breed / Type "$name". Create it in farmOS taxonomy first.',
      );
    }

    final exactMatch = terms.firstWhere(
      (term) {
        final termName =
            (term['attributes'] as Map<String, dynamic>?)?['name']?.toString();
        return termName != null &&
            termName.trim().toLowerCase() == name.trim().toLowerCase();
      },
      orElse: () => terms.first,
    );

    final id = exactMatch['id']?.toString();
    if (id == null || id.isEmpty) {
      throw Exception('Unable to resolve Breed / Type "$name".');
    }
    return id;
  }
}
