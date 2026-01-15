import '../settings/api_connection.dart';

class PasswordResetRepository {
  final api = ApiConnection.instance;

  // Paso 1: validar cedula+correo y crear token -> devuelve reset_id
  Future<Map<String, dynamic>> enviarCodigo({
    required String cedula,
    required String correo,
  }) async {
    final res = await api.post("api/auth/password-reset/paso1/enviar-codigo/", {
      "cedula": cedula.trim(),
      "correo": correo.trim().toLowerCase(),
    }, auth: false);

    return Map<String, dynamic>.from(res as Map);
  }

  // Paso 2: verificar código
  Future<void> verificarCodigo({
    required String resetId,
    required String codigo6,
  }) async {
    await api.post("api/auth/password-reset/paso2/verificar-codigo/", {
      "reset_id": resetId.trim(),
      "codigo": codigo6.trim(),
    }, auth: false);
  }

  // Paso 3: cambiar contraseña
  Future<Map<String, dynamic>> cambiarPassword({
    required String resetId,
    required String password,
    required String password2,
  }) async {
    final res = await api
        .post("api/auth/password-reset/paso3/cambiar-password/", {
          "reset_id": resetId.trim(),
          "password": password.trim(),
          "password2": password2.trim(),
        }, auth: false);

    return Map<String, dynamic>.from(res as Map);
  }
}
