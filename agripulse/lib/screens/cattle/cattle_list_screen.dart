import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/animal_provider.dart';
import '../../widgets/animal_card.dart';
import '../../widgets/loading_indicator.dart';

class CattleListScreen extends ConsumerStatefulWidget {
  const CattleListScreen({super.key});

  @override
  ConsumerState<CattleListScreen> createState() => _CattleListScreenState();
}

class _CattleListScreenState extends ConsumerState<CattleListScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(animalListProvider.notifier).loadAnimals(refresh: true),
    );
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final state = ref.read(animalListProvider);
      if (!state.isLoading && state.hasMore) {
        ref.read(animalListProvider.notifier).loadAnimals();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(animalListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cattle')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/cattle/new'),
        icon: const Icon(Icons.add),
        label: const Text('Add Animal'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search animals...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(animalListProvider.notifier).search('');
                        },
                      )
                    : null,
              ),
              onChanged: (query) {
                setState(() {});
                ref.read(animalListProvider.notifier).search(query);
              },
            ),
          ),

          // List
          Expanded(
            child: state.isLoading && state.animals.isEmpty
                ? const LoadingIndicator(message: 'Loading cattle...')
                : state.error != null && state.animals.isEmpty
                    ? ErrorDisplay(
                        message: state.error!,
                        onRetry: () => ref
                            .read(animalListProvider.notifier)
                            .loadAnimals(refresh: true),
                      )
                    : state.animals.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.pets,
                                    size: 64,
                                    color:
                                        theme.colorScheme.onSurfaceVariant),
                                const SizedBox(height: 16),
                                Text(
                                  state.searchQuery.isNotEmpty
                                      ? 'No animals match your search'
                                      : 'No animals registered yet',
                                  style:
                                      theme.textTheme.bodyLarge?.copyWith(
                                    color: theme
                                        .colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                if (state.searchQuery.isEmpty) ...[
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () =>
                                        context.go('/cattle/new'),
                                    child:
                                        const Text('Add your first animal'),
                                  ),
                                ],
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () async => ref
                                .read(animalListProvider.notifier)
                                .loadAnimals(refresh: true),
                            child: ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(
                                  16, 0, 16, 88),
                              itemCount: state.animals.length +
                                  (state.isLoading ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index >= state.animals.length) {
                                  return const Padding(
                                    padding:
                                        EdgeInsets.symmetric(vertical: 16),
                                    child: Center(
                                        child:
                                            CircularProgressIndicator()),
                                  );
                                }
                                final animal = state.animals[index];
                                return Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 8),
                                  child: AnimalCard(
                                    animal: animal,
                                    onTap: () => context
                                        .go('/cattle/${animal.id}'),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
