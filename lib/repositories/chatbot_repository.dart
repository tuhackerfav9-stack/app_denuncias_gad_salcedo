import 'dart:io';

import '../settings/api_connection.dart';
import 'denuncias_repository.dart';

class ChatbotRepository {
  final api = ApiConnection();
  final DenunciasRepository denunciasRepo = DenunciasRepository();

  // POST /api/chatbot/start/
  Future<Map<String, dynamic>> start() async {
    final res = await api.post("api/chatbot/start/", {}, auth: true);
    if (res is Map) return Map<String, dynamic>.from(res);
    throw Exception("Formato inesperado en chatbot/start");
  }

  // POST /api/chatbot/message/
  Future<Map<String, dynamic>> sendMessage({
    required String conversacionId,
    required String mensaje,
  }) async {
    final res = await api.post("api/chatbot/message/", {
      "conversacion_id": conversacionId,
      "mensaje": mensaje,
    }, auth: true);
    if (res is Map) return Map<String, dynamic>.from(res);
    throw Exception("Formato inesperado en chatbot/message");
  }

  // Evidencia -> reusa DenunciasRepository (multipart)
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

  // Firma -> reusa DenunciasRepository (multipart)
  Future<Map<String, dynamic>> subirFirma({
    required String borradorId,
    required List<int> pngBytes,
  }) async {
    return await denunciasRepo.subirFirmaBorrador(
      borradorId: borradorId,
      pngBytes: pngBytes,
    );
  }

  Future<Map<String, dynamic>> finalizarBorrador({
    required String borradorId,
  }) async {
    return await denunciasRepo.finalizarBorrador(borradorId);
  }
}
