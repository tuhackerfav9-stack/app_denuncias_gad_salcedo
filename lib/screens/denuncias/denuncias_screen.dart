import 'package:flutter/material.dart';
import 'package:awesome_dialog/awesome_dialog.dart';

import '../../repositories/denuncias_repository.dart';
import '../../settings/session.dart';
import '../../models/denuncia_model.dart';

//   (manejo global)
import '../error_view.dart';
import '../../settings/api_exception.dart';

class DenunciasScreen extends StatefulWidget {
  const DenunciasScreen({super.key});

  @override
  State<DenunciasScreen> createState() => _DenunciasScreenState();
}

class _DenunciasScreenState extends State<DenunciasScreen> {
  static const Color primaryBlue = Color(0xFF2C64C4);
  static const Color cancelGrey = Color(0xFF9E9E9E);
  int currentIndex = 0;
  final repo = DenunciasRepository();

  //   NUEVO: control de carga + error (para ErrorView)
  bool _loading = true;
  ApiException? _error;
  _DenunciasData? _data;

  bool _welcomeShown = false;

  //   NUEVO: Mapa local para mostrar nombre en vez de "Tipo #"
  static const List<String> _tipos = [
    'Alumbrado público',
    'Basura / Aseo',
    'Vías / Baches',
    'Seguridad',
    'Ruido',
    'Otro',
  ];

  String _tipoNombreDesdeId(dynamic tipoId) {
    if (tipoId == null) return "Sin tipo";
    int? id;
    if (tipoId is int) {
      id = tipoId;
    } else if (tipoId is String) {
      id = int.tryParse(tipoId);
    }
    if (id == null) return "Sin tipo";
    if (id >= 1 && id <= _tipos.length) return _tipos[id - 1];
    return "Tipo #$id";
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_welcomeShown) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    final showWelcome = (args is Map && args['showWelcome'] == true);

