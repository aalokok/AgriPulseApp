import '../models/animal_asset.dart';
import 'farmos_client.dart';

class AnimalService {
  static const _resourceType = 'asset/animal';
  static final List<AnimalAsset> _demoAnimals = [
    const AnimalAsset(
      id: 'demo-1',
      name: 'Bella',
      status: 'active',
      animalType: 'Holstein',
      idTags: [IdTag(id: 'A-102')],
      notes: 'Top milk producer in the north field group.',
      sex: 'F',
    ),
    const AnimalAsset(
      id: 'demo-2',
      name: 'Duke',
      status: 'active',
      animalType: 'Angus',
      idTags: [IdTag(id: 'B-207')],
      notes: 'Calm temperament; vaccinated this season.',
      sex: 'M',
    ),
    const AnimalAsset(
      id: 'demo-3',
      name: 'Maple',
      status: 'active',
      animalType: 'Jersey',
      idTags: [IdTag(id: 'C-318')],
      notes: 'Recently moved to rotational grazing plot 3.',
      sex: 'F',
    ),
  ];

  final FarmosClient _client;
  final bool _demoMode;

  AnimalService(this._client, {bool demoMode = false}) : _demoMode = demoMode;

  Future<List<AnimalAsset>> getAnimals({
    int page = 0,
    int pageSize = 25,
    String? searchQuery,
  }) async {
    if (_demoMode) {
      final query = searchQuery?.trim().toLowerCase() ?? '';
      final filtered = _demoAnimals.where((animal) {
        if (query.isEmpty) return true;
        return animal.name.toLowerCase().contains(query) ||
            (animal.animalType?.toLowerCase().contains(query) ?? false) ||
            animal.primaryTagId.toLowerCase().contains(query);
      }).toList();

      final start = page * pageSize;
      if (start >= filtered.length) return [];
      final end = (start + pageSize).clamp(0, filtered.length);
      return filtered.sublist(start, end);
    }

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
    if (_demoMode) {
      return _demoAnimals.firstWhere(
        (animal) => animal.id == id,
        orElse: () => throw Exception('Demo animal not found: $id'),
      );
    }

    final data = await _client.getResource(_resourceType, id);
    return AnimalAsset.fromJsonApi(data);
  }

  Future<AnimalAsset> createAnimal(AnimalAsset animal) async {
    if (_demoMode) {
      final created = animal.copyWith(
        id: 'demo-${DateTime.now().microsecondsSinceEpoch}',
      );
      _demoAnimals.insert(0, created);
      return created;
    }

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
    if (_demoMode) {
      final index = _demoAnimals.indexWhere((a) => a.id == animal.id);
      if (index == -1) {
        throw Exception('Demo animal not found: ${animal.id}');
      }
      _demoAnimals[index] = animal;
      return animal;
    }

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
    if (_demoMode) {
      _demoAnimals.removeWhere((a) => a.id == id);
      return;
    }

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
