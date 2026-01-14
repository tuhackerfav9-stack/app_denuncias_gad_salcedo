import 'package:flutter/material.dart';
import '../../repositories/denuncias_repository.dart';
import '../../settings/session.dart';
import '../../models/denuncia_model.dart';

class DenunciasScreen extends StatefulWidget {
  const DenunciasScreen({super.key});

  @override
  State<DenunciasScreen> createState() => _DenunciasScreenState();
}

class _DenunciasScreenState extends State<DenunciasScreen> {
  static const Color primaryBlue = Color(0xFF2C64C4);

  int currentIndex = 0;
  final repo = DenunciasRepository();

  late Future<_DenunciasData> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadAll();
  }

  Future<_DenunciasData> _loadAll() async {
    final borradoresRes = await repo
        .getBorradoresMios(); // {finalizados_auto, borradores:[]}
    final denuncias = await repo.getMias(); // List<DenunciaModel>
    return _DenunciasData(borradoresRes: borradoresRes, denuncias: denuncias);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadAll();
    });
    await _future;
  }

  // Navegación inferior (NO TOCAR)
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

  Future<void> _finalizarBorrador(String id) async {
    try {
      final res = await repo.finalizarBorrador(id);
      _snack("✅ ${res['detail'] ?? 'Borrador finalizado'}");
      await _refresh();
    } catch (e) {
      _snack("❌ Error finalizando: $e");
    }
  }

  Future<void> _eliminarBorrador(String id) async {
    try {
      await repo.eliminarBorrador(id);
      _snack("🗑️ Borrador eliminado");
      await _refresh();
    } catch (e) {
      _snack("❌ Error eliminando: $e");
    }
  }

  // =========================
  // PREVIEW BORRADOR (BOTTOM SHEET)
  // =========================
  void _showPreviewBorrador(Map<String, dynamic> b) {
    final id = (b["id"] ?? "").toString();
    final desc = (b["descripcion"] ?? "").toString();
    final tipoId = b["tipo_denuncia_id"];
    final expSeg = (b["expira_en_seg"] ?? 0);

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    "Borrador",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 10),
                  _chip(
                    text: "editable",
                    bg: Colors.orange.shade50,
                    fg: Colors.orange.shade800,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text("Tipo: #$tipoId"),
              const SizedBox(height: 6),
              Text("Expira en: $expSeg seg"),
              const SizedBox(height: 10),
              Text(
                desc.isEmpty ? "(sin descripción)" : desc,
                style: const TextStyle(height: 1.3),
              ),
              const SizedBox(height: 16),

              // Botones
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(
                          context,
                          '/form/denuncias',
                          arguments: {
                            "modo": "editar_borrador",
                            "borrador_id": id,
                            "data": b,
                          },
                        );
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text("Editar"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _finalizarBorrador(id);
                      },
                      icon: const Icon(Icons.send),
                      label: const Text("Enviar ya"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _eliminarBorrador(id);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text("Eliminar borrador"),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================
  // PREVIEW DENUNCIA FINAL (BOTTOM SHEET)
  // =========================
  void _showPreviewDenuncia(DenunciaModel d) {
    final tipoTxt =
        d.tipoDenunciaNombre ??
        (d.tipoDenunciaId != null ? "Tipo #${d.tipoDenunciaId}" : "Sin tipo");

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tipoTxt,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [const Text("Estado: "), _estadoChip(d.estado)]),
              const SizedBox(height: 10),
              Text(d.descripcion, style: const TextStyle(height: 1.3)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    //Navigator.pop(context);
                    //_snack("Luego: DetalleDenunciaScreen (ID: ${d.id})");
                    Navigator.pushNamed(
                      context,
                      '/detalle_denuncia',
                      arguments: d,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Ver detalle"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================
  // UI HELPERS
  // =========================
  Widget _chip({required String text, required Color bg, required Color fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }

  Widget _estadoChip(String estado) {
    final e = estado.toLowerCase().trim();
    if (e.contains("pend")) {
      return _chip(
        text: "pendiente",
        bg: Colors.orange.shade50,
        fg: Colors.orange.shade800,
      );
    }
    if (e.contains("asign")) {
      return _chip(
        text: "asignada",
        bg: Colors.blue.shade50,
        fg: Colors.blue.shade800,
      );
    }
    if (e.contains("proc")) {
      return _chip(
        text: "proceso",
        bg: Colors.purple.shade50,
        fg: Colors.purple.shade800,
      );
    }
    if (e.contains("res")) {
      return _chip(
        text: "resuelta",
        bg: Colors.green.shade50,
        fg: Colors.green.shade800,
      );
    }
    return _chip(
      text: estado,
      bg: Colors.grey.shade200,
      fg: Colors.grey.shade800,
    );
  }

  Widget _sectionTitle(String text, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Row(
        children: [
          Text(
            text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          if (subtitle != null) ...[
            const SizedBox(width: 8),
            Text(subtitle, style: const TextStyle(color: Colors.black54)),
          ],
        ],
      ),
    );
  }

  Widget _cardShell({required Widget child}) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Drawer (NO TOCAR)
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

      // AppBar (NO TOCAR)
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: primaryBlue),
        title: const Text(
          "Mis Denuncias",
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

      // BODY PRO (aquí sí tocamos)
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_DenunciasData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        "Error cargando datos:\n${snapshot.error}",
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              );
            }

            final data = snapshot.data!;
            final borradores =
                (data.borradoresRes["borradores"] as List?) ?? [];
            final finalizadosAuto = data.borradoresRes["finalizados_auto"] ?? 0;
            final denuncias = data.denuncias;

            // Para que RefreshIndicator funcione aunque esté vacío
            if (borradores.isEmpty && denuncias.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text("Aún no tienes denuncias ni borradores.")),
                ],
              );
            }

            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // BORRADORES
                _sectionTitle(
                  "Denuncias en Revición",
                  subtitle: finalizadosAuto != 0
                      ? "(auto-finalizados: $finalizadosAuto)"
                      : null,
                ),
                if (borradores.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text("No tienes denuncias recientes."),
                  )
                else
                  ...borradores.map((raw) {
                    final b = Map<String, dynamic>.from(raw as Map);
                    final expSeg = (b["expira_en_seg"] ?? 0);
                    final desc = (b["descripcion"] ?? "").toString();
                    final tipoId = b["tipo_denuncia_id"];

                    return _cardShell(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                "Tipo #$tipoId",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            _chip(
                              text: "procesando denuncia",
                              bg: Colors.orange.shade50,
                              fg: Colors.orange.shade800,
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Expira revición en: $expSeg seg"),
                              const SizedBox(height: 6),
                              Text(
                                desc,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showPreviewBorrador(b),
                      ),
                    );
                  }),

                const SizedBox(height: 8),
                const Divider(),

                // DENUNCIAS FINALES
                _sectionTitle("Denuncias enviadas"),
                if (denuncias.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text("Aún no tienes denuncias registradas."),
                  )
                else
                  ...denuncias.map((d) {
                    final tipoTxt =
                        d.tipoDenunciaNombre ??
                        (d.tipoDenunciaId != null
                            ? "Tipo #${d.tipoDenunciaId}"
                            : "Sin tipo");

                    return _cardShell(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        title: Text(
                          tipoTxt,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text("Estado: "),
                                  _estadoChip(d.estado),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                d.descripcion,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showPreviewDenuncia(d),
                      ),
                    );
                  }),

                const SizedBox(height: 80),
              ],
            );
          },
        ),
      ),

      // FAB (NO TOCAR, solo refrescar al volver)
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryBlue,
        shape: const CircleBorder(),
        onPressed: () async {
          await Navigator.pushNamed(context, '/form/denuncias');
          await _refresh();
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),

      // Bottom nav (NO TOCAR)
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
}

class _DenunciasData {
  final Map<String, dynamic> borradoresRes;
  final List<DenunciaModel> denuncias;

  _DenunciasData({required this.borradoresRes, required this.denuncias});
}
