import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;

class DenunciaPdfBuilder {
  static Future<Uint8List?> _loadNetworkImage(String? url) async {
    if (url == null || url.trim().isEmpty) return null;
    try {
      final r = await http.get(Uri.parse(url.trim()));
      if (r.statusCode >= 200 && r.statusCode < 300) {
        return r.bodyBytes;
      }
    } catch (_) {}
    return null;
  }

  static String _fmtFecha(dynamic v) {
    if (v == null) return "-";
    try {
      final dt = DateTime.tryParse(v.toString());
      if (dt == null) return v.toString();
      final local = dt.toLocal();
      return DateFormat("dd/MM/yyyy HH:mm").format(local);
    } catch (_) {
      return v.toString();
    }
  }

  static Future<Uint8List> build({
    required Map<String, dynamic> denuncia, // puedes pasar tu Map ya armado
  }) async {
    // ====== datos ======
    final tipo = (denuncia["tipo_denuncia_nombre"] ?? "Denuncia").toString();
    final descripcion = (denuncia["descripcion"] ?? "").toString();
    final estado = (denuncia["estado"] ?? "pendiente").toString();
    final referencia = (denuncia["referencia"] ?? "").toString();
    final direccionTexto = (denuncia["direccion_texto"] ?? "").toString();
    final lat = (denuncia["latitud"] ?? "").toString();
    final lng = (denuncia["longitud"] ?? "").toString();
    final fecha = _fmtFecha(denuncia["created_at"]);

    // Datos del ciudadano (ideal: que tu backend los mande o los consultes antes)
    final nombres = (denuncia["ciudadano_nombres"] ?? "").toString();
    final apellidos = (denuncia["ciudadano_apellidos"] ?? "").toString();
    final cedula = (denuncia["ciudadano_cedula"] ?? "").toString();

    // Firma URL
    final firmaUrl = (denuncia["firma_url"] ?? "").toString();
    final firmaBytes = await _loadNetworkImage(firmaUrl);

    // Logo asset
    final logoData = await rootBundle.load("assets/login.png");
    final logo = pw.MemoryImage(logoData.buffer.asUint8List());

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          // ===== Encabezado =====
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 70,
                height: 70,
                child: pw.Image(logo, fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "GAD MUNICIPAL DE SALCEDO",
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text("ANEXO A", style: const pw.TextStyle(fontSize: 11)),
                    pw.SizedBox(height: 6),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 10,
                      ),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(width: 1),
                      ),
                      child: pw.Text(
                        "FORMATO DE DENUNCIA",
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    "Fecha: $fecha",
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.Text(
                    "Estado: $estado",
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 16),

          // ===== Cuerpo tipo redacción general =====
          pw.Text(
            "Ciudad de Salcedo, a los ____ días del mes de __________ de ____.",
            style: const pw.TextStyle(fontSize: 11),
          ),
          pw.SizedBox(height: 10),

          pw.Text(
            "Yo, $nombres $apellidos, identificado/a con cédula N.° $cedula, "
            "me presento ante usted con la finalidad de dejar constancia de una denuncia "
            "relacionada con el siguiente hecho:",
            style: const pw.TextStyle(fontSize: 11),
          ),
          pw.SizedBox(height: 10),

          pw.Text(
            "1. Tipo de denuncia:",
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(tipo, style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 8),

          pw.Text(
            "2. Descripción de los hechos:",
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            descripcion.isEmpty ? "-" : descripcion,
            style: const pw.TextStyle(fontSize: 11),
          ),
          pw.SizedBox(height: 8),

          pw.Text(
            "3. Ubicación:",
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            (direccionTexto.trim().isNotEmpty)
                ? direccionTexto
                : "Coordenadas: $lat, $lng",
            style: const pw.TextStyle(fontSize: 11),
          ),

          if (referencia.trim().isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              "4. Referencia:",
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(referencia, style: const pw.TextStyle(fontSize: 11)),
          ],

          pw.SizedBox(height: 14),

          pw.Text(
            "Adjunto como medios probatorios la evidencia registrada en el sistema (fotografías, videos u otros), "
            "según corresponda.",
            style: const pw.TextStyle(fontSize: 11),
          ),

          pw.SizedBox(height: 22),

          // ===== Firma =====
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Expanded(child: pw.Container()),
              pw.Column(
                children: [
                  pw.Container(
                    width: 180,
                    height: 80,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(width: 1),
                    ),
                    child: (firmaBytes == null)
                        ? pw.Center(
                            child: pw.Text(
                              "Sin firma",
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                          )
                        : pw.Image(
                            pw.MemoryImage(firmaBytes),
                            fit: pw.BoxFit.contain,
                          ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Container(width: 180, child: pw.Divider()),
                  pw.Text(
                    "Nombre y firma del denunciante",
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 18),

          pw.Text(
            "Nota: Se adjunta copia simple del documento de identidad, y la evidencia cargada en el sistema. "
            "El denunciante puede solicitar una copia de la denuncia presentada, sin costo adicional.",
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );

    return doc.save();
  }
}
