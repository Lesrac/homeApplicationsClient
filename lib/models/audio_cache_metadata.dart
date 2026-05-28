class AudioCacheMetadata {
  final String title;
  final DateTime lastAccessed;
  final DateTime downloadedAt;
  final int fileSize;

  AudioCacheMetadata({
    required this.title,
    required this.lastAccessed,
    required this.downloadedAt,
    required this.fileSize,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'lastAccessed': lastAccessed.toIso8601String(),
      'downloadedAt': downloadedAt.toIso8601String(),
      'fileSize': fileSize,
    };
  }

  factory AudioCacheMetadata.fromJson(Map<String, dynamic> json) {
    return AudioCacheMetadata(
      title: json['title'] as String,
      lastAccessed: DateTime.parse(json['lastAccessed'] as String),
      downloadedAt: DateTime.parse(json['downloadedAt'] as String),
      fileSize: json['fileSize'] as int,
    );
  }

  AudioCacheMetadata copyWith({
    String? title,
    DateTime? lastAccessed,
    DateTime? downloadedAt,
    int? fileSize,
  }) {
    return AudioCacheMetadata(
      title: title ?? this.title,
      lastAccessed: lastAccessed ?? this.lastAccessed,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      fileSize: fileSize ?? this.fileSize,
    );
  }
}
