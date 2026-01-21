//import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:printing/printing.dart';

import '../../settings/session.dart';
import '../../repositories/denuncias_repository.dart';
import '../../pdf/denuncia_pdf_builder.dart';

class DetalleDenunciaScreen extends StatefulWidget {
  const DetalleDenunciaScreen({super.key});

  @override
  State<DetalleDenunciaScreen> createState() => _DetalleDenunciaScreenState();
}

class _DetalleDenunciaScreenState extends State<DetalleDenunciaScreen> {
  static const Color primaryBlue = Color(0xFF2C64C4);
  int currentIndex = 0;

  // ✅ NUEVO: repo + estado de carga del detalle real
  final repo = DenunciasRepository();
  Map<String, dynamic>? _detalle;
  bool _loading = true;
  String? _error;

  // ✅ NUEVO: normalizar URL (por si backend manda /media/...)
  String _absUrl(String? u) {
    if (u == null) return "";
    final s = u.trim();
    if (s.isEmpty) return "";
    if (s.startsWith("http://") || s.startsWith("https://")) return s;

    // si viene /media/...
    if (s.startsWith("/")) {
      return "${repo.baseUrl}$s"; // baseUrl sin slash final
    }

    return "${repo.baseUrl}/$s";
  }

  // Navegación inferior (MISMA que vienes usando)
  void _onBottomNavTap(int index) {
    setState(() => currentIndex = index);
    if (index == 0) Navigator.pushNamed(context, '/denuncias');
    if (index == 1) Navigator.pushNamed(context, '/form/denuncias');
    if (index == 2) Navigator.pushNamed(context, '/chatbot');
    if (index == 3) Navigator.pushNamed(context, '/mapadenuncias');
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // Helpers para leer campos desde DenunciaModel o Map
  dynamic _get(dynamic obj, String field) {
    try {
      if (obj is Map) return obj[field];
      final dyn = obj as dynamic;

      // Si tu modelo tuviera toMap/toJson
      try {
        final m = dyn.toMap();
        if (m is Map) return m[field];
      } catch (_) {}
      try {
        final m = dyn.toJson();
        if (m is Map) return m[field];
      } catch (_) {}

      // fallback manual por getters comunes
      switch (field) {
        case "id":
          return dyn.id;
        case "estado":
          return dyn.estado;
        case "descripcion":
          return dyn.descripcion;
        case "referencia":
          return dyn.referencia;
        case "latitud":
          return dyn.latitud;
        case "longitud":
          return dyn.longitud;
        case "tipo_denuncia_id":
          return dyn.tipoDenunciaId;
        case "tipo_denuncia_nombre":
          return dyn.tipoDenunciaNombre;
        case "fecha_creacion":
          return dyn.fechaCreacion;
        case "created_at":
          return dyn.createdAt;
        case "createdAt":
          return dyn.createdAt;

        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  String _safe(dynamic v, {String fallback = "-"}) {
    final s = (v ?? "").toString().trim();
    return s.isEmpty ? fallback : s;
  }

  Color _estadoColor(String estado) {
    final e = estado.toLowerCase();
    if (e.contains("pend")) return Colors.orange;
    if (e.contains("proc") || e.contains("asig")) return Colors.blue;
    if (e.contains("resu") || e.contains("final") || e.contains("cerr")) {
      return Colors.green;
    }
    if (e.contains("rech") || e.contains("anul") || e.contains("cancel")) {
      return Colors.red;
    }
    return Colors.grey;
  }

  // =========================
  // EXTRA: extraer firma/evidencias robusto
  // =========================
  String? _extraerFirmaUrl(dynamic args) {
    // directo
    final direct = _get(args, "firma_url") ?? _get(args, "firmaUrl");
    if (direct != null && direct.toString().trim().isNotEmpty) {
      return direct.toString().trim();
    }

    // firma anidada: firma: { firma_url: ... }
    final firmaObj = _get(args, "firma");
    if (firmaObj is Map) {
      final u =
          firmaObj["firma_url"] ?? firmaObj["url"] ?? firmaObj["url_firma"];
      if (u != null && u.toString().trim().isNotEmpty) {
        return u.toString().trim();
      }
    }

    // si viene lista firmas: firmas: [{firma_url: ...}]
    final firmas = _get(args, "firmas");
    if (firmas is List && firmas.isNotEmpty) {
      final first = firmas.first;
      if (first is Map) {
        final u = first["firma_url"] ?? first["url"] ?? first["url_firma"];
        if (u != null && u.toString().trim().isNotEmpty) {
          return u.toString().trim();
        }
      }
    }

    return null;
  }

  List<Map<String, dynamic>> _extraerEvidencias(dynamic args) {
    final raw =
        _get(args, "evidencias") ??
        _get(args, "evidencia") ??
        _get(args, "media");

    if (raw is List) {
      return raw
          .map((e) {
            if (e is Map) return Map<String, dynamic>.from(e);
            return <String, dynamic>{};
          })
          .where((m) => m.isNotEmpty)
          .toList();
    }

    if (raw is Map && raw["results"] is List) {
      final list = raw["results"] as List;
      return list
          .map(
            (e) =>
                e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{},
          )
          .where((m) => m.isNotEmpty)
          .toList();
    }

    return [];
  }

  void _verImagenFull(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(14),
        child: InteractiveViewer(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Padding(
              padding: EdgeInsets.all(20),
              child: Text("No se pudo cargar la imagen."),
            ),
          ),
        ),
      ),
    );
  }

  // ✅ NUEVO: cargar detalle real al entrar (para firma/evidencias)
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final args = ModalRoute.of(context)?.settings.arguments;
        final id = _get(args, "id")?.toString();

        if (id == null || id.isEmpty) {
          setState(() {
            _error = "No llegó el ID de la denuncia.";
            _loading = false;
          });
          return;
        }

        final detalle = await repo.getDetalleDenuncia(id);

        // Normaliza firma
        final f = detalle["firma"];
        if (f is Map) {
          final firmaUrl = _absUrl(f["firma_url"]?.toString());
          detalle["firma_url"] = firmaUrl;
        } else {
          // por si viene directo
          detalle["firma_url"] = _absUrl(detalle["firma_url"]?.toString());
        }

        // Normaliza evidencias
        final evs = (detalle["evidencias"] as List?) ?? [];
        final evidenciasNorm = evs.map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          final u = (m["url_archivo"] ?? m["url"] ?? "").toString();
          // guardamos normalizado donde el UI ya lo busca primero:
          m["url_archivo"] = _absUrl(u);
          return m;
        }).toList();

        detalle["evidencias"] = evidenciasNorm;

        setState(() {
          _detalle = Map<String, dynamic>.from(detalle);
          _loading = false;
          _error = null;
        });
      } catch (e) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: primaryBlue),
          title: const Text(
            "Detalle Denuncia",
            style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w600),
          ),
        ),
        body: const Center(
          child: Text("No se recibió la denuncia para mostrar."),
        ),
      );
    }

    // ✅ Fuente principal para pintar: detalle real si ya cargó
    final source = _detalle ?? args;

    // ✅ Si está cargando, mantenemos tu estilo (Scaffold igual)
    if (_loading) {
      return Scaffold(
        drawer: Drawer(
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),
                FutureBuilder(
                  future: Future.wait([Session.tipo(), Session.email()]),
                  builder: (context, snap) {
                    final tipo = snap.data?[0] ?? "Ciudadano";
                    final email = snap.data?[1] ?? "sin correo";
                    final letra = email.isNotEmpty
                        ? email[0].toUpperCase()
                        : "C";

                    return ListTile(
                      leading: CircleAvatar(child: Text(letra)),
                      title: Text(tipo == "ciudadano" ? "Ciudadano" : tipo),
                      subtitle: Text(email),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text("Perfil"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/perfil');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text("Ayuda"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/ayuda');
                  },
                ),
                const Spacer(),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text("Cerrar sesión"),
                  onTap: () async {
                    Navigator.pop(context);
                    await Session.clear();
                    if (!context.mounted) return;
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/',
                      (r) => false,
                    );
                  },
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: primaryBlue),
          title: const Text(
            "Detalle Denuncia",
            style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w600),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: _onBottomNavTap,
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          selectedItemColor: primaryBlue,
          unselectedItemColor: Colors.grey.shade600,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: "Inicio"),
            BottomNavigationBarItem(
              icon: Icon(Icons.format_align_center),
              label: "denuncias",
            ),
            BottomNavigationBarItem(icon: Icon(Icons.smart_toy), label: "chat"),
            BottomNavigationBarItem(icon: Icon(Icons.map), label: "mapa"),
          ],
        ),
      );
    }

    // ✅ Si hubo error, muestra mensaje (sin romper estilo)
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: primaryBlue),
          title: const Text(
            "Detalle Denuncia",
            style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w600),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              "Error cargando detalle:\n$_error",
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final id = _get(source, "id") ?? _get(args, "id");
    final estado = _safe(_get(source, "estado"), fallback: "sin estado");
    final desc = _safe(
      _get(source, "descripcion"),
      fallback: "Sin descripción",
    );
    final referencia = _safe(_get(source, "referencia"), fallback: "-");

    // tipo: si viene detalle, puede venir tipo_denuncia: {nombre}
    final tipoNombre =
        _get(source, "tipo_denuncia_nombre") ??
        _get(source, "tipoDenunciaNombre") ??
        _get(source, "tipo_denuncia")?["nombre"];

    final tipoId =
        _get(source, "tipo_denuncia_id") ??
        _get(source, "tipoDenunciaId") ??
        _get(source, "tipo_denuncia")?["id"];

    final tipoTxt = _safe(
      tipoNombre,
      fallback: (tipoId != null ? "Tipo #$tipoId" : "Sin tipo"),
    );

    String fmtFecha(dynamic v) {
      if (v == null) return "-";
      try {
        final s = v.toString();
        final dt = DateTime.tryParse(s);
        if (dt == null) return s;
        final local = dt.toLocal();
        return "${local.day.toString().padLeft(2, '0')}/"
            "${local.month.toString().padLeft(2, '0')}/"
            "${local.year} "
            "${local.hour.toString().padLeft(2, '0')}:"
            "${local.minute.toString().padLeft(2, '0')}";
      } catch (_) {
        return v.toString();
      }
    }

    final fecha =
        _get(source, "created_at") ??
        _get(source, "createdAt") ??
        _get(source, "fecha_creacion") ??
        _get(source, "fechaCreacion");

    final fechaTxt = fmtFecha(fecha);

    final lat = _toDouble(_get(source, "latitud"));
    final lng = _toDouble(_get(source, "longitud"));

    // ✅ AHORA firma/evidencias salen del DETALLE real
    final firmaUrl = _absUrl(_extraerFirmaUrl(source));
    final evidencias = _extraerEvidencias(source).map((m) {
      // normalizamos por si algo se cuela sin normalizar
      final u = (m["url_archivo"] ?? m["url"] ?? "").toString();
      m["url_archivo"] = _absUrl(u);
      return m;
    }).toList();

    final hasCoords = lat != null && lng != null;

    final LatLng? punto = hasCoords ? LatLng(lat, lng) : null;
    final markers = <Marker>{
      if (punto != null) Marker(markerId: const MarkerId("p"), position: punto),
    };

    return Scaffold(
      // Drawer (MISMO estilo)
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 10),
              FutureBuilder(
                future: Future.wait([Session.tipo(), Session.email()]),
                builder: (context, snap) {
                  final tipo = snap.data?[0] ?? "Ciudadano";
                  final email = snap.data?[1] ?? "sin correo";
                  final letra = email.isNotEmpty ? email[0].toUpperCase() : "C";

                  return ListTile(
                    leading: CircleAvatar(child: Text(letra)),
                    title: Text(tipo == "ciudadano" ? "Ciudadano" : tipo),
                    subtitle: Text(email),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text("Perfil"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/perfil');
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text("Ayuda"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/ayuda');
                },
              ),
              const Spacer(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text("Cerrar sesión"),
                onTap: () async {
                  Navigator.pop(context);
                  await Session.clear();
                  if (!context.mounted) return;
                  Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),

      // AppBar (MISMO estilo)
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: primaryBlue),
        title: const Text(
          "Detalle Denuncia",
          style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w600),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: FutureBuilder<String?>(
              future: Session.email(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }

                final email = snapshot.data ?? "";
                final letra = email.isNotEmpty ? email[0].toUpperCase() : "C";

                return CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey.shade300,
                  child: Text(
                    letra,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),

      //  BODY PRO
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Card principal
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título + estado chip
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            tipoTxt,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _estadoColor(estado).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: _estadoColor(
                                estado,
                              ).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            estado,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _estadoColor(estado),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    _infoRow("ID", _safe(id, fallback: "-")),
                    _infoRow("Fecha", fechaTxt),
                    _infoRow(
                      "Ubicación",
                      (lat != null && lng != null)
                          ? "${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}"
                          : "-",
                    ),
                    _infoRow("Referencia", referencia),

                    const SizedBox(height: 12),
                    const Text(
                      "Descripción",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      desc,
                      style: const TextStyle(fontSize: 14, height: 1.35),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // MAPA
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Ubicación en el mapa",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 180,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: !hasCoords
                          ? const Center(child: Text("No hay coordenadas."))
                          : GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: punto!,
                                zoom: 16,
                              ),
                              markers: markers,
                              zoomControlsEnabled: false,
                              myLocationButtonEnabled: false,
                              rotateGesturesEnabled: false,
                              scrollGesturesEnabled: false,
                              tiltGesturesEnabled: false,
                              zoomGesturesEnabled: false,
                            ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: !hasCoords
                            ? null
                            : () {
                                Navigator.pushNamed(
                                  context,
                                  '/mapadenuncias',
                                  arguments: {"lat": lat, "lng": lng},
                                );
                              },
                        icon: const Icon(Icons.map),
                        label: const Text("Abrir en mapa"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // EVIDENCIAS
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Evidencias",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (evidencias.isEmpty)
                      const Text("No hay evidencias adjuntas.")
                    else
                      SizedBox(
                        height: 92,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: evidencias.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (_, i) {
                            final ev = evidencias[i];
                            final tipo = (ev["tipo"] ?? "")
                                .toString()
                                .toLowerCase();

                            // ✅ usa url_archivo (normalizado)
                            final url = (ev["url_archivo"] ?? ev["url"] ?? "")
                                .toString();

                            final isVideo =
                                tipo.contains("video") ||
                                url.toLowerCase().contains(".mp4");

                            if (url.trim().isEmpty) {
                              return _miniBox(
                                child: const Center(child: Text("Sin URL")),
                              );
                            }

                            if (isVideo) {
                              return _miniBox(
                                onTap: () => _snack(
                                  "Video: abre el link en un visor (si quieres lo implemento)",
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.videocam, size: 28),
                                    SizedBox(height: 6),
                                    Text(
                                      "Video",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            // Imagen
                            return _miniBox(
                              onTap: () => _verImagenFull(url),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  url,
                                  width: 120,
                                  height: 92,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(10),
                                      child: Text("No carga"),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // FIRMA
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Firma",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (firmaUrl.trim().isEmpty)
                      const Text("No hay firma registrada.")
                    else
                      GestureDetector(
                        onTap: () => _verImagenFull(firmaUrl),
                        child: Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.network(
                            firmaUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Text("No se pudo cargar la firma."),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Acciones (PDF) - MISMO
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        final detalle = await repo.getDetalleDenuncia(
                          id.toString(),
                        );

                        final data = {
                          "tipo_denuncia_nombre":
                              detalle["tipo_denuncia"]?["nombre"],
                          "descripcion": detalle["descripcion"],
                          "estado": detalle["estado"],
                          "referencia": detalle["referencia"],
                          "direccion_texto": detalle["direccion_texto"],
                          "latitud": detalle["latitud"],
                          "longitud": detalle["longitud"],
                          "created_at": detalle["created_at"],

                          "ciudadano_nombres": detalle["ciudadano"]?["nombres"],
                          "ciudadano_apellidos":
                              detalle["ciudadano"]?["apellidos"],
                          "ciudadano_cedula": detalle["ciudadano"]?["cedula"],

                          // ✅ normaliza firma por si viene /media/
                          "firma_url": _absUrl(detalle["firma"]?["firma_url"]),
                          "evidencias": detalle["evidencias"],
                        };

                        final pdfBytes = await DenunciaPdfBuilder.build(
                          denuncia: data,
                        );

                        await Printing.layoutPdf(
                          onLayout: (_) async => pdfBytes,
                        );
                      } catch (e) {
                        _snack("Error PDF: $e");
                      }
                    },
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text("Descargar PDF"),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),

      // Menú inferior (MISMO)
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: _onBottomNavTap,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        selectedItemColor: primaryBlue,
        unselectedItemColor: Colors.grey.shade600,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Inicio"),
          BottomNavigationBarItem(
            icon: Icon(Icons.format_align_center),
            label: "denuncias",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.smart_toy), label: "chat"),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: "mapa"),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              "$label:",
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black54)),
          ),
        ],
      ),
    );
  }

  Widget _miniBox({required Widget child, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 120,
        height: 92,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300),
          color: Colors.white,
        ),
        child: child,
      ),
    );
  }
}
