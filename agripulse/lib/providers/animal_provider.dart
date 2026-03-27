import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/animal_asset.dart';
import 'auth_provider.dart';

// ── Animal list ─────────────────────────────────────────────────────────

class AnimalListState {
  final List<AnimalAsset> animals;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final String searchQuery;
  final int currentPage;

  const AnimalListState({
    this.animals = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.searchQuery = '',
    this.currentPage = 0,
  });

  AnimalListState copyWith({
    List<AnimalAsset>? animals,
    bool? isLoading,
    bool? hasMore,
    String? error,
    String? searchQuery,
    int? currentPage,
  }) {
    return AnimalListState(
      animals: animals ?? this.animals,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

class AnimalListNotifier extends Notifier<AnimalListState> {
  @override
  AnimalListState build() => const AnimalListState();

  Future<void> loadAnimals({bool refresh = false}) async {
    if (state.isLoading) return;

    final page = refresh ? 0 : state.currentPage;
    state = state.copyWith(
      isLoading: true,
      error: null,
      currentPage: page,
      animals: refresh ? [] : state.animals,
    );

    try {
      final service = ref.read(animalServiceProvider);
      final animals = await service.getAnimals(
        page: page,
        searchQuery: state.searchQuery.isEmpty ? null : state.searchQuery,
      );
      state = state.copyWith(
        isLoading: false,
        animals: refresh ? animals : [...state.animals, ...animals],
        hasMore: animals.length >= 25,
        currentPage: page + 1,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> search(String query) async {
    state = state.copyWith(searchQuery: query);
    await loadAnimals(refresh: true);
  }

  Future<void> deleteAnimal(String id) async {
    try {
      await ref.read(animalServiceProvider).deleteAnimal(id);
      state = state.copyWith(
        animals: state.animals.where((a) => a.id != id).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete: $e');
    }
  }
}

final animalListProvider =
    NotifierProvider<AnimalListNotifier, AnimalListState>(
        AnimalListNotifier.new);

// ── Single animal detail ────────────────────────────────────────────────

final animalDetailProvider =
    FutureProvider.family<AnimalAsset, String>((ref, id) async {
  return ref.read(animalServiceProvider).getAnimal(id);
});
