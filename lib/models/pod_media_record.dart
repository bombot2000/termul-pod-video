class PodMediaRecord {
  const PodMediaRecord({required this.path, required this.type, required this.createdAt, this.latitude, this.longitude, this.accuracy});
  final String path;
  final String type;
  final DateTime createdAt;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  Map<String, Object?> toJson() => {'path': path, 'type': type, 'createdAt': createdAt.toIso8601String(), 'latitude': latitude, 'longitude': longitude, 'accuracy': accuracy};
  factory PodMediaRecord.fromJson(Map<String, dynamic> json) => PodMediaRecord(
    path: json['path'] as String,
    type: json['type'] as String? ?? 'photo',
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    accuracy: (json['accuracy'] as num?)?.toDouble(),
  );
}
