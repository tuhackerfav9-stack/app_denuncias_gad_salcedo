import 'dart:convert';
import 'package:http/http.dart' as http;
import 'session.dart';

import 'dart:io';

import 'package:http_parser/http_parser.dart';

class ApiConnection {
  static final ApiConnection instance = ApiConnection._internal();
  factory ApiConnection() => instance;
  ApiConnection._internal();

  //  CAMBIA SOLO LA IP SI HACE FALTA
  final String baseUrl = "http://192.168.100.46:8000/";
  //final String baseUrl = "http://172.16.117.196:8000/";

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
  // REFRESH TOKEN
  // =============================
  Future<bool> _refreshToken() async {
    final refresh = await Session.refresh();
    if (refresh == null || refresh.isEmpty) return false;

    final url = Uri.parse("${baseUrl}api/auth/refresh/");
    final resp = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"refresh": refresh}),
    );

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      await Session.updateAccess(data["access"]);

      if (data["refresh"] != null) {
        await Session.updateRefresh(data["refresh"]);
      }
      return true;
    }

    return false;
  }

  // =============================
  // REQUEST BASE (AUTO REFRESH)
  // =============================
  Future<http.Response> _request(Future<http.Response> Function() call) async {
    http.Response response = await call();

    if (response.statusCode == 401) {
      final refreshed = await _refreshToken();
      if (refreshed) {
        response = await call(); // reintento
      }
    }

    return response;
  }

  // =============================
  // GET
  // =============================
  Future<dynamic> get(String endpoint, {bool auth = true}) async {
    final url = Uri.parse("$baseUrl$endpoint");

    final resp = await _request(() async {
      return await http.get(url, headers: await _headers(auth: auth));
    });

    if (resp.statusCode != 200) {
      throw Exception("GET error ${resp.statusCode}: ${resp.body}");
    }

    return jsonDecode(resp.body);
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
    });

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception("POST error ${resp.statusCode}: ${resp.body}");
    }

    return jsonDecode(resp.body);
  }

  // =============================
  // PATCH
  // =============================
  Future<dynamic> patch(String endpoint, Map<String, dynamic> data) async {
    final url = Uri.parse("$baseUrl$endpoint");

    final resp = await _request(() async {
      return await http.patch(
        url,
        headers: await _headers(),
        body: jsonEncode(data),
      );
    });

    if (resp.statusCode != 200) {
      throw Exception("PATCH error ${resp.statusCode}: ${resp.body}");
    }

    return jsonDecode(resp.body);
  }

  // =============================
  // DELETE
  // =============================
  Future<void> delete(String endpoint) async {
    final url = Uri.parse("$baseUrl$endpoint");

    final resp = await _request(() async {
      return await http.delete(url, headers: await _headers());
    });

    if (resp.statusCode != 200 && resp.statusCode != 204) {
      throw Exception("DELETE error ${resp.statusCode}: ${resp.body}");
    }
  }

  // =============================
  // put actualuzar
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
    });

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception("PUT error ${resp.statusCode}: ${resp.body}");
    }

    return jsonDecode(resp.body);
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

    // MultipartRequest maneja headers aparte, NO uses Content-Type json
    final req = http.MultipartRequest("POST", url);

    // headers
    final headers = <String, String>{"Accept": "application/json"};

    if (auth) {
      final token = await Session.access();
      if (token != null && token.isNotEmpty) {
        headers["Authorization"] = "Bearer $token";
      }
    }

    req.headers.addAll(headers);

    // fields
    if (fields != null) {
      req.fields.addAll(fields);
    }

    // files
    req.files.addAll(files);

    // enviar
    http.StreamedResponse streamed = await req.send().timeout(
      const Duration(seconds: 60),
    );

    final resp = await http.Response.fromStream(streamed);

    // refresh si 401 (no aplica a register normalmente, pero lo dejamos pro)
    if (resp.statusCode == 401 && auth) {
      final refreshed = await _refreshToken();
      if (refreshed) {
        // reintento con token nuevo
        final req2 = http.MultipartRequest("POST", url);
        final headers2 = <String, String>{"Accept": "application/json"};

        final token2 = await Session.access();
        if (token2 != null && token2.isNotEmpty) {
          headers2["Authorization"] = "Bearer $token2";
        }
        req2.headers.addAll(headers2);

        if (fields != null) req2.fields.addAll(fields);
        req2.files.addAll(files);

        final streamed2 = await req2.send().timeout(
          const Duration(seconds: 60),
        );
        final resp2 = await http.Response.fromStream(streamed2);

        if (resp2.statusCode < 200 || resp2.statusCode >= 300) {
          throw Exception("MULTIPART error ${resp2.statusCode}: ${resp2.body}");
        }
        return _safeJson(resp2.body);
      }
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception("MULTIPART error ${resp.statusCode}: ${resp.body}");
    }

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

    // detecta mime básico por extensión
    final lower = filename.toLowerCase();
    MediaType contentType = MediaType("application", "octet-stream");
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
