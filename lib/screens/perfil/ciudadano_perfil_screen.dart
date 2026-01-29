import 'package:flutter/material.dart';
import 'package:awesome_dialog/awesome_dialog.dart';

import '../../settings/session.dart';
import '../../repositories/perfil_repository.dart';
import '../../models/perfil_model.dart';

//  Manejo global de errores
import '../../settings/api_exception.dart';

class CiudadanoPerfilScreen extends StatefulWidget {
  const CiudadanoPerfilScreen({super.key});

  @override
  State<CiudadanoPerfilScreen> createState() => _CiudadanoPerfilScreenState();
}

class _CiudadanoPerfilScreenState extends State<CiudadanoPerfilScreen> {
  static const Color primaryBlue = Color(0xFF2C64C4);
  static const Color cancelGrey = Color(0xFF9E9E9E);

  final formKey = GlobalKey<FormState>();
  int currentIndex = 0;

  // repo
  final repo = PerfilRepository();

  // loading
  bool _loading = true;
  bool _saving = false;

  PerfilModel? _perfil;

  // Controllers
  final cedulaController = TextEditingController();
  final nombresController = TextEditingController();
  final apellidosController = TextEditingController();
  final telefonoController = TextEditingController();
  final correoController = TextEditingController();
  final fechaNacController = TextEditingController();

  // Password toggle
  bool cambiarContrasena = false;
  final passActualController = TextEditingController();
  final passNuevaController = TextEditingController();
  final passConfirmarController = TextEditingController();
  bool obscurePassActual = true;
  bool obscurePassNueva = true;
  bool obscurePassConfirmar = true;

  // Para saber si hubo cambios
  Map<String, String> originalValues = {};

  @override
  void initState() {
    super.initState();
    _loadPerfil();
  }

  @override
  void dispose() {
    cedulaController.dispose();
    nombresController.dispose();
    apellidosController.dispose();
    telefonoController.dispose();
    correoController.dispose();
    fechaNacController.dispose();

    passActualController.dispose();
    passNuevaController.dispose();
    passConfirmarController.dispose();
    super.dispose();
  }

  // ====== bottom nav ======
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

  void _dlgOk({required String title, required String desc}) {
    AwesomeDialog(
      context: context,
      animType: AnimType.scale,
      title: title,
      desc: desc,
      headerAnimationLoop: false,
      customHeader: _blueHeader(Icons.check_circle_outline),
      btnOkText: "Listo",
      btnOkColor: primaryBlue,
      btnOkOnPress: () {},
    ).show();
  }

  void _dlgError({required String title, required String desc}) {
    AwesomeDialog(
      context: context,
      animType: AnimType.scale,
      title: title,
      desc: desc,
      headerAnimationLoop: false,
      customHeader: _blueHeader(Icons.error_outline),
      btnOkText: "Entendido",
      btnOkColor: primaryBlue,
      btnOkOnPress: () {},
    ).show();
  }

  void _dlgInfo({required String title, required String desc}) {
    AwesomeDialog(
      context: context,
      animType: AnimType.scale,
      title: title,
      desc: desc,
      headerAnimationLoop: false,
      customHeader: _blueHeader(Icons.info_outline),
      btnOkText: "Ok",
      btnOkColor: primaryBlue,
      btnOkOnPress: () {},
    ).show();
  }

  void _dlgConfirm({
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
      customHeader: _blueHeader(Icons.help_outline),
      btnCancelText: "Cancelar",
      btnOkText: "Sí, guardar",
      btnCancelColor: cancelGrey,
      btnOkColor: primaryBlue,
      btnCancelOnPress: () {},
      btnOkOnPress: onOk,
    ).show();
  }

  // Mapea ApiException -> dialog + acciones (401 manda a login)
  Future<void> _handleApiException(ApiException e) async {
    if (!mounted) return;

    switch (e.type) {
      case ApiErrorType.unauthorized:
        _dlgInfo(title: "Sesión expirada", desc: e.message);
        await Session.clear();
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
        return;

      case ApiErrorType.forbidden:
        _dlgError(title: "Sin permisos", desc: e.message);
        return;

      case ApiErrorType.network:
        _dlgError(title: "Sin conexión", desc: e.message);
        return;

      case ApiErrorType.timeout:
        _dlgError(title: "Tiempo de espera", desc: e.message);
        return;

      case ApiErrorType.server:
        _dlgError(title: "Servidor con problemas", desc: e.message);
        return;

      case ApiErrorType.unknown:
        _dlgError(title: "Error", desc: e.message);
        return;
    }
  }

