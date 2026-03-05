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
      return DateFormat("dd/MM/yyyy HH:mm").format(dt.toLocal());
    } catch (_) {
      return v.toString();
    }
  }

  static String _safe(dynamic v, {String fallback = "-"}) {
    final s = (v ?? "").toString().trim();
    return s.isEmpty ? fallback : s;
  }

  static String _absUrl(String raw, String? baseUrl) {
    final s = raw.trim();
    if (s.isEmpty) return "";

    final b = (baseUrl ?? "").trim();
    final apiBase = b.endsWith("/") ? b.substring(0, b.length - 1) : b;
    final rootBase = apiBase.replaceAll(RegExp(r"/web$"), "");

    // Si es absoluta
    if (s.startsWith("http://") || s.startsWith("https://")) {
      final uri = Uri.tryParse(s);
      if (uri != null) {
        final host = uri.host.toLowerCase();
        final isInternal =
            host.startsWith("192.168.") ||
            host.startsWith("10.") ||
            host == "localhost" ||
            host == "127.0.0.1";

        if (isInternal) {
          final path = uri.path; // /api/... o /media/...
          if (path.startsWith("/api/")) {
            return "$apiBase$path"; //  cae en /web/api/...
          }

          if (path.startsWith("/media/")) {
            return "$rootBase$path"; //  /media/ sin /web
          }

          if (path.startsWith("/web/")) return "$rootBase$path";
          return "$rootBase$path";
        }
        return s;
      }
      return s;
    }

    // Relativas
    if (s.startsWith("/api/")) return "$apiBase$s";
    if (s.startsWith("/media/")) return "$rootBase$s";
    if (s.startsWith("/web/")) return "$rootBase$s";
    if (s.startsWith("/")) return "$rootBase$s";

    return "$apiBase/$s";
  }

  static Map<String, String> _headersFrom(Map<String, dynamic> denuncia) {
    final token = (denuncia["auth_token"] ?? denuncia["token"] ?? "")
        .toString()
        .trim();
    if (token.isEmpty) return {};
    // si tu token ya viene como "Bearer xxx", no lo dupliques:
    final isBearer = token.toLowerCase().startsWith("bearer ");
    return {"Authorization": isBearer ? token : "Bearer $token"};
  }

  static Future<Uint8List?> _loadNetworkBytes(
    String? url, {
    required Map<String, String> headers,
  }) async {
    if (url == null) return null;
    final u = url.trim();
    if (u.isEmpty) return null;

    // Si quedó relativo sin host, no sirve para http.get
    if (!u.startsWith("http://") && !u.startsWith("https://")) return null;

    try {
      final uri = Uri.parse(u);
      final r = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));
      if (r.statusCode >= 200 && r.statusCode < 300 && r.bodyBytes.isNotEmpty) {
        return r.bodyBytes;
      }
    } catch (_) {}
    return null;
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

    // Base URL para /media/...
    final baseUrl =
        (denuncia["base_url"] ??
                denuncia["baseUrl"] ??
                denuncia["api_base_url"] ??
                denuncia["apiBaseUrl"])
            ?.toString()
            .trim();

    final headers = _headersFrom(denuncia);

    // ===== Firma =====
    final firmaUrlRaw = (denuncia["firma_url"] ?? "").toString();
    final firmaUrl = _absUrl(firmaUrlRaw, baseUrl);
    final firmaBytes = await _loadNetworkBytes(firmaUrl, headers: headers);

    // ===== Evidencias =====
    final evidenciasRaw = (denuncia["evidencias"] is List)
        ? (denuncia["evidencias"] as List)
        : <dynamic>[];

    final imagenUrls = <String>[];
    final videoUrls = <String>[];

    for (final e in evidenciasRaw) {
      String u = "";
      String tipoEv = "";

      if (e is Map) {
        u = (e["url_archivo"] ?? e["url"] ?? e["archivo"] ?? "")
            .toString()
            .trim();
        tipoEv = (e["tipo"] ?? "").toString().toLowerCase().trim();
      } else if (e is String) {
        u = e.trim();
      }

      if (u.isEmpty) continue;

      final abs = _absUrl(u, baseUrl);
      final isVideo = _isVideoUrl(abs) || tipoEv.contains("video");

      if (isVideo) {
        videoUrls.add(abs);
      } else {
        imagenUrls.add(abs);
      }
    }

    // Descargar hasta 4 imágenes
    final evidenciaImages = <pw.MemoryImage>[];
    for (final url in imagenUrls) {
      if (evidenciaImages.length >= 4) break;
      final bytes = await _loadNetworkBytes(url, headers: headers);
      if (bytes != null) {
        evidenciaImages.add(pw.MemoryImage(bytes));
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
              pw.SizedBox(
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
            "Ciudad de Salcedo, $fecha",
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

          // ✅ Fotos
          if (evidenciaImages.isNotEmpty) ...[
            pw.Text(
              "Fotografías (máximo 4):",
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Wrap(
              spacing: 10,
              runSpacing: 10,
              children: evidenciaImages.map((img) {
                return pw.Container(
                  width: 240,
                  height: 160,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 1, color: PdfColors.grey500),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Image(img, fit: pw.BoxFit.contain),
                );
              }).toList(),
            ),
            pw.SizedBox(height: 10),
          ] else if (imagenUrls.isNotEmpty) ...[
            // si hay urls pero no se pudieron descargar
            pw.Text(
              "Fotos adjuntas: ${imagenUrls.length} (no se pudieron incrustar en el PDF).",
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 6),
          ],

          // ✅ Videos: SOLO mensaje con cantidad (como pediste)
          if (videoUrls.isNotEmpty)
            pw.Text(
              "Videos adjuntos: ${videoUrls.length}",
              style: const pw.TextStyle(fontSize: 10),
            ),

          if (evidenciaImages.isEmpty &&
              imagenUrls.isEmpty &&
              videoUrls.isEmpty)
            pw.Text(
              "No existen evidencias registradas.",
              style: const pw.TextStyle(fontSize: 11),
            ),

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
                  pw.SizedBox(width: 200, child: pw.Divider()),
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
            "Este documento tiene valides de 24 horas, caso contario descargue de nuevo, ya que pierde valides.",
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
          pw.SizedBox(
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
