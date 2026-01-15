import 'package:flutter/material.dart';
import '../../repositories/register_repository.dart';

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

  @override
  void dispose() {
    cedulaController.dispose();
    nombresController.dispose();
    apellidosController.dispose();
    telefonoController.dispose();
    super.dispose();
  }

  bool _soloNumeros(String s) => RegExp(r'^\d+$').hasMatch(s);

  Future<void> continuar() async {
    if (!formKey.currentState!.validate()) return;

    final repo = RegisterRepository();

    try {
      // loading simple (sin cambiar tu estilo)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Guardando datos...')));

      final uid = await repo.paso1(
        cedula: cedulaController.text,
        nombres: nombresController.text,
        apellidos: apellidosController.text,
        telefono: telefonoController.text,
      );

      if (!mounted) return;

      // Siguiente pantalla: mandamos UID y (si quieres) los datos
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
    }
  }

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

                  // LOGO ARRIBA
                  Image.asset(
                    'assets/logo_gad_municipal_letras.png',
                    height: 95,
                    fit: BoxFit.contain,
                  ),

                  const SizedBox(height: 24),

                  // Cédula
                  const Text(
                    'Cédula de identidad',
                    style: TextStyle(
                      color: primaryBlue,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: cedulaController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration(hint: 'ej.1234567890'),
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return 'La cédula es requerida';
                      if (!_soloNumeros(value)) return 'Solo números';
                      if (value.length != 10) return 'Debe tener 10 dígitos';
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Nombres
                  const Text(
                    'Nombres',
                    style: TextStyle(
                      color: primaryBlue,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: nombresController,
                    decoration: _inputDecoration(hint: 'ej.Juan Santiago'),
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return 'Los nombres son requeridos';
                      if (value.length < 2) return 'Muy corto';
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Apellidos
                  const Text(
                    'Apellidos',
                    style: TextStyle(
                      color: primaryBlue,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: apellidosController,
                    decoration: _inputDecoration(hint: 'ej. Alcocer Cando'),
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return 'Los apellidos son requeridos';
                      if (value.length < 2) return 'Muy corto';
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Teléfono
                  const Text(
                    'Teléfono',
                    style: TextStyle(
                      color: primaryBlue,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: telefonoController,
                    keyboardType: TextInputType.phone,
                    decoration: _inputDecoration(hint: 'ej.0900000000'),
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return 'El teléfono es requerido';
                      if (!_soloNumeros(value)) return 'Solo números';
                      if (value.length < 9) return 'Teléfono inválido';
                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  // Botón Registrarme
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: continuar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
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

                  // Ilustración abajo
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

  static InputDecoration _inputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade500),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: primaryBlue, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 1.2),
      ),
    );
  }
}
