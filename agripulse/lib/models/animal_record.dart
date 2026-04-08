enum AnimalRecordType {
  activity('activity', 'Activity'),
  observation('observation', 'Observation'),
  input('input', 'Input'),
  harvest('harvest', 'Harvest'),
  seeding('seeding', 'Seeding'),
  transplanting('transplanting', 'Transplanting'),
  labTest('lab_test', 'Lab test'),
  maintenance('maintenance', 'Maintenance'),
  medical('medical', 'Medical'),
  birth('birth', 'Birth');

  const AnimalRecordType(this.apiPath, this.label);
  final String apiPath;
  final String label;
}

class AnimalRecord {
  final String id;
  final AnimalRecordType type;
  final String title;
  final DateTime? timestamp;
  final String? notes;

  const AnimalRecord({
    required this.id,
    required this.type,
    required this.title,
    this.timestamp,
    this.notes,
  });

  factory AnimalRecord.fromJsonApi(
    Map<String, dynamic> jsonApiData,
    AnimalRecordType type,
  ) {
    final attributes = jsonApiData['attributes'] as Map<String, dynamic>? ?? {};
    final notesRaw = attributes['notes'];
    return AnimalRecord(
      id: jsonApiData['id']?.toString() ?? '',
      type: type,
      title: attributes['name']?.toString() ?? type.label,
      timestamp: DateTime.tryParse(attributes['timestamp']?.toString() ?? ''),
      notes: notesRaw is Map ? notesRaw['value']?.toString() : null,
    );
  }
}
