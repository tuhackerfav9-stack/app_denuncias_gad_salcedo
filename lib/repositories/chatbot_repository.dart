import 'dart:io';

import '../settings/api_connection.dart';
import 'denuncias_repository.dart';

class ChatbotRepository {
  final ApiConnection api = ApiConnection();
  final DenunciasRepository denunciasRepo = DenunciasRepository();

  // ✅ V2 start
  Future<Map<String, dynamic>> startV2() async {
    final res = await api.post("api/chatbot/v2/start/", {}, auth: true);
    if (res is Map) return Map<String, dynamic>.from(res);
    throw Exception("Formato inesperado en chatbot/v2/start");
  }

  // ✅ V2 message (sync)
  Future<Map<String, dynamic>> syncV2({
    required String conversacionId,
    required String mensaje,
    String? botResponse, // respuesta Gemini
    Map<String, dynamic>? extracted, // opcional (si tú parseas algo en front)
  }) async {
    final body = <String, dynamic>{
      "conversacion_id": conversacionId,
      "mensaje": mensaje,
    };

    if (botResponse != null && botResponse.trim().isNotEmpty) {
      body["bot_response"] = botResponse.trim();
    }
    if (extracted != null && extracted.isNotEmpty) {
      body["extracted"] = extracted;
    }

    final res = await api.post("api/chatbot/v2/message/", body, auth: true);
    if (res is Map) return Map<String, dynamic>.from(res);
    throw Exception("Formato inesperado en chatbot/v2/message");
  }

  // ✅ Evidencia (multipart) -> reusa DenunciasRepository
  Future<Map<String, dynamic>> subirEvidencia({
    required String borradorId,
    required File archivo,
    required String tipo, // "foto" | "video"
  }) async {
    return await denunciasRepo.subirEvidenciaBorrador(
      borradorId: borradorId,
      archivo: archivo,
      tipo: tipo,
    );
  }

  // ✅ Firma (multipart) -> reusa DenunciasRepository
  Future<Map<String, dynamic>> subirFirma({
    required String borradorId,
    required List<int> pngBytes,
  }) async {
    return await denunciasRepo.subirFirmaBorrador(
      borradorId: borradorId,
      pngBytes: pngBytes,
    );
  }

  // ✅ Finalizar borrador -> reusa DenunciasRepository
  Future<Map<String, dynamic>> finalizarBorrador({
    required String borradorId,
  }) async {
    return await denunciasRepo.finalizarBorrador(borradorId);
  }

  //usarchatbotv2tipo

  Future<Map<String, dynamic>> tiposV2() async {
    final res = await api.get("api/chatbot/v2/tipos/", auth: true);
    if (res is Map) return Map<String, dynamic>.from(res);
    throw Exception("Formato inesperado en chatbot/v2/tipos");
  }
}
