class WaterLevelLog {
  final String id;
  final String name;
  final DateTime timestamp;
  final String status;
  final double? value;
  final String units;
  final String sensorId;
  final String sensorName;

  const WaterLevelLog({
    required this.id,
    required this.name,
    required this.timestamp,
    this.status = 'done',
    this.value,
    this.units = 'cm',
    this.sensorId = '',
    this.sensorName = '',
  });
}

class SensorInfo {
  final String id;
  final String name;
  final int fieldNumber;

  const SensorInfo({
    required this.id,
    required this.name,
    required this.fieldNumber,
  });
}
