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

    // Resolve quantity from JSON:API relationships + included resources.
    // The client attaches a `_included` map keyed by "type:id".
    double? waterValue;
    String waterUnits = 'cm';
    final relationships =
        jsonApiData['relationships'] as Map<String, dynamic>? ?? {};
    final quantityRel = relationships['quantity'] as Map<String, dynamic>?;
    final includedMap =
        jsonApiData['_included'] as Map<String, Map<String, dynamic>>?;

    if (quantityRel != null && includedMap != null) {
      final relData = quantityRel['data'];
      final refs = relData is List ? relData : (relData != null ? [relData] : []);
      for (final ref in refs) {
        final key = '${ref['type']}:${ref['id']}';
        final included = includedMap[key];
        if (included == null) continue;
        final qAttrs = included['attributes'] as Map<String, dynamic>? ?? {};
        final rawVal = qAttrs['value'];
        if (rawVal is Map) {
          final decimal = rawVal['decimal'];
          waterValue = decimal is String
              ? double.tryParse(decimal)
              : (decimal is num ? decimal.toDouble() : null);
        } else if (rawVal is num) {
          waterValue = rawVal.toDouble();
        } else if (rawVal is String) {
          waterValue = double.tryParse(rawVal);
        }
        final label = qAttrs['label'] as String?;
        if (label != null && label.isNotEmpty) {
          waterUnits = 'cm';
        }
        if (waterValue != null) break;
      }
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
