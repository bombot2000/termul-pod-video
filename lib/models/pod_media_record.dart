class PodMediaRecord {
  const PodMediaRecord({
    required this.id,
    required this.path,
    required this.type,
    required this.createdAt,
  });

  final String id;
  final String path;
  final String type;
  final DateTime createdAt;

  bool get isVideo => type == 'video';

  Map<String, Object?> toJson() => {
        'id': id,
        'path': path,
        'type': type,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PodMediaRecord.fromJson(Map<String, dynamic> json) {
    return PodMediaRecord(
      id: json['id'] as String,
      path: json['path'] as String,
      type: json['type'] as String? ?? 'photo',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
