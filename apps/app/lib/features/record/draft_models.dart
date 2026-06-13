/// Local-only manual dream draft.
///
/// Drafts live entirely on-device until the user explicitly saves them to
/// their collection (see `IDraftRepository`). Legacy stored these in a Drift
/// SQLite table; the new app keeps them as a JSON list in `shared_preferences`.
class DreamDraft {
  const DreamDraft({
    required this.id,
    required this.title,
    required this.originalDream,
    required this.isNightmare,
    required this.updatedAt,
    this.rewrittenDream,
    this.intensity,
  });

  factory DreamDraft.fromJson(Map<String, dynamic> json) {
    return DreamDraft(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      originalDream: json['originalDream'] as String? ?? '',
      rewrittenDream: json['rewrittenDream'] as String?,
      intensity: (json['intensity'] as num?)?.toInt(),
      isNightmare: json['isNightmare'] as bool? ?? false,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String id;
  final String title;
  final String originalDream;
  final String? rewrittenDream;
  final int? intensity;
  final bool isNightmare;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'originalDream': originalDream,
      'rewrittenDream': rewrittenDream,
      'intensity': intensity,
      'isNightmare': isNightmare,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  DreamDraft copyWith({
    String? title,
    String? originalDream,
    String? rewrittenDream,
    bool clearRewrittenDream = false,
    int? intensity,
    bool clearIntensity = false,
    bool? isNightmare,
    DateTime? updatedAt,
  }) {
    return DreamDraft(
      id: id,
      title: title ?? this.title,
      originalDream: originalDream ?? this.originalDream,
      rewrittenDream:
          clearRewrittenDream ? null : (rewrittenDream ?? this.rewrittenDream),
      intensity: clearIntensity ? null : (intensity ?? this.intensity),
      isNightmare: isNightmare ?? this.isNightmare,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
