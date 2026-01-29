import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'session.dart';
import 'api_exception.dart';

import '../app_navigator.dart';

class ApiConnection {
  static final ApiConnection instance = ApiConnection._internal();
  factory ApiConnection() => instance;
  ApiConnection._internal();

  // CAMBIA SOLO LA IP SI HACE FALTA
  final String baseUrl = "http://192.168.100.46:8000/";

  // Timeouts (para que NO se quede cargando)
  static const Duration _timeout = Duration(seconds: 25);

  // Lock para evitar refresh simultáneo
  Future<bool>? _refreshing;

  // =============================
  // HEADERS CON TOKEN
  // =============================
  Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
    };

    if (auth) {
      final token = await Session.access();
      if (token != null && token.isNotEmpty) {
        headers["Authorization"] = "Bearer $token";
      }
    }
    return headers;
  }

  // =============================
  // EXTRAER MENSAJE HUMANO
  // =============================
  String _extractMessage(String body) {
    final b = body.trim();
    if (b.isEmpty) return "Ocurrió un error inesperado.";
    try {
      final j = jsonDecode(b);
      if (j is Map) {
        return (j["detail"] ??
                j["error"] ??
                j["message"] ??
                j["mensaje"] ??
                "Ocurrió un error inesperado.")
            .toString();
      }
      return "Ocurrió un error inesperado.";
    } catch (_) {
      // si no es JSON, devuelve un resumen corto
      return b.length > 120 ? "${b.substring(0, 120)}..." : b;
    }
  }

  // =============================
  // REFRESH TOKEN (con lock)
  // =============================
  Future<bool> _refreshTokenLocked() async {
    // si ya hay refresh en progreso, espera ese mismo
    _refreshing ??= _refreshToken();
    final ok = await _refreshing!;
    _refreshing = null;
    return ok;
  }

  Future<bool> _refreshToken() async {
    final refresh = await Session.refresh();
    if (refresh == null || refresh.isEmpty) return false;

    final url = Uri.parse("${baseUrl}api/auth/refresh/");
    try {
      final resp = await http
          .post(
            url,
            headers: {
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: jsonEncode({"refresh": refresh}),
          )
          .timeout(_timeout);

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final newAccess = (data["access"] ?? "").toString();
        if (newAccess.isEmpty) return false;

        await Session.updateAccess(newAccess);

        if (data["refresh"] != null) {
          await Session.updateRefresh(data["refresh"].toString());
        }
        return true;
      }
      return false;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  // =============================
  // REQUEST BASE (AUTO REFRESH + ERROR MAP)
  // =============================
  Future<http.Response> _request(
    Future<http.Response> Function() call, {
    bool auth = true,
  }) async {
    try {
      http.Response response = await call().timeout(_timeout);

      // 401 -> refresh -> retry
      if (response.statusCode == 401 && auth) {
        final refreshed = await _refreshTokenLocked();
        if (refreshed) {
          response = await call().timeout(_timeout);
        } else {
          // sesión muerta
          await Session.clear();
          AppNavigator.goLogin();
          throw ApiException(
            type: ApiErrorType.unauthorized,
            statusCode: 401,
            message: "Tu sesión expiró. Inicia sesión nuevamente.",
            raw: _safeJson(response.body),
          );
        }
      }

      // Mapear errores
      if (response.statusCode == 403) {
        throw ApiException(
          type: ApiErrorType.forbidden,
          statusCode: 403,
          message: "No autorizado. No tienes permisos para esta acción.",
          raw: _safeJson(response.body),
        );
      }

      if (response.statusCode >= 500) {
        throw ApiException(
          type: ApiErrorType.server,
          statusCode: response.statusCode,
          message: "Error del servidor. Intenta nuevamente en unos minutos.",
          raw: _safeJson(response.body),
        );
      }

      // Otros errores 4xx
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          type: ApiErrorType.unknown,
          statusCode: response.statusCode,
          message: _extractMessage(response.body),
          raw: _safeJson(response.body),
        );
      }

      return response;
    } on SocketException {
      throw ApiException(
        type: ApiErrorType.network,
        message: "Sin conexión a internet. Revisa tu red e intenta otra vez.",
      );
    } on TimeoutException {
      throw ApiException(
        type: ApiErrorType.timeout,
        message: "La solicitud tardó demasiado. Reintenta.",
      );
    }
  }

  // =============================
  // GET
  // =============================
  Future<dynamic> get(String endpoint, {bool auth = true}) async {
    final url = Uri.parse("$baseUrl$endpoint");

    final resp = await _request(() async {
      return await http.get(url, headers: await _headers(auth: auth));
    }, auth: auth);

    return _safeJson(resp.body);
  }

  // =============================
  // POST
  // =============================
  Future<dynamic> post(
    String endpoint,
    Map<String, dynamic> data, {
    bool auth = true,
  }) async {
    final url = Uri.parse("$baseUrl$endpoint");

    final resp = await _request(() async {
      return await http.post(
        url,
        headers: await _headers(auth: auth),
        body: jsonEncode(data),
      );
    }, auth: auth);

    return _safeJson(resp.body);
  }

  // =============================
  // PATCH
  // =============================
  Future<dynamic> patch(
    String endpoint,
    Map<String, dynamic> data, {
    bool auth = true,
  }) async {
    final url = Uri.parse("$baseUrl$endpoint");

    final resp = await _request(() async {
      return await http.patch(
        url,
        headers: await _headers(auth: auth),
        body: jsonEncode(data),
      );
    }, auth: auth);

    return _safeJson(resp.body);
  }

  // =============================
  // PUT
  // =============================
  Future<dynamic> put(
    String endpoint,
    Map<String, dynamic> data, {
    bool auth = true,
  }) async {
    final url = Uri.parse("$baseUrl$endpoint");

    final resp = await _request(() async {
      return await http.put(
        url,
        headers: await _headers(auth: auth),
        body: jsonEncode(data),
      );
    }, auth: auth);

    return _safeJson(resp.body);
  }

  // =============================
  // DELETE
  // =============================
  Future<void> delete(String endpoint, {bool auth = true}) async {
    final url = Uri.parse("$baseUrl$endpoint");

    await _request(() async {
      return await http.delete(url, headers: await _headers(auth: auth));
    }, auth: auth);
  }

  // =============================
  // MULTIPART POST (archivos)
  // =============================
  Future<dynamic> multipartPost(
    String endpoint, {
    Map<String, String>? fields,
    required List<http.MultipartFile> files,
    bool auth = true,
  }) async {
    final url = Uri.parse("$baseUrl$endpoint");

    Future<http.Response> sendOnce() async {
      final req = http.MultipartRequest("POST", url);

      final headers = <String, String>{"Accept": "application/json"};
      if (auth) {
        final token = await Session.access();
        if (token != null && token.isNotEmpty) {
          headers["Authorization"] = "Bearer $token";
        }
      }
      req.headers.addAll(headers);

      if (fields != null) req.fields.addAll(fields);
      req.files.addAll(files);

      final streamed = await req.send().timeout(const Duration(seconds: 60));
      return http.Response.fromStream(streamed);
    }

    http.Response resp = await _request(() => sendOnce(), auth: auth);

    // Si aquí pasó, ya es 2xx
    return _safeJson(resp.body);
  }

  // =============================
  // helper: json seguro
  // =============================
  dynamic _safeJson(String body) {
    final b = body.trim();
    if (b.isEmpty) return {};
    try {
      return jsonDecode(b);
    } catch (_) {
      return {"raw": body};
    }
  }

  // =============================
  // helper: crear MultipartFile desde File
  // =============================
  Future<http.MultipartFile> filePart({
    required String fieldName,
    required File file,
  }) async {
    final filename = file.path.split(Platform.pathSeparator).last;

    MediaType contentType = MediaType("application", "octet-stream");
    final lower = filename.toLowerCase();
    if (lower.endsWith(".jpg") || lower.endsWith(".jpeg")) {
      contentType = MediaType("image", "jpeg");
    } else if (lower.endsWith(".png")) {
      contentType = MediaType("image", "png");
    } else if (lower.endsWith(".pdf")) {
      contentType = MediaType("application", "pdf");
    }

    return http.MultipartFile.fromBytes(
      fieldName,
      await file.readAsBytes(),
      filename: filename,
      contentType: contentType,
    );
  }
}
