import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../models/denuncia_model.dart';
import '../settings/api_connection.dart';
import '../settings/session.dart';
import 'package:http_parser/http_parser.dart' as http_parser;

class DenunciasRepository {
  final api = ApiConnection();

  // IMPORTANTE:
  // - ApiConnection.baseUrl = "http://192.168.100.46:8000/"
  // - Para multipart usamos baseUrl sin duplicar slashes
  final String baseUrl = "http://192.168.100.46:8000";

  // =========================
  // TOKEN
  // =========================
  Future<String> _accessToken() async {
    final t = await Session.access();
    if (t == null || t.isEmpty) throw Exception("No hay access token");
    return t;
  }

  // Refresh manual (para multipart)
  Future<bool> _refreshToken() async {
    final refresh = await Session.refresh();
    if (refresh == null || refresh.isEmpty) return false;

    final url = Uri.parse("$baseUrl/api/auth/refresh/");
    final resp = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"refresh": refresh}),
    );

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      final newAccess = (data["access"] ?? "").toString();
      if (newAccess.isNotEmpty) {
        await Session.updateAccess(newAccess);
      }
      final newRefresh = data["refresh"];
      if (newRefresh != null && newRefresh.toString().isNotEmpty) {
        await Session.updateRefresh(newRefresh.toString());
      }
      return true;
    }

    return false;
  }

  // =========================
  // MULTIPART HELPERS
  // =========================
  Future<Map<String, dynamic>> _sendMultipartAndParse(
    http.MultipartRequest req,
  ) async {
    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();

    // Si token expira, intentamos refrescar y reintentar 1 vez
    if (streamed.statusCode == 401) {
      final refreshed = await _refreshToken();
      if (!refreshed) {
        throw Exception("401 no autorizado (refresh falló): $body");
      }

      // Reintento con nuevo token (toca rehacer request)
      // Como MultipartRequest no se puede re-enviar fácil con mismos streams,
      // este helper se usa solo desde métodos que pueden recrear request.
      throw _RetryMultipartException();
    }

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception("Error ${streamed.statusCode}: $body");
    }

    final decoded = jsonDecode(body);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw Exception("Respuesta inesperada (no es JSON Map): $body");
  }

  // =========================
  // SUBIR EVIDENCIA (foto/video)
  // POST /api/denuncias/borradores/<id>/evidencias/
  // form-data:
  //   - archivo: file
  //   - tipo: "foto" | "video"
  // =========================
  Future<Map<String, dynamic>> subirEvidenciaBorrador({
    required String borradorId,
    required File archivo,
    required String tipo,
  }) async {
    Future<Map<String, dynamic>> attempt() async {
      final token = await _accessToken();

      final uri = Uri.parse(
        "$baseUrl/api/denuncias/borradores/$borradorId/evidencias/",
      );

      final req = http.MultipartRequest("POST", uri);
      req.headers["Authorization"] = "Bearer $token";
      req.fields["tipo"] = tipo;

      req.files.add(
        await http.MultipartFile.fromPath(
          "archivo", // <- CLAVE EXACTA QUE ESPERA BACKEND
          archivo.path,
          filename: archivo.path.split('/').last,
        ),
      );

      return await _sendMultipartAndParse(req);
    }

    try {
      return await attempt();
    } on _RetryMultipartException {
      // refrescó token, reintenta una vez
      return await attempt();
    }
  }

  // =========================
  // SUBIR FIRMA (PNG)
  // POST /api/denuncias/borradores/<id>/firma/
  // form-data:
  //   - archivo: file (firma.png)
  // =========================
  Future<Map<String, dynamic>> subirFirmaBorrador({
    required String borradorId,
    required List<int> pngBytes,
  }) async {
    Future<Map<String, dynamic>> attempt() async {
      final token = await _accessToken();

      final uri = Uri.parse(
        "$baseUrl/api/denuncias/borradores/$borradorId/firma/",
      );

      final req = http.MultipartRequest("POST", uri);
      req.headers["Authorization"] = "Bearer $token";

      req.files.add(
        http.MultipartFile.fromBytes(
          "firma", // ESTA ES LA CLAVE QUE ESPERA EL BACKEND
          pngBytes,
          filename: "firma.png",
          contentType: http_parser.MediaType("image", "png"),
        ),
      );

      return await _sendMultipartAndParse(req);
    }

    try {
      return await attempt();
    } on _RetryMultipartException {
      return await attempt();
    }
  }

  // =========================
  // GET /api/denuncias/mias/
  // =========================
  Future<List<DenunciaModel>> getMias() async {
    final res = await api.get("api/denuncias/mias/");
    if (res is List) {
      return res
          .map((e) => DenunciaModel.fromMap(e as Map<String, dynamic>))
          .toList();
    }
    if (res is Map && res['results'] is List) {
      final list = (res['results'] as List);
      return list
          .map((e) => DenunciaModel.fromMap(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception("Formato inesperado en /api/denuncias/mias/");
  }

  // GET raw
  Future<List<Map<String, dynamic>>> getMiasRaw() async {
    final res = await api.get("api/denuncias/mias/");
    if (res is List) return res.cast<Map<String, dynamic>>();
    throw Exception("Formato inesperado en /api/denuncias/mias/");
  }

  // =========================
  // DENUNCIA DIRECTA
  // POST /api/denuncias/
  // =========================
  Future<Map<String, dynamic>> crearDenunciaDirecta({
    required int tipoDenunciaId,
    required String descripcion,
    required double latitud,
    required double longitud,
    String? referencia,
    String? direccionTexto,
    String origen = "formulario",
  }) async {
    final body = {
      "tipo_denuncia_id": tipoDenunciaId,
      "descripcion": descripcion,
      "latitud": latitud,
      "longitud": longitud,
      "referencia": referencia,
      "direccion_texto": direccionTexto,
      "origen": origen,
    };

    final res = await api.post("api/denuncias/", body);
    if (res is Map) return Map<String, dynamic>.from(res);
    throw Exception("Formato inesperado en /api/denuncias/");
  }

  // =========================
  // BORRADORES
  // =========================

  // POST /api/denuncias/borradores/
  Future<Map<String, dynamic>> crearBorrador({
    required int tipoDenunciaId,
    required String descripcion,
    required double latitud,
    required double longitud,
    String? referencia,
    String? direccionTexto,
    String origen = "formulario",
  }) async {
    final body = {
      "tipo_denuncia_id": tipoDenunciaId,
      "descripcion": descripcion,
      "latitud": latitud,
      "longitud": longitud,
      "referencia": referencia,
      "direccion_texto": direccionTexto,
      "origen": origen,
    };

    final res = await api.post("api/denuncias/borradores/", body);
    if (res is Map) return Map<String, dynamic>.from(res);
    throw Exception("Formato inesperado en /api/denuncias/borradores/");
  }

  // PUT /api/denuncias/borradores/<id>/
  Future<Map<String, dynamic>> actualizarBorrador({
    required String borradorId,
    int? tipoDenunciaId,
    String? descripcion,
    double? latitud,
    double? longitud,
    String? referencia,
    String? direccionTexto,
  }) async {
    final body = <String, dynamic>{};
    if (tipoDenunciaId != null) body["tipo_denuncia_id"] = tipoDenunciaId;
    if (descripcion != null) body["descripcion"] = descripcion;
    if (latitud != null) body["latitud"] = latitud;
    if (longitud != null) body["longitud"] = longitud;
    if (referencia != null) body["referencia"] = referencia;
    if (direccionTexto != null) body["direccion_texto"] = direccionTexto;

    final res = await api.put("api/denuncias/borradores/$borradorId/", body);
    if (res is Map) return Map<String, dynamic>.from(res);
    throw Exception("Formato inesperado en PUT borrador");
  }

  // DELETE /api/denuncias/borradores/<id>/
  Future<void> eliminarBorrador(String borradorId) async {
    await api.delete("api/denuncias/borradores/$borradorId/");
  }

  // GET /api/denuncias/borradores/mios/
  Future<Map<String, dynamic>> getBorradoresMios() async {
    final res = await api.get("api/denuncias/borradores/mios/");
    if (res is Map) return Map<String, dynamic>.from(res);
    throw Exception("Formato inesperado en /api/denuncias/borradores/mios/");
  }

  // POST /api/denuncias/borradores/<id>/finalizar/
  Future<Map<String, dynamic>> finalizarBorrador(String borradorId) async {
    final res = await api.post(
      "api/denuncias/borradores/$borradorId/finalizar/",
      {},
    );
    if (res is Map) return Map<String, dynamic>.from(res);
    throw Exception("Formato inesperado en finalizar borrador");
  }

  //----------mapa------------
  Future<Map<String, dynamic>> getMapa({
    double? lat,
    double? lng,
    double radioKm = 2,
    bool soloHoy = false,
    bool soloMias = true,
    int? tipoDenunciaId,
    String? q,
  }) async {
    final params = <String, String>{
      "radio_km": radioKm.toString(),
      "solo_hoy": soloHoy ? "true" : "false",
      "solo_mias": soloMias ? "true" : "false",
    };

    if (lat != null && lng != null) {
      params["lat"] = lat.toString();
      params["lng"] = lng.toString();
    }
    if (tipoDenunciaId != null) params["tipo_denuncia_id"] = "$tipoDenunciaId";
    if (q != null && q.trim().isNotEmpty) params["q"] = q.trim();

    final query = params.entries
        .map((e) => "${e.key}=${Uri.encodeComponent(e.value)}")
        .join("&");
    final path = "api/denuncias/mapa/?$query";

    final res = await api.get(path);
    if (res is Map) return Map<String, dynamic>.from(res);
    throw Exception("Formato inesperado en /api/denuncias/mapa/");
  }

  //----------descargas
  Future<Map<String, dynamic>> getDetalleDenuncia(String denunciaId) async {
    final res = await api.get("api/denuncias/$denunciaId/detalle/");
    if (res is Map) return Map<String, dynamic>.from(res);
    throw Exception("Formato inesperado en detalle denuncia");
  }
}

// excepción interna para reintento de multipart tras refresh
class _RetryMultipartException implements Exception {}
