import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/water_level_log.dart';
import 'auth_provider.dart';

class WaterLevelState {
  final WaterLevelLog? latestReading;
  final List<WaterLevelLog> recentReadings;
  final List<SensorInfo> sensors;
  final String? selectedSensorId;
  final bool isLoading;
  final String? error;

  const WaterLevelState({
    this.latestReading,
    this.recentReadings = const [],
    this.sensors = const [],
    this.selectedSensorId,
    this.isLoading = false,
    this.error,
  });

  WaterLevelState copyWith({
    WaterLevelLog? latestReading,
    List<WaterLevelLog>? recentReadings,
    List<SensorInfo>? sensors,
    String? selectedSensorId,
    bool clearSelectedSensor = false,
    bool? isLoading,
    String? error,
  }) {
    return WaterLevelState(
      latestReading: latestReading ?? this.latestReading,
      recentReadings: recentReadings ?? this.recentReadings,
      sensors: sensors ?? this.sensors,
      selectedSensorId: clearSelectedSensor
          ? null
          : (selectedSensorId ?? this.selectedSensorId),
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
      final sensors = await service.getSensors();
      final sensorId = state.selectedSensorId;
      final latest = await service.getLatestReading(sensorId: sensorId);
      final readings =
          await service.getReadings(pageSize: 50, sensorId: sensorId);

      state = state.copyWith(
        isLoading: false,
        sensors: sensors,
        latestReading: latest,
        recentReadings: readings,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void selectSensor(String? sensorId) {
    if (sensorId == state.selectedSensorId) return;
    state = state.copyWith(
      selectedSensorId: sensorId,
      clearSelectedSensor: sensorId == null,
    );
    loadData();
  }

  Future<void> refresh() => loadData();

  Future<List<WaterLevelLog>> getChartData({int days = 1}) async {
    final since = DateTime.now().subtract(Duration(days: days));
    final service = ref.read(waterLevelServiceProvider);
    return service.getReadingsSince(since, sensorId: state.selectedSensorId);
  }
}

final waterLevelProvider =
    NotifierProvider<WaterLevelNotifier, WaterLevelState>(
        WaterLevelNotifier.new);
