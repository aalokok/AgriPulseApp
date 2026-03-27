import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/background_service.dart';
import '../../services/notification_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _thresholdController = TextEditingController();
  bool _initialized = false;

  @override
  void dispose() {
    _thresholdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final authState = ref.watch(authProvider);

    if (!_initialized) {
      _initialized = true;
      _thresholdController.text =
          settings.waterLevelThreshold.toStringAsFixed(1);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Server info
          Text(
            'Connection',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.dns_outlined,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text('Server',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          )),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    authState.serverUrl ?? '—',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 10,
                        color: authState.isAuthenticated
                            ? Colors.green
                            : Colors.red,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        authState.isAuthenticated
                            ? 'Connected'
                            : 'Disconnected',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Threshold
          Text(
            'Water Level Alerts',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _thresholdController,
                    decoration: const InputDecoration(
                      labelText: 'Low level threshold (cm)',
                      prefixIcon: Icon(Icons.straighten),
                      helperText:
                          'You\'ll be alerted when water drops below this level',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onSubmitted: (value) {
                      final v = double.tryParse(value);
                      if (v != null) {
                        ref.read(settingsProvider.notifier).setThreshold(v);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonal(
                      onPressed: () {
                        final v =
                            double.tryParse(_thresholdController.text);
                        if (v != null) {
                          ref
                              .read(settingsProvider.notifier)
                              .setThreshold(v);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Threshold updated')),
                          );
                        }
                      },
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Notifications toggle
          Card(
            child: SwitchListTile(
              title: const Text('Background notifications'),
              subtitle: const Text(
                  'Get hourly water level updates and threshold alerts'),
              secondary: const Icon(Icons.notifications_outlined),
              value: settings.notificationsEnabled,
              onChanged: (enabled) async {
                await ref
                    .read(settingsProvider.notifier)
                    .setNotificationsEnabled(enabled);
                final bgService = BackgroundService();
                if (enabled) {
                  await NotificationService().requestPermissions();
                  await bgService.registerPeriodicTask();
                } else {
                  await bgService.cancelAll();
                }
              },
            ),
          ),
          const SizedBox(height: 32),

          // Logout
          OutlinedButton.icon(
            onPressed: () => _confirmLogout(context, ref),
            icon: Icon(Icons.logout, color: theme.colorScheme.error),
            label: Text('Logout',
                style: TextStyle(color: theme.colorScheme.error)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text(
            'Are you sure you want to disconnect from the farmOS server?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await BackgroundService().cancelAll();
              await ref.read(authProvider.notifier).logout();
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
