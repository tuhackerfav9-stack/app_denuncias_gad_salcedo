import '../settings/api_connection.dart';
import '../models/perfil_model.dart';

class PerfilRepository {
  final api = ApiConnection();

  // GET /api/auth/perfil/
  Future<PerfilModel> getPerfil() async {
    final res = await api.get("api/auth/perfil/", auth: true);
    if (res is Map<String, dynamic>) {
      return PerfilModel.fromMap(res);
    }
    throw Exception("Formato inesperado en /api/auth/perfil/");
  }

  // PATCH /api/auth/perfil/
  // Solo manda campos editables que vengan != null
  Future<void> updatePerfilPatch({
    String? nombres,
    String? apellidos,
    String? telefono,
    DateTime? fechaNacimiento,
  }) async {
    final body = <String, dynamic>{};

    if (nombres != null) body["nombres"] = nombres;
    if (apellidos != null) body["apellidos"] = apellidos;
    if (telefono != null) body["telefono"] = telefono;

    if (fechaNacimiento != null) {
      final yyyy = fechaNacimiento.year.toString().padLeft(4, '0');
      final mm = fechaNacimiento.month.toString().padLeft(2, '0');
      final dd = fechaNacimiento.day.toString().padLeft(2, '0');
      body["fecha_nacimiento"] = "$yyyy-$mm-$dd";
    }

    if (body.isEmpty) return; // nada que actualizar

    final res = await api.patch("api/auth/perfil/", body);
    // res normalmente: {"detail": "Perfil actualizado"}
    if (res is! Map) {
      throw Exception("Respuesta inesperada en PATCH perfil");
    }
  }

  // POST /api/auth/password/change/
  Future<void> changePassword({
    required String actual,
    required String nueva,
    required String confirmar,
  }) async {
    final res = await api.post("api/auth/password/change/", {
      "password_actual": actual,
      "password_nueva": nueva,
      "password_confirmar": confirmar,
    }, auth: true);

    if (res is! Map) {
      throw Exception("Respuesta inesperada en cambio de contraseña");
    }
  }
}
