import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/water_level_log.dart';
import 'auth_provider.dart';

class WaterLevelState {
  final WaterLevelLog? latestReading;
  final List<WaterLevelLog> recentReadings;
  final bool isLoading;
  final String? error;

  const WaterLevelState({
    this.latestReading,
    this.recentReadings = const [],
    this.isLoading = false,
    this.error,
  });

  WaterLevelState copyWith({
    WaterLevelLog? latestReading,
    List<WaterLevelLog>? recentReadings,
    bool? isLoading,
    String? error,
  }) {
    return WaterLevelState(
      latestReading: latestReading ?? this.latestReading,
      recentReadings: recentReadings ?? this.recentReadings,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class WaterLevelNotifier extends Notifier<WaterLevelState> {
  @override
  WaterLevelState build() => const WaterLevelState();

  Future<void> loadData() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);

    try {
      final service = ref.read(waterLevelServiceProvider);
      final latest = await service.getLatestReading();
      final readings = await service.getReadings(pageSize: 50);

      state = state.copyWith(
        isLoading: false,
        latestReading: latest,
        recentReadings: readings,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() => loadData();

  Future<List<WaterLevelLog>> getChartData({int days = 1}) async {
    final since = DateTime.now().subtract(Duration(days: days));
    final service = ref.read(waterLevelServiceProvider);
    return service.getReadingsSince(since);
  }
}

final waterLevelProvider =
    NotifierProvider<WaterLevelNotifier, WaterLevelState>(
        WaterLevelNotifier.new);
