import '../models/denuncia_model.dart';
import '../settings/api_connection.dart';

class DenunciasRepository {
  final api = ApiConnection();

  // GET /api/denuncias/mias/
  Future<List<DenunciaModel>> getMias() async {
    final res = await api.get("api/denuncias/mias/");
    if (res is List) {
      return res
          .map((e) => DenunciaModel.fromMap(e as Map<String, dynamic>))
          .toList();
    }

    // por si tu backend devuelve {results:[...]}
    if (res is Map && res['results'] is List) {
      final list = (res['results'] as List);
      return list
          .map((e) => DenunciaModel.fromMap(e as Map<String, dynamic>))
          .toList();
    }

    throw Exception("Formato inesperado en /api/denuncias/mias/");
  }

  // =========================
  // DENUNCIAS (finales)
  // =========================

  // GET /api/denuncias/mias/
  Future<List<Map<String, dynamic>>> getMiasRaw() async {
    final res = await api.get("api/denuncias/mias/");
    if (res is List) {
      return res.cast<Map<String, dynamic>>();
    }
    throw Exception("Formato inesperado en /api/denuncias/mias/");
  }

  // POST /api/denuncias/  (directo, sin borrador)
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
}
