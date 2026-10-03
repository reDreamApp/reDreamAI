/// IRT stages in canonical order. [wire] is the value the API sends.
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
    (s) => s.wire == value,
    orElse: () => IrtStage.recording,
  );

  /// Nightmares go through all five stages; positive dreams skip two.
  static List<IrtStage> path({required bool nightmare}) => nightmare
      ? values
      : const [IrtStage.recording, IrtStage.summary, IrtStage.finalStage];
}

enum MessageStatus { sent, sending, failed }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.stage,
    this.status = MessageStatus.sent,
    this.isLocal = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'].toString(),
    role: json['role'] as String,
    content: json['content'] as String,
    stage: json['stage'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  /// Client-side message (welcome text, unsent input). Cannot be reported.
  factory ChatMessage.local({
    required String id,
    required String role,
    required String content,
    MessageStatus status = MessageStatus.sent,
  }) => ChatMessage(
    id: id,
    role: role,
    content: content,
    createdAt: DateTime.now(),
    status: status,
    isLocal: true,
  );

  final String id;
  final String role;
  final String content;
  final String? stage;
  final DateTime createdAt;
  final MessageStatus status;
  final bool isLocal;

  bool get isUser => role == 'user';

  ChatMessage copyWith({MessageStatus? status}) => ChatMessage(
    id: id,
    role: role,
    content: content,
    stage: stage,
    createdAt: createdAt,
    status: status ?? this.status,
    isLocal: isLocal,
  );
}

class ChatSummary {
  const ChatSummary({
    required this.id,
    required this.language,
    required this.stage,
    required this.isDone,
    required this.createdAt,
    required this.updatedAt,
    this.isNightmare,
    this.title,
  });

  factory ChatSummary.fromJson(Map<String, dynamic> json) => ChatSummary(
    id: json['id'] as int,
    language: json['language'] as String,
    stage: IrtStage.fromWire(json['current_stage'] as String?),
    isDone: json['is_done'] as bool? ?? false,
    isNightmare: json['is_nightmare'] as bool?,
    title: json['title'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  final int id;
  final String language;
  final IrtStage stage;
  final bool isDone;
  final bool? isNightmare;
  final String? title;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class SafetyEvent {
  const SafetyEvent({
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
  const ChatStart({required this.chatId, required this.stage});

  factory ChatStart.fromJson(Map<String, dynamic> json) => ChatStart(
    chatId: json['chat_id'] as int,
    stage: IrtStage.fromWire(json['current_stage'] as String?),
  );

  final int chatId;
  final IrtStage stage;
}

class ChatTurn {
  const ChatTurn({
    required this.userMessage,
    required this.stage,
    required this.isDone,
    this.aiMessage,
    this.safetyEvent,
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
      isDone: json['is_done'] as bool? ?? false,
      safetyEvent: safety == null ? null : SafetyEvent.fromJson(safety),
    );
  }

  final ChatMessage userMessage;
  final ChatMessage? aiMessage;
  final IrtStage stage;
  final bool isDone;
  final SafetyEvent? safetyEvent;
}

enum ReportReason {
  childSafety('child_safety'),
  selfHarm('self_harm'),
  sexual('sexual'),
  hate('hate'),
  violence('violence'),
  harassment('harassment'),
  deceptive('deceptive'),
  other('other')
  ;

  const ReportReason(this.wire);

  final String wire;
}
