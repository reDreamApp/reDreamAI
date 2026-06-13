enum IrtStage { recording, intensity, rewriting, summary, finalStage }

IrtStage stageFromString(String s) {
  switch (s) {
    case 'recording':
      return IrtStage.recording;
    case 'intensity':
      return IrtStage.intensity;
    case 'rewriting':
      return IrtStage.rewriting;
    case 'summary':
      return IrtStage.summary;
    case 'final':
      return IrtStage.finalStage;
  }
  return IrtStage.recording;
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.stage,
    required this.createdAt,
  });

  final String id;
  final String role; // 'user' | 'assistant'
  final String content;
  final String? stage;
  final DateTime createdAt;

  bool get isUser => role == 'user';

  static ChatMessage fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'].toString(),
        role: json['role'] as String,
        content: json['content'] as String,
        stage: json['stage'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

/// One row of `GET /api/v1/chats` (backend `ChatOut`) — used by the
/// chat-history drawer and the resume-on-open flow.
class ChatSummary {
  ChatSummary({
    required this.id,
    required this.language,
    required this.currentStage,
    required this.isDone,
    required this.isNightmare,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String language;
  final IrtStage currentStage;
  final bool isDone;
  final bool? isNightmare;
  final String? title;
  final DateTime createdAt;
  final DateTime updatedAt;

  static ChatSummary fromJson(Map<String, dynamic> json) => ChatSummary(
        id: json['id'] as int,
        language: json['language'] as String,
        currentStage: stageFromString(json['current_stage'] as String),
        isDone: json['is_done'] as bool? ?? false,
        isNightmare: json['is_nightmare'] as bool?,
        title: json['title'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}

class SafetyEvent {
  SafetyEvent({
    required this.risk,
    required this.categories,
    required this.confidence,
    this.message,
  });

  final String risk;
  final List<String> categories;
  final double confidence;

  /// Optional backend-localized helpline text. Absent on older backends.
  final String? message;

  static SafetyEvent fromJson(Map<String, dynamic> json) => SafetyEvent(
        risk: json['risk'] as String,
        categories: (json['categories'] as List).cast<String>(),
        confidence: (json['confidence'] as num).toDouble(),
        message: json['message'] as String?,
      );
}

class ChatStart {
  ChatStart({required this.chatId, required this.language, required this.currentStage});

  final int chatId;
  final String language;
  final IrtStage currentStage;

  static ChatStart fromJson(Map<String, dynamic> json) => ChatStart(
        chatId: json['chat_id'] as int,
        language: json['language'] as String,
        currentStage: stageFromString(json['current_stage'] as String),
      );
}

class ChatTurn {
  ChatTurn({
    required this.userMessage,
    required this.aiMessage,
    required this.stage,
    required this.isDone,
    required this.safetyEvent,
  });

  final ChatMessage userMessage;
  final ChatMessage? aiMessage;
  final IrtStage stage;
  final bool isDone;
  final SafetyEvent? safetyEvent;

  static ChatTurn fromJson(Map<String, dynamic> json) => ChatTurn(
        userMessage: ChatMessage.fromJson(json['user_message'] as Map<String, dynamic>),
        aiMessage: json['ai_message'] == null
            ? null
            : ChatMessage.fromJson(json['ai_message'] as Map<String, dynamic>),
        stage: stageFromString(json['stage'] as String),
        isDone: json['is_done'] as bool,
        safetyEvent: json['safety_event'] == null
            ? null
            : SafetyEvent.fromJson(json['safety_event'] as Map<String, dynamic>),
      );
}
