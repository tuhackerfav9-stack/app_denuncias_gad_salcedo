import 'package:flutter/material.dart';
import 'package:awesome_dialog/awesome_dialog.dart';

import '../../repositories/register_repository.dart';
import '../../settings/api_exception.dart';
import '../../settings/session.dart';

class Register extends StatefulWidget {
  const Register({super.key});

  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  static const Color primaryBlue = Color(0xFF2C64C4);

  final formKey = GlobalKey<FormState>();

  final cedulaController = TextEditingController();
  final nombresController = TextEditingController();
  final apellidosController = TextEditingController();
  final telefonoController = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    cedulaController.dispose();
    nombresController.dispose();
    apellidosController.dispose();
    telefonoController.dispose();
    super.dispose();
  }

  bool _soloNumeros(String s) => RegExp(r'^\d+$').hasMatch(s);

  // Validación cédula ecuatoriana
  bool _cedulaEcuatorianaValida(String cedula) {
    if (cedula.length != 10) return false;
    if (!_soloNumeros(cedula)) return false;

    final prov = int.parse(cedula.substring(0, 2));
    if (prov < 1 || prov > 24) return false;

    final tercer = int.parse(cedula[2]);
    if (tercer < 0 || tercer > 5) return false;

    final digits = cedula.split('').map(int.parse).toList();

    int suma = 0;
    for (int i = 0; i < 9; i++) {
      int val = digits[i];
      if (i % 2 == 0) {
        val *= 2;
        if (val > 9) val -= 9;
      }
      suma += val;
    }

    final mod = suma % 10;
    final verificador = mod == 0 ? 0 : 10 - mod;
    return verificador == digits[9];
  }

  // =========================
  // DIALOGOS PRO
  // =========================
  void _dlgInfo(String title, String desc) {
    AwesomeDialog(
      context: context,
      animType: AnimType.scale,
      title: title,
      desc: desc,
      btnOkText: "Ok",
      btnOkColor: primaryBlue,
      btnOkOnPress: () {},
      customHeader: _header(Icons.info_outline),
    ).show();
  }

  void _dlgError(String title, String desc) {
    AwesomeDialog(
      context: context,
      animType: AnimType.scale,
      title: title,
      desc: desc,
      btnOkText: "Entendido",
      btnOkColor: primaryBlue,
      btnOkOnPress: () {},
      customHeader: _header(Icons.error_outline),
    ).show();
  }

  Widget _header(IconData icon) {
    return Container(
      width: 70,
      height: 70,
      decoration: const BoxDecoration(
        color: primaryBlue,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 36),
    );
  }

  // =========================
  // CONTINUAR
  // =========================
  Future<void> continuar() async {
    if (!formKey.currentState!.validate()) return;
    if (_loading) return;

    setState(() => _loading = true);

    final repo = RegisterRepository();

    try {
      final uid = await repo.paso1(
        cedula: cedulaController.text.trim(),
        nombres: nombresController.text.trim(),
        apellidos: apellidosController.text.trim(),
        telefono: telefonoController.text.trim(),
      );

      if (!mounted) return;

      Navigator.pushNamed(
        context,
        '/register2',
        arguments: {
          'uid': uid,
          'cedula': cedulaController.text.trim(),
          'nombres': nombresController.text.trim(),
          'apellidos': apellidosController.text.trim(),
          'telefono': telefonoController.text.trim(),
        },
      );
    } on ApiException catch (e) {
      if (!mounted) return;

      switch (e.type) {
        case ApiErrorType.network:
          _dlgError("Sin conexión", "Revisa tu conexión a internet.");
          break;

        case ApiErrorType.timeout:
          _dlgError("Tiempo agotado", "El servidor no respondió a tiempo.");
          break;

        case ApiErrorType.unauthorized:
          await Session.clear();
          if (!mounted) return;

          _dlgInfo(
            "Sesión inválida",
            "Tu sesión no es válida. Inicia nuevamente.",
          );

          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
          break;

        case ApiErrorType.forbidden:
          _dlgError("Acceso denegado", e.message);
          break;

        case ApiErrorType.server:
          _dlgError("Servidor no disponible", "Intenta nuevamente más tarde.");
          break;

        case ApiErrorType.unknown:
          _dlgError("Error", e.message);
          break;
      }
    } catch (e) {
      if (!mounted) return;
      _dlgError("Error inesperado", e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),

                  Image.asset(
                    'assets/logo_gad_municipal_letras.png',
                    height: 95,
                    fit: BoxFit.contain,
                  ),

                  const SizedBox(height: 24),

                  _label('Cédula de identidad'),
                  _input(
                    controller: cedulaController,
                    hint: 'ej.1234567890',
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return 'La cédula es requerida';
                      if (!_soloNumeros(value)) return 'Solo números';
                      if (value.length != 10) return 'Debe tener 10 dígitos';
                      if (!_cedulaEcuatorianaValida(value)) {
                        return 'Cédula ecuatoriana inválida';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  _label('Nombres'),
                  _input(
                    controller: nombresController,
                    hint: 'ej. Juan Santiago',
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Los nombres son requeridos'
                        : null,
                  ),

                  const SizedBox(height: 16),

                  _label('Apellidos'),
                  _input(
                    controller: apellidosController,
                    hint: 'ej. Alcocer Cando',
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Los apellidos son requeridos'
                        : null,
                  ),

                  const SizedBox(height: 16),

                  _label('Teléfono'),
                  _input(
                    controller: telefonoController,
                    hint: 'ej. 0900000000',
                    keyboardType: TextInputType.phone,
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return 'El teléfono es requerido';
                      if (!_soloNumeros(value)) return 'Solo números';
                      if (value.length < 9) return 'Teléfono inválido';
                      return null;
                    },
                  ),

                  const SizedBox(height: 18),

                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _loading ? null : continuar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _loading
                          ? const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            )
                          : const Text(
                              'Registrarme',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  Image.asset(
                    'assets/logo_gad_municipal_claro animacion.png',
                    height: 110,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: primaryBlue,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
