class PodMediaRecord {
  const PodMediaRecord({
    required this.path,
    required this.type,
    required this.createdAt,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.address,
    this.watermarkApplied,
    this.gallerySaved,
    this.locationMocked,
    this.locationAgeSeconds,
    this.locationClockOffsetSeconds,
  });

  final String path;
  final String type;
  final DateTime createdAt;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final String? address;
  final bool? watermarkApplied;
  final bool? gallerySaved;

  /// True when Android flagged the position as coming from a mock provider.
  final bool? locationMocked;

  /// Age of the GPS fix, in seconds, at the moment it was attached.
  final int? locationAgeSeconds;

  /// Device clock minus GPS time, in seconds, when the app had to correct for
  /// a wrong phone clock. Null when unknown, 0 when the clock agreed.
  final int? locationClockOffsetSeconds;

  PodMediaRecord copyWith({bool? gallerySaved}) => PodMediaRecord(
        path: path,
        type: type,
        createdAt: createdAt,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        address: address,
        watermarkApplied: watermarkApplied,
        gallerySaved: gallerySaved ?? this.gallerySaved,
        locationMocked: locationMocked,
        locationAgeSeconds: locationAgeSeconds,
        locationClockOffsetSeconds: locationClockOffsetSeconds,
      );

  Map<String, Object?> toJson() => {
        'path': path,
        'type': type,
        'createdAt': createdAt.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'address': address,
        'watermarkApplied': watermarkApplied,
        'gallerySaved': gallerySaved,
        'locationMocked': locationMocked,
        'locationAgeSeconds': locationAgeSeconds,
        'locationClockOffsetSeconds': locationClockOffsetSeconds,
      };

  factory PodMediaRecord.fromJson(Map<String, dynamic> json) =>
      PodMediaRecord(
        path: json['path'] as String,
        type: json['type'] as String? ?? 'photo',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        accuracy: (json['accuracy'] as num?)?.toDouble(),
        address: json['address'] as String?,
        watermarkApplied: json['watermarkApplied'] as bool?,
        gallerySaved: json['gallerySaved'] as bool?,
        locationMocked: json['locationMocked'] as bool?,
        locationAgeSeconds: (json['locationAgeSeconds'] as num?)?.toInt(),
        locationClockOffsetSeconds:
            (json['locationClockOffsetSeconds'] as num?)?.toInt(),
      );
}
