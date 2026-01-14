import 'dart:convert';
import 'package:http/http.dart' as http;
import 'session.dart';

class ApiConnection {
  static final ApiConnection instance = ApiConnection._internal();
  factory ApiConnection() => instance;
  ApiConnection._internal();

  //  CAMBIA SOLO LA IP SI HACE FALTA
  final String baseUrl = "http://192.168.100.46:8000/";

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
}
