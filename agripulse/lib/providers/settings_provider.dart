import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';

class SettingsState {
  final double waterLevelThreshold;
  final bool notificationsEnabled;

  const SettingsState({
    this.waterLevelThreshold = AppConstants.defaultWaterLevelThreshold,
    this.notificationsEnabled = true,
  });

  SettingsState copyWith({
    double? waterLevelThreshold,
    bool? notificationsEnabled,
  }) {
    return SettingsState(
      waterLevelThreshold: waterLevelThreshold ?? this.waterLevelThreshold,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() => const SettingsState();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = SettingsState(
      waterLevelThreshold: prefs.getDouble(AppConstants.keyThreshold) ??
          AppConstants.defaultWaterLevelThreshold,
      notificationsEnabled:
          prefs.getBool(AppConstants.keyNotificationsEnabled) ?? true,
    );
  }

  Future<void> setThreshold(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(AppConstants.keyThreshold, value);
    state = state.copyWith(waterLevelThreshold: value);
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyNotificationsEnabled, enabled);
    state = state.copyWith(notificationsEnabled: enabled);
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