    if (showWelcome) {
      _welcomeShown = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mostrarBienvenida();
      });
    }
  }

  void _mostrarBienvenida() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false, // solo se cierra con la X
      barrierLabel: "Bienvenida",
      pageBuilder: (_, __, ___) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Fondo del popup (imagen)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset('assets/foto_menu.png', fit: BoxFit.cover),
                ),

                // Botón X arriba a la derecha
                Positioned(
                  top: 10,
                  right: 22,
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha((0.55 * 255).round()),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    cargar(); //   NUEVO: ya no FutureBuilder
  }

  //   NUEVO: carga centralizada con ApiException
  Future<void> cargar() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final borradoresRes = await repo.getBorradoresMios();
      final denuncias = await repo.getMias();
      final data = _DenunciasData(
        borradoresRes: borradoresRes,
        denuncias: denuncias,
      );

      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiException(
          type: ApiErrorType.unknown,
          message: "Ocurrió un error inesperado.",
          raw: e.toString(),
        );
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    await cargar();
  }

  // Navegación inferior (NO TOCAR)
  void _onBottomNavTap(int index) {
    setState(() => currentIndex = index);

    if (index == 0) Navigator.pushNamed(context, '/denuncias');
    if (index == 1) Navigator.pushNamed(context, '/form/denuncias');
    if (index == 2) Navigator.pushNamed(context, '/chatbot');
    if (index == 3) Navigator.pushNamed(context, '/mapadenuncias');
  }

  // =========================
  // DIALOGS PRO (AwesomeDialog) - con tu paleta
  // =========================

  Widget _blueHeader(IconData icon) {
    return Container(
      width: 70,
      height: 70,
      decoration: const BoxDecoration(
        color: primaryBlue,
        shape: BoxShape.circle,
      ),
      child: Center(child: Icon(icon, color: Colors.white, size: 36)),
    );
  }

  void _okDialog(String title, String desc) {
    AwesomeDialog(
      context: context,
      animType: AnimType.scale,
      title: title,
      desc: desc,
      headerAnimationLoop: false,

      // ✅ Header azul
      customHeader: _blueHeader(Icons.check_circle_outline),

      btnOkText: "Listo",
      btnOkColor: primaryBlue,
      btnOkOnPress: () {},
    ).show();
  }

  void _errorDialog(String title, String desc) {
    AwesomeDialog(
      context: context,
      animType: AnimType.scale,
      title: title,
      desc: desc,
      headerAnimationLoop: false,

      // ✅ Header azul (no rojo)
      customHeader: _blueHeader(Icons.error_outline),

      btnOkText: "Entendido",
      btnOkColor: primaryBlue,
      btnOkOnPress: () {},
    ).show();
  }

  void _confirmDialog({
    required String title,
    required String desc,
    required VoidCallback onOk,
  }) {
    AwesomeDialog(
      context: context,
      animType: AnimType.scale,
      title: title,
      desc: desc,
      headerAnimationLoop: false,

      // ✅ Header azul (no amarillo)
      customHeader: _blueHeader(Icons.help_outline),

      btnCancelText: "Cancelar",
      btnOkText: "Sí, continuar",
      btnCancelColor: cancelGrey,
      btnOkColor: primaryBlue,

      btnCancelOnPress: () {},
      btnOkOnPress: onOk,
    ).show();
  }

  Future<void> _finalizarBorrador(String id) async {
    try {
      final res = await repo.finalizarBorrador(id);
      if (!mounted) return;

      _okDialog(
        "Denuncia enviada",
        (res['detail'] ?? "Borrador finalizado").toString(),
      );
      await _refresh();
    } on ApiException catch (e) {
      if (!mounted) return;

      // si es error “global”, mejor pantalla completa al recargar, pero aquí damos un dialog rápido
      _errorDialog("No se pudo enviar", e.message);
    } catch (e) {
      if (!mounted) return;
      _errorDialog("No se pudo enviar", e.toString());
    }
  }

  Future<void> _eliminarBorrador(String id) async {
    try {
      await repo.eliminarBorrador(id);
      if (!mounted) return;

      _okDialog("Borrador eliminado", "Se eliminó correctamente.");
      await _refresh();
    } on ApiException catch (e) {
      if (!mounted) return;
      _errorDialog("No se pudo eliminar", e.message);
    } catch (e) {
      if (!mounted) return;
      _errorDialog("No se pudo eliminar", e.toString());
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

    //   NUEVO: Nombre en vez de #id
    final tipoNombre = _tipoNombreDesdeId(tipoId);

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

              Text("Tipo: $tipoNombre"),

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

                        _confirmDialog(
                          title: "Enviar denuncia",
                          desc: "¿Deseas enviar este borrador ahora?",
                          onOk: () async => await _finalizarBorrador(id),
                        );
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

                    _confirmDialog(
                      title: "Eliminar borrador",
                      desc: "Esta acción no se puede deshacer. ¿Eliminar?",
                      onOk: () async => await _eliminarBorrador(id),
                    );
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
        (d.tipoDenunciaNombre != null &&
            d.tipoDenunciaNombre!.trim().isNotEmpty)
        ? d.tipoDenunciaNombre!
        : _tipoNombreDesdeId(d.tipoDenunciaId);

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
    //   NUEVO: si hay error global, mostramos ErrorView (pantalla completa)
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: primaryBlue),
          title: const Text(
            "Mis Denuncias",
            style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w600),
          ),
        ),
        body: ErrorView(error: _error!, onRetry: cargar),
      );
    }

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

      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _loading
            ? ListView(
                children: const [
                  SizedBox(height: 140),

                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _buildContent(),
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

  Widget _buildContent() {
    final data = _data;

    if (data == null) {
      // raro, pero por seguridad
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(child: Text("No se pudo cargar la información.")),
        ],
      );
    }

    final borradores = (data.borradoresRes["borradores"] as List?) ?? [];
    final finalizadosAuto = data.borradoresRes["finalizados_auto"] ?? 0;
    final denuncias = data.denuncias;

    if (borradores.isEmpty && denuncias.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(child: Text("Aún no tienes denuncias, registra una.")),
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

            final tipoNombre = _tipoNombreDesdeId(tipoId);

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
                        tipoNombre,
                        style: const TextStyle(fontWeight: FontWeight.w800),
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
                      Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis),
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
                (d.tipoDenunciaNombre != null &&
                    d.tipoDenunciaNombre!.trim().isNotEmpty)
                ? d.tipoDenunciaNombre!
                : _tipoNombreDesdeId(d.tipoDenunciaId);

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
  }
}

class _DenunciasData {
  final Map<String, dynamic> borradoresRes;
  final List<DenunciaModel> denuncias;

  _DenunciasData({required this.borradoresRes, required this.denuncias});
}
