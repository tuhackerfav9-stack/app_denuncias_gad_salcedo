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
}
