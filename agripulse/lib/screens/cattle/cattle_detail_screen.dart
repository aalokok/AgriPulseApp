import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/animal_provider.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/status_badge.dart';

class CattleDetailScreen extends ConsumerWidget {
  final String id;

  const CattleDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final animalAsync = ref.watch(animalDetailProvider(id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Animal Details'),
        actions: [
          animalAsync.whenOrNull(
                data: (_) => IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => context.go('/cattle/$id/edit'),
                ),
              ) ??
              const SizedBox.shrink(),
          animalAsync.whenOrNull(
                data: (_) => IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: theme.colorScheme.error),
                  onPressed: () => _confirmDelete(context, ref),
                ),
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: animalAsync.when(
        loading: () => const LoadingIndicator(message: 'Loading animal...'),
        error: (error, _) => ErrorDisplay(
          message: error.toString(),
          onRetry: () => ref.invalidate(animalDetailProvider(id)),
        ),
        data: (animal) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(
                      Icons.pets,
                      size: 40,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    animal.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  StatusBadge(label: animal.status),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Details card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _DetailRow(
                      icon: Icons.category_outlined,
                      label: 'Breed / Type',
                      value: animal.animalType ?? '—',
                    ),
                    const Divider(height: 24),
                    _DetailRow(
                      icon: Icons.label_outline,
                      label: 'Tag ID',
                      value: animal.primaryTagId,
                    ),
                    if (animal.idTags.isNotEmpty &&
                        animal.idTags.first.type != null) ...[
                      const Divider(height: 24),
                      _DetailRow(
                        icon: Icons.style_outlined,
                        label: 'Tag Type',
                        value: animal.idTags.first.type!,
                      ),
                    ],
                    if (animal.sex != null) ...[
                      const Divider(height: 24),
                      _DetailRow(
                        icon: Icons.wc_outlined,
                        label: 'Sex',
                        value: animal.sex!,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Notes
            if (animal.notes != null && animal.notes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.notes_outlined,
                              size: 20,
                              color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Text(
                            'Notes',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        animal.notes!,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Animal'),
        content: const Text(
            'Are you sure you want to delete this animal? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(animalListProvider.notifier).deleteAnimal(id);
              if (context.mounted) context.go('/cattle');
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
