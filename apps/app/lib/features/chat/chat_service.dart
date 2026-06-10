import '../../core/api/api_client.dart';
import 'chat_models.dart';

abstract class IChatService {
  Future<ChatStart> start({required String language});
  Future<List<ChatMessage>> listMessages(int chatId);
  Future<ChatTurn> sendMessage({required int chatId, required String content});
}

class ChatService implements IChatService {
  ChatService(this._api);
  final ApiClient _api;

  @override
  Future<ChatStart> start({required String language}) async {
    final json = await _api.post('/api/v1/chats/start', {'language': language});
    return ChatStart.fromJson(json);
  }

  @override
  Future<List<ChatMessage>> listMessages(int chatId) async {
    final list = await _api.getList('/api/v1/chats/$chatId/messages');
    return list.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<ChatTurn> sendMessage({required int chatId, required String content}) async {
    final json = await _api.post('/api/v1/chats/$chatId/message', {'content': content});
    return ChatTurn.fromJson(json);
  }
}