  Future<void> _loadPerfil() async {
    setState(() => _loading = true);

    try {
      final p = await repo.getPerfil();

      _perfil = p;

      // set controllers
      cedulaController.text = p.cedula ?? "";
      correoController.text = p.correo;
      nombresController.text = p.nombres;
      apellidosController.text = p.apellidos;
      telefonoController.text = p.telefono;

      if (p.fechaNacimiento != null) {
        final d = p.fechaNacimiento!;
        final yyyy = d.year.toString().padLeft(4, '0');
        final mm = d.month.toString().padLeft(2, '0');
        final dd = d.day.toString().padLeft(2, '0');
        fechaNacController.text = "$yyyy-$mm-$dd";
      } else {
        fechaNacController.text = "";
      }

      originalValues = {
        'cedula': cedulaController.text,
        'nombres': nombresController.text,
        'apellidos': apellidosController.text,
        'telefono': telefonoController.text,
        'correo': correoController.text,
        'fecha': fechaNacController.text,
      };
    } on ApiException catch (e) {
      await _handleApiException(e);
    } catch (e) {
      _dlgError(title: "No se pudo cargar", desc: e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _huboCambiosPerfil() {
    return nombresController.text != (originalValues['nombres'] ?? "") ||
        apellidosController.text != (originalValues['apellidos'] ?? "") ||
        telefonoController.text != (originalValues['telefono'] ?? "") ||
        fechaNacController.text != (originalValues['fecha'] ?? "");
  }

  bool _huboCambiosContrasena() {
    if (!cambiarContrasena) return false;
    return passActualController.text.trim().isNotEmpty ||
        passNuevaController.text.trim().isNotEmpty ||
        passConfirmarController.text.trim().isNotEmpty;
  }

  Future<void> _pickFecha() async {
    final now = DateTime.now();
    final initial =
        DateTime.tryParse(fechaNacController.text) ??
        DateTime(now.year - 18, 1, 1);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950, 1, 1),
      lastDate: DateTime(now.year - 10, 12, 31),
    );

    if (picked == null) return;

    final yyyy = picked.year.toString().padLeft(4, '0');
    final mm = picked.month.toString().padLeft(2, '0');
    final dd = picked.day.toString().padLeft(2, '0');

    setState(() {
      fechaNacController.text = '$yyyy-$mm-$dd';
    });
  }

  DateTime? _parseFecha(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return DateTime.tryParse(t);
  }

  Future<void> _guardar() async {
    if (_saving) return;

    if (!formKey.currentState!.validate()) return;

    final cambiosPerfil = _huboCambiosPerfil();
    final cambiosClave = _huboCambiosContrasena();

    if (!cambiosPerfil && !cambiosClave) {
      _dlgInfo(title: "Sin cambios", desc: "No hay cambios para guardar.");
      return;
    }

    // Validación extra si cambia contraseña
    if (cambiarContrasena) {
      if (passActualController.text.trim().isEmpty) {
        _dlgInfo(title: "Falta un dato", desc: "Ingresa tu contraseña actual.");
        return;
      }
      if (passNuevaController.text.trim().length < 6) {
        _dlgInfo(
          title: "Contraseña débil",
          desc: "La nueva contraseña debe tener mínimo 6 caracteres.",
        );
        return;
      }
      if (passNuevaController.text.trim() !=
          passConfirmarController.text.trim()) {
        _dlgInfo(title: "No coincide", desc: "La confirmación no coincide.");
        return;
      }
    }

    // Confirmación con tu paleta
    _dlgConfirm(
      title: "Guardar cambios",
      desc: "¿Deseas guardar los cambios del perfil?",
      onOk: () async => await _guardarReal(),
    );
  }

  Future<void> _guardarReal() async {
    setState(() => _saving = true);

    try {
      final cambiosPerfil = _huboCambiosPerfil();
      //final cambiosClave = _huboCambiosContrasena();//la comento con el fin de ver como actua el flujo si no se rompe

      // 1) actualizar perfil (PATCH) solo si cambió algo
      if (cambiosPerfil && _perfil != null) {
        final nombres = nombresController.text.trim();
        final apellidos = apellidosController.text.trim();
        final telefono = telefonoController.text.trim();
        final fecha = _parseFecha(fechaNacController.text);
        final _ = _perfil!.cedula;

        await repo.updatePerfilPatch(
          nombres: nombres,
          apellidos: apellidos,
          telefono: telefono,
          fechaNacimiento: fecha,
        );
      }

      // 2) cambiar contraseña (solo si checkbox activo)
      if (cambiarContrasena) {
        await repo.changePassword(
          actual: passActualController.text.trim(),
          nueva: passNuevaController.text.trim(),
          confirmar: passConfirmarController.text.trim(),
        );
      }

      if (!mounted) return;

      _dlgOk(title: "Listo", desc: "Cambios guardados correctamente.");

      // refrescar perfil
      await _loadPerfil();

      // limpiar zona contraseña
      setState(() {
        cambiarContrasena = false;
        passActualController.clear();
        passNuevaController.clear();
        passConfirmarController.clear();
      });
    } on ApiException catch (e) {
      await _handleApiException(e);
    } catch (e) {
      if (!mounted) return;
      _dlgError(title: "Error guardando", desc: e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final emailFuture = Session.email();

    return Scaffold(
      backgroundColor: Colors.white,

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

              // PERFIL activo
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: primaryBlue.withAlpha((0.10 * 255).round()),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  leading: const Icon(Icons.person_outline, color: primaryBlue),
                  title: const Text(
                    "Perfil",
                    style: TextStyle(
                      color: primaryBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
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

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: primaryBlue),
        title: const Text(
          "Perfil",
          style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadPerfil,
            icon: const Icon(Icons.refresh),
            tooltip: "Actualizar",
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: FutureBuilder<String?>(
              future: emailFuture,
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

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
              child: Form(
                key: formKey,
                child: Column(
                  children: [
                    // AVATAR letra del correo
                    Center(
                      child: FutureBuilder<String?>(
                        future: Session.email(),
                        builder: (context, snapshot) {
                          final email = snapshot.data ?? "";
                          final letra = email.isNotEmpty
                              ? email[0].toUpperCase()
                              : "C";

                          return Column(
                            children: [
                              Container(
                                width: 150,
                                height: 150,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.grey.shade300,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  letra,
                                  style: const TextStyle(
                                    fontSize: 64,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                "Editar perfil",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 18),

                    // CÉDULA (solo lectura)
                    _label('Cédula de identidad'),
                    const SizedBox(height: 8),
                    _input(
                      controller: cedulaController,
                      hint: 'cédula',
                      readOnly: true,
                      enabled: false,
                    ),
                    const SizedBox(height: 14),

                    // Correo (solo lectura)
                    _label('Correo electrónico'),
                    const SizedBox(height: 8),
                    _input(
                      controller: correoController,
                      hint: 'correo',
                      readOnly: true,
                      enabled: false,
                    ),

                    const SizedBox(height: 14),

                    // Nombres editable
                    _label('Nombres'),
                    const SizedBox(height: 8),
                    _input(
                      controller: nombresController,
                      hint: 'Ej. Cristian Santiago',
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Los nombres son requeridos'
                          : null,
                    ),

                    const SizedBox(height: 14),

                    // Apellidos editable
                    _label('Apellidos'),
                    const SizedBox(height: 8),
                    _input(
                      controller: apellidosController,
                      hint: 'Ej. Alcocer Cando',
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Los apellidos son requeridos'
                          : null,
                    ),

                    const SizedBox(height: 14),

                    // Teléfono editable
                    _label('Teléfono'),
                    const SizedBox(height: 8),
                    _input(
                      controller: telefonoController,
                      hint: 'Ej. 0999999999',
                      keyboardType: TextInputType.phone,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'El teléfono es requerido';
                        }
                        if (v.trim().length < 10) {
                          return 'Debe tener mínimo 10 dígitos';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 14),

                    // Fecha nacimiento editable
                    _label('Fecha nacimiento'),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickFecha,
                      child: AbsorbPointer(
                        child: _input(
                          controller: fechaNacController,
                          hint: 'YYYY-MM-DD',
                          suffixIcon: const Icon(Icons.calendar_month),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Selecciona la fecha'
                              : null,
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // CAMBIAR CONTRASEÑA
                    Row(
                      children: [
                        Checkbox(
                          value: cambiarContrasena,
                          onChanged: _saving
                              ? null
                              : (v) => setState(
                                  () => cambiarContrasena = v ?? false,
                                ),
                          activeColor: primaryBlue,
                        ),
                        const Text(
                          'Cambiar contraseña',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),

                    if (cambiarContrasena) ...[
                      const SizedBox(height: 8),
                      _label('Contraseña actual'),
                      const SizedBox(height: 8),
                      _input(
                        controller: passActualController,
                        hint: '**********',
                        obscureText: obscurePassActual,
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => obscurePassActual = !obscurePassActual,
                          ),
                          icon: Icon(
                            obscurePassActual
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),
                      _label('Nueva contraseña'),
                      const SizedBox(height: 8),

                      _input(
                        controller: passNuevaController,
                        hint: 'mínimo 6 caracteres',
                        obscureText: obscurePassNueva,
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => obscurePassNueva = !obscurePassNueva,
                          ),
                          icon: Icon(
                            obscurePassNueva
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),
                      _label('Confirmar contraseña'),
                      const SizedBox(height: 8),

                      _input(
                        controller: passConfirmarController,
                        hint: 'repite la contraseña',
                        obscureText: obscurePassConfirmar,
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => obscurePassConfirmar = !obscurePassConfirmar,
                          ),
                          icon: Icon(
                            obscurePassConfirmar
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: TextButton(
                        onPressed: _saving ? null : _guardar,
                        style: TextButton.styleFrom(
                          backgroundColor: _saving ? Colors.grey : primaryBlue,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          _saving ? 'Guardando...' : 'Guardar',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

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

  Widget _label(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(color: primaryBlue, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool obscureText = false,
    Widget? suffixIcon,
    bool readOnly = false,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      obscureText: obscureText,
      readOnly: readOnly,
      enabled: enabled,
      decoration: InputDecoration(
        hintText: hint,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }
}
