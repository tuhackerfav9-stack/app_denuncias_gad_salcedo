class PerfilModel {
  final String uid;
  final String correo;
  final String nombres;
  final String apellidos;
  final String telefono;
  final String? cedula;
  final DateTime? fechaNacimiento;

  PerfilModel({
    required this.uid,
    required this.correo,
    required this.nombres,
    required this.apellidos,
    required this.telefono,
    this.cedula,
    this.fechaNacimiento,
  });

  factory PerfilModel.fromMap(Map<String, dynamic> json) {
    DateTime? fn;
    final raw = json["fecha_nacimiento"];
    if (raw != null) {
      final s = raw.toString();
      if (s.isNotEmpty) fn = DateTime.tryParse(s);
    }

    return PerfilModel(
      uid: (json["uid"] ?? "").toString(),
      correo: (json["correo"] ?? "").toString(),
      nombres: (json["nombres"] ?? "").toString(),
      apellidos: (json["apellidos"] ?? "").toString(),
      telefono: (json["telefono"] ?? "").toString(),
      cedula: json["cedula"]?.toString(),
      fechaNacimiento: fn,
    );
  }
}
