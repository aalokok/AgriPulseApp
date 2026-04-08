import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers/auth_provider.dart';
import 'providers/settings_provider.dart';
import 'services/background_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final isMobilePlatform = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  // These plugins rely on mobile platform channels and can crash on web/desktop.
  if (isMobilePlatform) {
    await NotificationService().init();
    await BackgroundService().init();
  }

  final container = ProviderContainer();

  // Restore session and settings before first frame
  await container.read(authProvider.notifier).tryRestoreSession();
  await container.read(settingsProvider.notifier).load();

  // If authenticated and notifications enabled, register background task
  final authState = container.read(authProvider);
  final settingsState = container.read(settingsProvider);
  if (isMobilePlatform &&
      authState.isAuthenticated &&
      settingsState.notificationsEnabled) {
    await BackgroundService().registerPeriodicTask();
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const AgriPulseApp(),
    ),
  );
}
