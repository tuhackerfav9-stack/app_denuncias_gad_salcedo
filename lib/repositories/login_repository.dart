import '../settings/api_connection.dart';
import '../settings/session.dart';

class LoginRepository {
  final ApiConnection _api = ApiConnection();

  Future<void> login({required String correo, required String password}) async {
    final response = await _api.post(
      "api/auth/login/",
      {"correo": correo.trim().toLowerCase(), "password": password},
      auth: false, //  LOGIN NO usa Bearer
    );

    // Validación defensiva
    if (response["access"] == null || response["refresh"] == null) {
      throw Exception("Respuesta inválida del servidor");
    }

    final usuario = response["usuario"];
    final access = response["access"] as String; // ✅ aquí
    final refresh = response["refresh"] as String; // ✅ aquí

    await Session.saveLogin(
      access: access,
      refresh: refresh,
      //access: response["access"],
      //refresh: response["refresh"],
      email: usuario["correo"],
      userId: usuario["id"],
      tipo: usuario["tipo"],
    );
    await Session.updateAccess(access);
  }
}
