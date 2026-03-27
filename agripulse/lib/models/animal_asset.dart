class IdTag {
  final String? id;
  final String? type;
  final String? location;

  const IdTag({this.id, this.type, this.location});

  factory IdTag.fromJson(Map<String, dynamic> json) {
    return IdTag(
      id: json['id'] as String?,
      type: json['type'] as String?,
      location: json['location'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (location != null) 'location': location,
    };
  }

  IdTag copyWith({String? id, String? type, String? location}) {
    return IdTag(
      id: id ?? this.id,
      type: type ?? this.type,
      location: location ?? this.location,
    );
  }
}

class AnimalAsset {
  final String id;
  final String name;
  final String status;
  final String? animalType;
  final List<IdTag> idTags;
  final String? notes;
  final String? sex;

  const AnimalAsset({
    required this.id,
    required this.name,
    this.status = 'active',
    this.animalType,
    this.idTags = const [],
    this.notes,
    this.sex,
  });

  factory AnimalAsset.fromJsonApi(Map<String, dynamic> jsonApiData) {
    final attributes = jsonApiData['attributes'] as Map<String, dynamic>? ?? {};
    final idTagsRaw = attributes['id_tag'];
    final notesRaw = attributes['notes'];

    return AnimalAsset(
      id: jsonApiData['id'] as String,
      name: attributes['name'] as String? ?? '',
      status: attributes['status'] as String? ?? 'active',
      animalType: attributes['animal_type'] as String?,
      idTags: idTagsRaw is List
          ? idTagsRaw
              .map((e) => IdTag.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
      notes: notesRaw is Map ? notesRaw['value'] as String? : null,
      sex: attributes['sex'] as String?,
    );
  }

  Map<String, dynamic> toJsonApiAttributes() {
    return {
      'name': name,
      'status': status,
      if (animalType != null) 'animal_type': animalType,
      if (idTags.isNotEmpty) 'id_tag': idTags.map((t) => t.toJson()).toList(),
      if (notes != null)
        'notes': {'value': notes, 'format': 'default'},
      if (sex != null) 'sex': sex,
    };
  }

  Map<String, dynamic> toCreatePayload() {
    return {
      'data': {
        'type': 'asset--animal',
        'attributes': toJsonApiAttributes(),
      },
    };
  }

  Map<String, dynamic> toUpdatePayload() {
    return {
      'data': {
        'type': 'asset--animal',
        'id': id,
        'attributes': toJsonApiAttributes(),
      },
    };
  }

  AnimalAsset copyWith({
    String? id,
    String? name,
    String? status,
    String? animalType,
    List<IdTag>? idTags,
    String? notes,
    String? sex,
  }) {
    return AnimalAsset(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      animalType: animalType ?? this.animalType,
      idTags: idTags ?? this.idTags,
      notes: notes ?? this.notes,
      sex: sex ?? this.sex,
    );
  }

  String get primaryTagId =>
      idTags.isNotEmpty ? (idTags.first.id ?? '—') : '—';
}
