class WaterLevelLog {
  final String id;
  final String name;
  final DateTime timestamp;
  final String status;
  final double? value;
  final String units;

  const WaterLevelLog({
    required this.id,
    required this.name,
    required this.timestamp,
    this.status = 'done',
    this.value,
    this.units = 'cm',
  });
}
