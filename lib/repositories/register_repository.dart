import 'dart:io';

import '../settings/api_connection.dart';

class RegisterRepository {
  final api = ApiConnection.instance;

  // Paso 1: datos base -> devuelve uid (borrador)
  Future<String> paso1({
    required String cedula,
    required String nombres,
    required String apellidos,
    String? telefono,
  }) async {
    final res = await api.post("api/auth/register/paso1/", {
      "cedula": cedula.trim(),
      "nombres": nombres.trim(),
      "apellidos": apellidos.trim(),
      "telefono": (telefono ?? "").trim().isEmpty ? null : telefono!.trim(),
    }, auth: false);

    final uid = (res["uid"] ?? "").toString();
    if (uid.isEmpty) {
      throw Exception("No se recibió uid del backend (paso1).");
    }
    return uid;
  }

  // Paso 2A: enviar código al correo
  // En dev, backend devuelve dev_codigo
  Future<Map<String, dynamic>> enviarCodigo({
    required String uid,
    required String correo,
  }) async {
    final res = await api.post("api/auth/register/paso2/enviar-codigo/", {
      "uid": uid.trim(),
      "correo": correo.trim().toLowerCase(),
    }, auth: false);

    // devuelve: detail, dev_codigo (dev), expira_en_min
    return Map<String, dynamic>.from(res as Map);
  }

  // Paso 2B: verificar código
  Future<void> verificarCodigo({
    required String uid,
    required String codigo6,
  }) async {
    await api.post("api/auth/register/paso2/verificar-codigo/", {
      "uid": uid.trim(),
      "codigo": codigo6.trim(),
    }, auth: false);
  }

  // Paso 3: guardar fecha (YYYY-MM-DD)
  Future<void> guardarFechaNacimiento({
    required String uid,
    required String fechaISO, // "YYYY-MM-DD"
  }) async {
    await api.post("api/auth/register/paso3/fecha/", {
      "uid": uid.trim(),
      "fecha_nacimiento": fechaISO.trim(),
    }, auth: false);
  }

  // Paso 4: subir cedula frontal/trasera (multipart)
  Future<Map<String, dynamic>> subirDocumentos({
    required String uid,
    required File cedulaFrontal,
    required File cedulaTrasera,
  }) async {
    final frontalPart = await api.filePart(
      fieldName: "cedula_frontal",
      file: cedulaFrontal,
    );

    final traseraPart = await api.filePart(
      fieldName: "cedula_trasera",
      file: cedulaTrasera,
    );

    final res = await api.multipartPost(
      "api/auth/register/paso4/documentos/",
      auth: false,
      fields: {"uid": uid.trim()},
      files: [frontalPart, traseraPart],
    );

    return Map<String, dynamic>.from(res as Map);
  }

  // Paso 5: finalizar (crea usuarios/ciudadanos/documentos)
  Future<Map<String, dynamic>> finalizar({
    required String uid,
    required String password,
  }) async {
    final res = await api.post("api/auth/register/paso5/finalizar/", {
      "uid": uid.trim(),
      "password": password.trim(),
    }, auth: false);

    return Map<String, dynamic>.from(res as Map);
  }
}
