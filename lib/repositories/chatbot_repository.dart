import '../settings/api_connection.dart';

class ChatbotRepository {
  final api = ApiConnection();

  Future<Map<String, dynamic>> startChat() async {
    final data = await api.post("/api/chatbot/start/", {}, auth: true);
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> sendMessage({
    required String conversacionId,
    required String mensaje,
  }) async {
    final data = await api.post("/api/chatbot/message/", {
      "conversacion_id": conversacionId,
      "mensaje": mensaje,
    }, auth: true);
    return Map<String, dynamic>.from(data);
  }
}
