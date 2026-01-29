class DenunciaModel {
  final String id;
  final int? tipoDenunciaId;
  final String? tipoDenunciaNombre;
  final String estado;
  final String descripcion;
  final double latitud;
  final double longitud;
  final String? referencia;
  final String? direccionTexto;
  final DateTime? createdAt;

  DenunciaModel({
    required this.id,
    required this.estado,
    required this.descripcion,
    required this.latitud,
    required this.longitud,
    this.tipoDenunciaId,
    this.tipoDenunciaNombre,
    this.referencia,
    this.direccionTexto,
    this.createdAt,
  });

  factory DenunciaModel.fromMap(Map<String, dynamic> json) {
    // Soporta 2 formatos:
    // 1) tipo_denuncia: 2
    // 2) tipo_denuncia: {id:2, nombre:"Basura"}
    final td = json['tipo_denuncia'];
    int? tdId;
    String? tdNombre;

    if (td is int) {
      tdId = td;
    } else if (td is Map<String, dynamic>) {
      tdId = td['id'] is int ? td['id'] : int.tryParse('${td['id']}');
      tdNombre = td['nombre']?.toString();
    } else {
      tdId = json['tipo_denuncia_id'] is int
          ? json['tipo_denuncia_id']
          : int.tryParse('${json['tipo_denuncia_id']}');
    }

    DateTime? created;
    final ca = json['created_at']?.toString();
    if (ca != null && ca.isNotEmpty) {
      created = DateTime.tryParse(ca);
    }

    return DenunciaModel(
      id: json['id'].toString(),
      tipoDenunciaId: tdId,
      tipoDenunciaNombre: tdNombre,
      estado: (json['estado'] ?? 'pendiente').toString(),
      descripcion: (json['descripcion'] ?? '').toString(),
      latitud: (json['latitud'] is num)
          ? (json['latitud'] as num).toDouble()
          : double.tryParse('${json['latitud']}') ?? 0.0,
      longitud: (json['longitud'] is num)
          ? (json['longitud'] as num).toDouble()
          : double.tryParse('${json['longitud']}') ?? 0.0,
      referencia: json['referencia']?.toString(),
      direccionTexto: json['direccion_texto']?.toString(),
      createdAt: created,
    );
  }
}
