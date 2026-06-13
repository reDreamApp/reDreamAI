/// Wire model for the backend's DreamOut schema
/// (apps/api .../dreams/schemas.py). Field names are the JSON contract.
class Dream {
  Dream({
    required this.id,
    required this.title,
    required this.originalDream,
    required this.isNightmare,
    required this.isCurrentDream,
    required this.source,
    required this.createdAt,
    required this.lastEdited,
    this.rewrittenDream,
    this.intensity,
    this.imageUrl,
    this.sessionId,
    this.practiceTimestamps = const [],
    this.rehearsalAudioUrl,
    this.rehearsalScript,
    this.rehearsalDuration,
  });

  factory Dream.fromJson(Map<String, dynamic> json) {
    return Dream(
      id: json['id'] as int,
      title: json['title'] as String,
      originalDream: json['original_dream'] as String,
      rewrittenDream: json['rewritten_dream'] as String?,
      intensity: json['intensity'] as int?,
      isNightmare: json['is_nightmare'] as bool? ?? false,
      isCurrentDream: json['is_current_dream'] as bool? ?? false,
      imageUrl: json['image_url'] as String?,
      sessionId: json['session_id'] as String?,
      source: json['source'] as String? ?? 'manual',
      createdAt: DateTime.parse(json['created_at'] as String),
      lastEdited: DateTime.parse(json['last_edited'] as String),
      practiceTimestamps: (json['practice_timestamps'] as List<dynamic>?)
              ?.map((e) => DateTime.tryParse(e.toString()))
              .whereType<DateTime>()
              .toList() ??
          const [],
      rehearsalAudioUrl: json['rehearsal_audio_url'] as String?,
      rehearsalScript: json['rehearsal_script'] as String?,
      rehearsalDuration: json['rehearsal_duration'] as String?,
    );
  }

  final int id;
  final String title;
  final String originalDream;
  final String? rewrittenDream;
  final int? intensity;
  final bool isNightmare;
  final bool isCurrentDream;
  final String? imageUrl;
  final String? sessionId;
  final String source;
  final DateTime createdAt;
  final DateTime lastEdited;
  final List<DateTime> practiceTimestamps;
  final String? rehearsalAudioUrl;
  final String? rehearsalScript;
  final String? rehearsalDuration;
}
