import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiConnection {
  static final ApiConnection instance = ApiConnection._internal();
  factory ApiConnection() => instance;
  ApiConnection._internal();

  //  CAMBIA la IP segun donde corra API de django
  final String baseUrl = "http://192.168.100.46:8000";

  String? _access;
  String? _refresh;

  // ========= AUTH =========
  Future<void> login(String correo, String password) async {
    final url = Uri.parse("$baseUrl/api/auth/login/");
    final resp = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"correo": correo, "password": password}),
    );

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception("Login error: ${resp.body}");
    }

    final data = jsonDecode(resp.body);
    _access = data["access"];
    _refresh = data["refresh"];
  }

  Future<void> refreshToken() async {
    if (_refresh == null) throw Exception("No refresh token guardado");

    final url = Uri.parse("$baseUrl/api/auth/refresh/");
    final resp = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"refresh": _refresh}),
    );

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception("Refresh error: ${resp.body}");
    }

    final data = jsonDecode(resp.body);
    _access = data["access"];
    if (data["refresh"] != null) _refresh = data["refresh"];
  }

  Map<String, String> _headers({bool auth = false}) {
    final h = {"Content-Type": "application/json"};
    if (auth && _access != null) {
      h["Authorization"] = "Bearer $_access";
    }
    return h;
  }

  // ========= REQUEST WRAPPER =========
  Future<http.Response> _requestWithAutoRefresh(
    Future<http.Response> Function() requestFn,
  ) async {
    http.Response resp = await requestFn();

    // si expira, refresca y reintenta 1 vez
    if (resp.statusCode == 401) {
      await refreshToken();
      resp = await requestFn();
    }
    return resp;
  }

  // ========= GET =========
  Future<dynamic> get(String path, {bool auth = false}) async {
    final url = Uri.parse("$baseUrl$path");

    final resp = await _requestWithAutoRefresh(() {
      return http.get(url, headers: _headers(auth: auth));
    });

    if (resp.statusCode != 200) {
      throw Exception("GET error ${resp.statusCode}: ${resp.body}");
    }
    return jsonDecode(resp.body);
  }

  // ========= POST =========
  Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    final url = Uri.parse("$baseUrl$path");

    final resp = await _requestWithAutoRefresh(() {
      return http.post(
        url,
        headers: _headers(auth: auth),
        body: jsonEncode(body),
      );
    });

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception("POST error ${resp.statusCode}: ${resp.body}");
    }
    return jsonDecode(resp.body);
  }
}
