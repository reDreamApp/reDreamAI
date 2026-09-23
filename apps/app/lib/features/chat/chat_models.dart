/// IRT stages, in canonical order. [wire] is the value the API sends.
enum IrtStage {
  recording('recording'),
  intensity('intensity'),
  rewriting('rewriting'),
  summary('summary'),
  finalStage('final')
  ;

  const IrtStage(this.wire);

  final String wire;

  static IrtStage fromWire(String? value) => values.firstWhere(
    (stage) => stage.wire == value,
    orElse: () => IrtStage.recording,
  );
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.stage,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'].toString(),
    role: json['role'] as String,
    content: json['content'] as String,
    stage: json['stage'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  final String id;
  final String role;
  final String content;
  final String? stage;
  final DateTime createdAt;

  bool get isUser => role == 'user';
}

class SafetyEvent {
  SafetyEvent({
    required this.risk,
    required this.categories,
    required this.confidence,
  });

  factory SafetyEvent.fromJson(Map<String, dynamic> json) => SafetyEvent(
    risk: json['risk'] as String,
    categories: (json['categories'] as List).cast<String>(),
    confidence: (json['confidence'] as num).toDouble(),
  );

  final String risk;
  final List<String> categories;
  final double confidence;
}

class ChatStart {
  ChatStart({
    required this.chatId,
    required this.language,
    required this.currentStage,
  });

  factory ChatStart.fromJson(Map<String, dynamic> json) => ChatStart(
    chatId: json['chat_id'] as int,
    language: json['language'] as String,
    currentStage: IrtStage.fromWire(json['current_stage'] as String?),
  );

  final int chatId;
  final String language;
  final IrtStage currentStage;
}

class ChatTurn {
  ChatTurn({
    required this.userMessage,
    required this.aiMessage,
    required this.stage,
    required this.isDone,
    required this.safetyEvent,
  });

  factory ChatTurn.fromJson(Map<String, dynamic> json) {
    final ai = json['ai_message'] as Map<String, dynamic>?;
    final safety = json['safety_event'] as Map<String, dynamic>?;
    return ChatTurn(
      userMessage: ChatMessage.fromJson(
        json['user_message'] as Map<String, dynamic>,
      ),
      aiMessage: ai == null ? null : ChatMessage.fromJson(ai),
      stage: IrtStage.fromWire(json['stage'] as String?),
      isDone: json['is_done'] as bool,
      safetyEvent: safety == null ? null : SafetyEvent.fromJson(safety),
    );
  }

  final ChatMessage userMessage;
  final ChatMessage? aiMessage;
  final IrtStage stage;
  final bool isDone;
  final SafetyEvent? safetyEvent;
}
