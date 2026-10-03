import 'package:redream_app/core/api/api_client.dart';
import 'package:redream_app/features/chat/chat_models.dart';

class ChatService {
  ChatService(this._api);

  final ApiClient _api;

  static const _base = '/api/v1/chats';

  Future<ChatStart> start({required String language}) async =>
      ChatStart.fromJson(
        await _api.post('$_base/start', {'language': language}),
      );

  Future<List<ChatSummary>> listChats() async => [
    for (final e in await _api.getList(_base))
      ChatSummary.fromJson(e as Map<String, dynamic>),
  ];

  Future<List<ChatMessage>> listMessages(int chatId) async => [
    for (final e in await _api.getList('$_base/$chatId/messages'))
      ChatMessage.fromJson(e as Map<String, dynamic>),
  ];

  Future<ChatTurn> sendMessage({
    required int chatId,
    required String content,
  }) async => ChatTurn.fromJson(
    await _api.post('$_base/$chatId/message', {'content': content}, aiTimeout),
  );

  Future<void> deleteChat(int chatId) => _api.delete('$_base/$chatId');

  Future<void> report({
    required int chatId,
    required ChatMessage message,
    required ReportReason reason,
    String? details,
  }) => _api.post('/api/v1/reports/ai-content', {
    'chat_id': chatId,
    'message_id': message.id,
    'target_role': message.isUser ? 'user' : 'assistant',
    'reason': reason.wire,
    if (details != null && details.trim().isNotEmpty) 'details': details.trim(),
  });
}
