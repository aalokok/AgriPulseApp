import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/animal_asset.dart';
import '../../providers/animal_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/loading_indicator.dart';

class CattleFormScreen extends ConsumerStatefulWidget {
  final String? id;

  const CattleFormScreen({super.key, this.id});

  bool get isEditing => id != null;

  @override
  ConsumerState<CattleFormScreen> createState() => _CattleFormScreenState();
}

class _CattleFormScreenState extends ConsumerState<CattleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _tagIdController = TextEditingController();
  final _notesController = TextEditingController();
  String _status = 'active';
  String? _sex;
  bool _saving = false;
  bool _loaded = false;

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _tagIdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _populateFromAnimal(AnimalAsset animal) {
    if (_loaded) return;
    _loaded = true;
    _nameController.text = animal.name;
    _breedController.text = animal.animalType ?? '';
    _tagIdController.text = animal.primaryTagId == '—' ? '' : animal.primaryTagId;
    _notesController.text = animal.notes ?? '';
    _status = animal.status;
    _sex = animal.sex;
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final service = ref.read(animalServiceProvider);

      final idTags = _tagIdController.text.trim().isNotEmpty
          ? [IdTag(id: _tagIdController.text.trim())]
          : <IdTag>[];

      final animal = AnimalAsset(
        id: widget.id ?? '',
        name: _nameController.text.trim(),
        status: _status,
        animalType: _breedController.text.trim(),
        idTags: idTags,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        sex: _sex,
      );

      if (widget.isEditing) {
        await service.updateAnimal(animal);
      } else {
        await service.createAnimal(animal);
      }

      if (mounted) {
        ref.read(animalListProvider.notifier).loadAnimals(refresh: true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Animal ${widget.isEditing ? 'updated' : 'created'} successfully'),
          ),
        );
        context.go('/cattle');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget body;

    if (widget.isEditing) {
      final animalAsync = ref.watch(animalDetailProvider(widget.id!));
      body = animalAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorDisplay(message: e.toString()),
        data: (animal) {
          _populateFromAnimal(animal);
          return _buildForm(theme);
        },
      );
    } else {
      body = _buildForm(theme);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Animal' : 'New Animal'),
      ),
      body: body,
    );
  }

  Widget _buildForm(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name *',
                prefixIcon: Icon(Icons.pets),
              ),
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _breedController,
              decoration: const InputDecoration(
                labelText: 'Breed / Type *',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              textInputAction: TextInputAction.next,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Breed / Type is required'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _tagIdController,
              decoration: const InputDecoration(
                labelText: 'Tag ID',
                prefixIcon: Icon(Icons.label_outline),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Status',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
              items: const [
                DropdownMenuItem(value: 'active', child: Text('Active')),
                DropdownMenuItem(value: 'archived', child: Text('Archived')),
              ],
              onChanged: (v) => setState(() => _status = v ?? 'active'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _sex,
              decoration: const InputDecoration(
                labelText: 'Sex',
                prefixIcon: Icon(Icons.wc_outlined),
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('Not specified')),
                DropdownMenuItem(value: 'F', child: Text('Female')),
                DropdownMenuItem(value: 'M', child: Text('Male')),
              ],
              onChanged: (v) => setState(() => _sex = v),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                prefixIcon: Icon(Icons.notes_outlined),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              textInputAction: TextInputAction.newline,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _saving ? null : _handleSave,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(widget.isEditing ? 'Save Changes' : 'Create Animal'),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _saving ? null : () => context.pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
