import 'package:flutter/material.dart';
import '../../settings/session.dart';

class DetalleDenunciaScreen extends StatefulWidget {
  const DetalleDenunciaScreen({super.key});

  @override
  State<DetalleDenunciaScreen> createState() => _DetalleDenunciaScreenState();
}

class _DetalleDenunciaScreenState extends State<DetalleDenunciaScreen> {
  static const Color primaryBlue = Color(0xFF2C64C4);
  int currentIndex = 0;

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
      // Map
      if (obj is Map) return obj[field];

      // DenunciaModel u otro objeto con getters
      final dyn = obj as dynamic;
      return dyn?.toJson != null ? dyn.toJson()[field] : dyn?.$field;
    } catch (_) {
      try {
        final dyn = obj as dynamic;
        // intenta por getter conocido
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
          default:
            return null;
        }
      } catch (_) {
        return null;
      }
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

    final id = _get(args, "id");
    final estado = _safe(_get(args, "estado"), fallback: "sin estado");
    final desc = _safe(_get(args, "descripcion"), fallback: "Sin descripción");
    final referencia = _safe(_get(args, "referencia"), fallback: "-");

    final tipoNombre =
        _get(args, "tipo_denuncia_nombre") ?? _get(args, "tipoDenunciaNombre");
    final tipoId =
        _get(args, "tipo_denuncia_id") ?? _get(args, "tipoDenunciaId");
    final tipoTxt = _safe(
      tipoNombre,
      fallback: (tipoId != null ? "Tipo #$tipoId" : "Sin tipo"),
    );

    final fecha = _get(args, "fecha_creacion") ?? _get(args, "fechaCreacion");
    final fechaTxt = _safe(fecha, fallback: "-");

    final lat = _toDouble(_get(args, "latitud"));
    final lng = _toDouble(_get(args, "longitud"));

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
                            color: _estadoColor(estado).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: _estadoColor(estado).withOpacity(0.4),
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

            // Acciones
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.close),
                    label: const Text("Cerrar"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      side: BorderSide(color: Colors.grey.shade400),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (lat == null || lng == null)
                        ? null
                        : () {
                            Navigator.pushNamed(
                              context,
                              '/mapadenuncias',
                              arguments: {"lat": lat, "lng": lng},
                            );
                          },
                    icon: const Icon(Icons.map),
                    label: const Text("Ver mapa"),
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
}
