import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class DenunciaPdfBuilder {
  // =========================
  // Helpers
  // =========================
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

  static String _safe(dynamic v, {String fallback = "-"}) {
    final s = (v ?? "").toString().trim();
    return s.isEmpty ? fallback : s;
  }

  static Future<Uint8List?> _loadNetworkImage(String? url) async {
    if (url == null || url.trim().isEmpty) return null;
    try {
      final uri = Uri.parse(url.trim());
      final r = await http.get(uri);
      if (r.statusCode >= 200 && r.statusCode < 300) {
        return r.bodyBytes;
      }
    } catch (_) {}
    return null;
  }

  static bool _isImageUrl(String url) {
    final u = url.toLowerCase();
    return u.endsWith(".png") ||
        u.endsWith(".jpg") ||
        u.endsWith(".jpeg") ||
        u.endsWith(".webp") ||
        u.endsWith(".gif");
  }

  static bool _isVideoUrl(String url) {
    final u = url.toLowerCase();
    return u.endsWith(".mp4") || u.endsWith(".mov") || u.endsWith(".avi");
  }

  // =========================
  // PDF Builder
  // =========================
  static Future<Uint8List> build({
    required Map<String, dynamic> denuncia,
  }) async {
    // ===== Datos =====
    final tipo = _safe(denuncia["tipo_denuncia_nombre"], fallback: "Denuncia");
    final descripcion = _safe(denuncia["descripcion"], fallback: "");
    final estado = _safe(denuncia["estado"], fallback: "pendiente");
    final referencia = _safe(denuncia["referencia"], fallback: "");
    final direccion = _safe(denuncia["direccion_texto"], fallback: "");
    final lat = _safe(denuncia["latitud"], fallback: "");
    final lng = _safe(denuncia["longitud"], fallback: "");
    final fecha = _fmtFecha(denuncia["created_at"]);

    final nombres = _safe(denuncia["ciudadano_nombres"], fallback: "");
    final apellidos = _safe(denuncia["ciudadano_apellidos"], fallback: "");
    final cedula = _safe(denuncia["ciudadano_cedula"], fallback: "");

    // Firma (URL -> bytes)
    final firmaUrl = (denuncia["firma_url"] ?? "").toString();
    final firmaBytes = await _loadNetworkImage(firmaUrl);

    // Evidencias (lista)
    final evidenciasRaw = (denuncia["evidencias"] is List)
        ? (denuncia["evidencias"] as List)
        : <dynamic>[];

    // Normalizar URLs de evidencias
    final evidenciasUrls = <String>[];
    final videosUrls = <String>[];

    for (final e in evidenciasRaw) {
      if (e is Map) {
        final u = (e["url_archivo"] ?? e["url"] ?? "").toString().trim();
        if (u.isEmpty) continue;

        if (_isVideoUrl(u) ||
            (e["tipo"]?.toString().toLowerCase().contains("video") ?? false)) {
          videosUrls.add(u);
        } else {
          // si no termina en extensión, igual la intentamos como imagen
          evidenciasUrls.add(u);
        }
      } else if (e is String) {
        final u = e.trim();
        if (u.isEmpty) continue;
        if (_isVideoUrl(u)) {
          videosUrls.add(u);
        } else {
          evidenciasUrls.add(u);
        }
      }
    }

    // Cargar hasta 4 evidencias como imágenes (para no demorar ni pesar tanto)
    final evidenciaImages = <Uint8List>[];
    for (final url in evidenciasUrls) {
      if (evidenciaImages.length >= 4) break;

      // si tiene extensión de imagen, ok; si no, igual intentamos descargar
      if (_isImageUrl(url) || true) {
        final bytes = await _loadNetworkImage(url);
        if (bytes != null) evidenciaImages.add(bytes);
      }
    }

    // Logo asset
    final logoData = await rootBundle.load(
      'assets/LOGO_GAD_MUNICIPAL_SALCEDO.png',
    );
    final logo = pw.MemoryImage(logoData.buffer.asUint8List());

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          // ========= Header =========
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
                    pw.SizedBox(height: 4),
                    pw.Text(
                      "Sistema de Denuncias Públicas",
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 10,
                      ),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey200,
                        border: pw.Border.all(
                          width: 1,
                          color: PdfColors.grey600,
                        ),
                        borderRadius: pw.BorderRadius.circular(4),
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
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    "Estado: $estado",
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 14),
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 10),

          // ========= Intro =========
          pw.Text(
            "Ciudad de Salcedo, a los ____ días del mes de __________ del año ____.",
            style: const pw.TextStyle(fontSize: 11),
          ),
          pw.SizedBox(height: 10),

          pw.Text(
            "Yo, ${_safe("$nombres $apellidos", fallback: "-")}, identificado/a con cédula N.° ${_safe(cedula)}, "
            "me presento ante usted con la finalidad de dejar constancia de una denuncia relacionada con el siguiente hecho:",
            style: const pw.TextStyle(fontSize: 11),
          ),

          pw.SizedBox(height: 14),

          // ========= Bloque 1: Datos =========
          _sectionTitle("1. Información general"),
          _kv("Tipo de denuncia", tipo),
          _kv("Estado", estado),
          _kv("Referencia", referencia.isEmpty ? "-" : referencia),

          pw.SizedBox(height: 10),

          _sectionTitle("2. Descripción de los hechos"),
          pw.Text(
            descripcion.isEmpty ? "-" : descripcion,
            style: const pw.TextStyle(fontSize: 11),
          ),

          pw.SizedBox(height: 10),

          _sectionTitle("3. Ubicación"),
          pw.Text(
            direccion.isNotEmpty ? direccion : "Coordenadas: $lat, $lng",
            style: const pw.TextStyle(fontSize: 11),
          ),

          pw.SizedBox(height: 14),

          // ========= Evidencias =========
          _sectionTitle("4. Evidencias registradas en el sistema"),
          if (evidenciaImages.isEmpty && videosUrls.isEmpty)
            pw.Text(
              "No existen evidencias registradas.",
              style: const pw.TextStyle(fontSize: 11),
            )
          else ...[
            if (evidenciaImages.isNotEmpty) ...[
              pw.Text(
                "Fotografías (máximo 4):",
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Wrap(
                spacing: 10,
                runSpacing: 10,
                children: evidenciaImages.map((bytes) {
                  return pw.Container(
                    width: 240,
                    height: 160,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(width: 1, color: PdfColors.grey500),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Image(
                      pw.MemoryImage(bytes),
                      fit: pw.BoxFit.contain,
                    ),
                  );
                }).toList(),
              ),
              pw.SizedBox(height: 10),
            ],
            if (videosUrls.isNotEmpty) ...[
              pw.Text(
                "Videos (enlaces):",
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: videosUrls
                    .take(5)
                    .map(
                      (u) => pw.Text(
                        "- $u",
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],

          pw.SizedBox(height: 18),

          // ========= Firma =========
          _sectionTitle("5. Firma del denunciante"),
          pw.SizedBox(height: 6),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Expanded(child: pw.Container()),
              pw.Column(
                children: [
                  pw.Container(
                    width: 200,
                    height: 90,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(width: 1, color: PdfColors.grey600),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    padding: const pw.EdgeInsets.all(6),
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
                  pw.Container(width: 200, child: pw.Divider()),
                  pw.Text(
                    _safe(
                      "$nombres $apellidos",
                      fallback: "Nombre del denunciante",
                    ),
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 14),

          // ========= Nota =========
          pw.Text(
            "Nota: La evidencia adjunta (fotografías, videos u otros) corresponde a la registrada en el sistema. "
            "El denunciante puede solicitar una copia de la denuncia presentada.",
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text(
            "Página ${context.pageNumber} de ${context.pagesCount}",
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ),
      ),
    );

    return doc.save();
  }

  // ===== UI helpers pdf =====
  static pw.Widget _sectionTitle(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: PdfColors.grey400),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _kv(String k, String v) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 120,
            child: pw.Text(
              "$k:",
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              v.trim().isEmpty ? "-" : v,
              style: const pw.TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
