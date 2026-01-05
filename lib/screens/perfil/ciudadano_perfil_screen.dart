import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CiudadanoPerfilScreen extends StatefulWidget {
  const CiudadanoPerfilScreen({super.key});

  @override
  State<CiudadanoPerfilScreen> createState() => _CiudadanoPerfilScreenState();
}

class _CiudadanoPerfilScreenState extends State<CiudadanoPerfilScreen> {
  static const Color primaryBlue = Color(0xFF2C64C4);

  final formKey = GlobalKey<FormState>();
  // navegación inferior
  int currentIndex = 0;
  // ====== bottom nav ======
  void _onBottomNavTap(int index) {
    setState(() => currentIndex = index);

    if (index == 0) Navigator.pushNamed(context, '/denuncias');
    if (index == 1) Navigator.pushNamed(context, '/form/denuncias');
    if (index == 2) Navigator.pushNamed(context, '/chatbot');
    if (index == 3) Navigator.pushNamed(context, '/mapadenuncias');
  }

  // Controllers
  final cedulaController = TextEditingController(text: '0500000000');
  final nombresController = TextEditingController(text: 'cristian santiago');
  final apellidosController = TextEditingController(text: 'Alcocer Cando');
  final telefonoController = TextEditingController(text: '0999999999');
  final correoController = TextEditingController(text: 'usuario@correo.com');
  final fechaNacController = TextEditingController(text: '2001-01-01');

  // Password toggle
  bool cambiarContrasena = false;
  final passActualController = TextEditingController();
  final passNuevaController = TextEditingController();
  final passConfirmarController = TextEditingController();

  // Foto
  File? fotoLocal;

  // Para saber si hubo cambios
  late Map<String, String> originalValues;

  @override
  void initState() {
    super.initState();

    originalValues = {
      'cedula': cedulaController.text,
      'nombres': nombresController.text,
      'apellidos': apellidosController.text,
      'telefono': telefonoController.text,
      'correo': correoController.text,
      'fecha': fechaNacController.text,
    };
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

  bool _huboCambios() {
    if (fotoLocal != null) return true;

    return cedulaController.text != originalValues['cedula'] ||
        nombresController.text != originalValues['nombres'] ||
        apellidosController.text != originalValues['apellidos'] ||
        telefonoController.text != originalValues['telefono'] ||
        correoController.text != originalValues['correo'] ||
        fechaNacController.text != originalValues['fecha'] ||
        (cambiarContrasena &&
            (passActualController.text.isNotEmpty ||
                passNuevaController.text.isNotEmpty ||
                passConfirmarController.text.isNotEmpty));
  }

  Future<void> _pickFoto() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x == null) return;
    setState(() => fotoLocal = File(x.path));
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

  void _guardar() {
    if (!formKey.currentState!.validate()) return;

    if (!_huboCambios()) {
      _snack('No hay cambios para guardar');
      return;
    }

    // Validación extra si cambia contraseña
    if (cambiarContrasena) {
      if (passActualController.text.trim().isEmpty) {
        _snack('Ingresa tu contraseña actual');
        return;
      }
      if (passNuevaController.text.trim().length < 6) {
        _snack('La nueva contraseña debe tener mínimo 6 caracteres');
        return;
      }
      if (passNuevaController.text.trim() !=
          passConfirmarController.text.trim()) {
        _snack('La confirmación no coincide');
        return;
      }
    }

    // SOLO UI
    _snack('Datos guardados   (solo frontend)');

    // Actualiza "original" para que ya no marque cambios
    setState(() {
      originalValues = {
        'cedula': cedulaController.text,
        'nombres': nombresController.text,
        'apellidos': apellidosController.text,
        'telefono': telefonoController.text,
        'correo': correoController.text,
        'fecha': fechaNacController.text,
      };
      fotoLocal = null;
      cambiarContrasena = false;
      passActualController.clear();
      passNuevaController.clear();
      passConfirmarController.clear();
    });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // Drawer (Ayuda activo/resaltado)
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 10),
              const ListTile(
                leading: CircleAvatar(child: Icon(Icons.person)),
                title: Text("Ciudadano"),
                subtitle: Text("usuario@correo.com"),
              ),
              const Divider(),

              // ✅ AYUDA ACTIVO (resaltado)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: primaryBlue.withAlpha((0.10 * 255).round()),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  leading: const Icon(Icons.info_outline, color: primaryBlue),
                  title: const Text(
                    "Perfil",
                    style: TextStyle(
                      color: primaryBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    // ya estás en perfil
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
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
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(context, '/');
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
          "Pefil",
          style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w600),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey.shade300,
              child: const Icon(Icons.person, size: 18, color: Colors.black54),
            ),
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
        child: Form(
          key: formKey,
          child: Column(
            children: [
              // FOTO
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey.shade300,
                        image: DecorationImage(
                          image: fotoLocal != null
                              ? FileImage(fotoLocal!)
                              : const AssetImage('assets/profile_dummy.png')
                                    as ImageProvider,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickFoto,
                      child: const Text(
                        "cambiar foto",
                        style: TextStyle(
                          color: primaryBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // CAMPOS
              _label('cedula de identidad'),
              const SizedBox(height: 8),
              _input(
                controller: cedulaController,
                hint: 'ej. 0500000000',
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'La cédula es requerida';
                  }

                  if (v.trim().length < 10) {
                    return 'La cédula debe tener 10 dígitos';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 14),
              _label('nombres'),
              const SizedBox(height: 8),
              _input(
                controller: nombresController,
                hint: 'ej. Cristian Santiago',
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Los nombres son requeridos'
                    : null,
              ),

              const SizedBox(height: 14),
              _label('apellidos'),
              const SizedBox(height: 8),
              _input(
                controller: apellidosController,
                hint: 'ej. Alcocer Cando',
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Los apellidos son requeridos'
                    : null,
              ),

              const SizedBox(height: 14),
              _label('teléfono'),
              const SizedBox(height: 8),
              _input(
                controller: telefonoController,
                hint: 'ej. 0999999999',
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
              _label('correo electrónico'),
              const SizedBox(height: 8),
              _input(
                controller: correoController,
                hint: 'ej. usuario@gmail.com',
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'El correo es requerido';
                  }

                  if (!v.contains('@')) return 'Correo inválido';
                  return null;
                },
              ),

              const SizedBox(height: 14),
              _label('fecha nacimiento'),
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
                    onChanged: (v) =>
                        setState(() => cambiarContrasena = v ?? false),
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
                _label('contraseña actual'),
                const SizedBox(height: 8),
                _input(
                  controller: passActualController,
                  hint: '••••••••',
                  obscureText: true,
                ),

                const SizedBox(height: 14),
                _label('nueva contraseña'),
                const SizedBox(height: 8),
                _input(
                  controller: passNuevaController,
                  hint: 'mínimo 6 caracteres',
                  obscureText: true,
                ),

                const SizedBox(height: 14),
                _label('confirmar contraseña'),
                const SizedBox(height: 8),
                _input(
                  controller: passConfirmarController,
                  hint: 'repite la contraseña',
                  obscureText: true,
                ),
              ],

              const SizedBox(height: 20),

              // GUARDAR
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: _guardar,
                  style: TextButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    'Guardar',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // bottom nav con navegación real
      bottomNavigationBar: BottomNavigationBar(
        currentIndex:
            0, // ayuda NO está en bottom nav, entonces deja inicio fijo o maneja como quieras
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
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      obscureText: obscureText,
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
