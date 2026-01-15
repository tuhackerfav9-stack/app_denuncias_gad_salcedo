import 'package:flutter/material.dart';
import '../../repositories/password_reset_repository.dart';

class RecuperarPassword extends StatefulWidget {
  const RecuperarPassword({super.key});

  @override
  State<RecuperarPassword> createState() => _RecuperarPasswordState();
}

class _RecuperarPasswordState extends State<RecuperarPassword> {
  static const Color primaryBlue = Color(0xFF2C64C4);

  final formKey = GlobalKey<FormState>();
  final cedulaController = TextEditingController();
  final correoController = TextEditingController();

  bool loading = false;

  @override
  void dispose() {
    cedulaController.dispose();
    correoController.dispose();
    super.dispose();
  }

  bool _soloNumeros(String s) => RegExp(r'^\d+$').hasMatch(s);

  Future<void> enviarCodigo() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => loading = true);

    try {
      final repo = PasswordResetRepository();

      final resp = await repo.enviarCodigo(
        cedula: cedulaController.text,
        correo: correoController.text,
      );

      if (!mounted) return;

      final detail = (resp["detail"] ?? "Código enviado").toString();
      final resetId = (resp["reset_id"] ?? "").toString();
      final devCodigo = (resp["dev_codigo"] ?? "").toString();

      // Siempre mostramos el detail
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(detail)));

      // Si es DEV, mostramos el código
      if (devCodigo.isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("✅ Código (DEV): $devCodigo")));
      }

      // Si no vino reset_id (por seguridad backend puede devolver 200 sin reset_id)
      if (resetId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Si los datos son correctos, te llegará el código."),
          ),
        );
        return;
      }

      Navigator.pushNamed(
        context,
        '/verificar_codigo',
        arguments: {
          "reset_id": resetId,
          "correo": correoController.text.trim(),
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => loading = false);
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

                  Image.asset(
                    'assets/logo_gad_municipal_letras.png',
                    height: 95,
                    fit: BoxFit.contain,
                  ),

                  const SizedBox(height: 80),

                  const Text(
                    'Recuperar la Contraseña',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: primaryBlue,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 18),

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
                  const SizedBox(height: 18),

                  const Text(
                    'Ingrese su Correo Electronico',
                    style: TextStyle(
                      color: primaryBlue,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),

                  TextFormField(
                    controller: correoController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _inputDecoration(
                      hint: 'ej.rociocarme123@gmail.com',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'El correo es requerido';
                      }
                      final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                      if (!ok.hasMatch(v.trim())) return 'Correo inválido';
                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  SizedBox(
                    height: 48,
                    child: TextButton(
                      onPressed: loading ? null : enviarCodigo,
                      style: TextButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Enviar Codigo',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 70),

                  Image.asset(
                    'assets/logo_gad_municipal_claro animacion.png',
                    height: 120,
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
