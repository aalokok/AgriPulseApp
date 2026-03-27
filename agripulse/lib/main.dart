import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers/auth_provider.dart';
import 'providers/settings_provider.dart';
import 'services/background_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService().init();
  await BackgroundService().init();

  final container = ProviderContainer();

  // Restore session and settings before first frame
  await container.read(authProvider.notifier).tryRestoreSession();
  await container.read(settingsProvider.notifier).load();

  // If authenticated and notifications enabled, register background task
  final authState = container.read(authProvider);
  final settingsState = container.read(settingsProvider);
  if (authState.isAuthenticated && settingsState.notificationsEnabled) {
    await BackgroundService().registerPeriodicTask();
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const AgriPulseApp(),
    ),
  );
}
