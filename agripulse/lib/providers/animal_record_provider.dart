import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/animal_record.dart';
import 'auth_provider.dart';

final animalRecordsProvider =
    FutureProvider.family<List<AnimalRecord>, String>((ref, animalId) async {
  return ref
      .read(animalRecordServiceProvider)
      .getRecordsForAnimal(animalId, limitPerType: 3);
});
