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

  factory WaterLevelLog.fromJsonApi(Map<String, dynamic> jsonApiData) {
    final attributes = jsonApiData['attributes'] as Map<String, dynamic>? ?? {};

    // Parse timestamp — farmOS sends Unix seconds as int or string
    final rawTs = attributes['timestamp'];
    DateTime ts;
    if (rawTs is int) {
      ts = DateTime.fromMillisecondsSinceEpoch(rawTs * 1000, isUtc: true);
    } else if (rawTs is String) {
      ts = DateTime.tryParse(rawTs)?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(
            (int.tryParse(rawTs) ?? 0) * 1000,
            isUtc: true,
          );
    } else {
      ts = DateTime.now().toUtc();
    }

    // Parse quantity array — grab first measurement value
    double? waterValue;
    String waterUnits = 'cm';
    final quantities = attributes['quantity'];
    if (quantities is List && quantities.isNotEmpty) {
      final q = quantities.first as Map<String, dynamic>;
      final rawVal = q['value'];
      if (rawVal is num) {
        waterValue = rawVal.toDouble();
      } else if (rawVal is String) {
        waterValue = double.tryParse(rawVal);
      }
      waterUnits = q['units'] as String? ?? 'cm';
    }

    return WaterLevelLog(
      id: jsonApiData['id'] as String,
      name: attributes['name'] as String? ?? '',
      timestamp: ts,
      status: attributes['status'] as String? ?? 'done',
      value: waterValue,
      units: waterUnits,
    );
  }
}
