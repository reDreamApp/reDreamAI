import '../../core/api/api_client.dart';
import 'chat_models.dart';

class ChatService {
  ChatService(this._api);

  final ApiClient _api;

  Future<ChatStart> start({required String language}) async =>
      ChatStart.fromJson(
        await _api.post('/api/v1/chats/start', {'language': language}),
      );

  Future<List<ChatMessage>> listMessages(int chatId) async {
    final list = await _api.getList('/api/v1/chats/$chatId/messages');
    return [
      for (final e in list) ChatMessage.fromJson(e as Map<String, dynamic>),
    ];
  }

  Future<ChatTurn> sendMessage({
    required int chatId,
    required String content,
  }) async => ChatTurn.fromJson(
    await _api.post('/api/v1/chats/$chatId/message', {'content': content}),
  );
}
