import 'package:flutter/material.dart';
import 'package:awesome_dialog/awesome_dialog.dart';

import '../../repositories/password_reset_repository.dart';
import '../../settings/api_exception.dart';
import '../../settings/session.dart';

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

  // =========================
  // DIALOGOS PRO (mismo estilo/paleta)
  // =========================
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

  void _dlg(String title, String desc, IconData icon) {
    AwesomeDialog(
      context: context,
      animType: AnimType.scale,
      title: title,
      desc: desc,
      btnOkText: "Ok",
      btnOkColor: primaryBlue,
      btnOkOnPress: () {},
      customHeader: _header(icon),
    ).show();
  }

  Future<void> _handleApiError(ApiException e) async {
    if (!mounted) return;

    switch (e.type) {
      case ApiErrorType.network:
        _dlg("Sin conexión", "Revisa tu conexión a internet.", Icons.wifi_off);
        break;

      case ApiErrorType.timeout:
        _dlg(
          "Tiempo agotado",
          "El servidor no respondió. Intenta nuevamente.",
          Icons.access_time,
        );
        break;

      case ApiErrorType.unauthorized:
        await Session.clear();
        if (!mounted) return;
        _dlg(
          "Sesión expirada",
          "Tu sesión no es válida. Inicia sesión nuevamente.",
          Icons.lock_outline,
        );
        Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
        break;

      case ApiErrorType.forbidden:
        _dlg("Acceso denegado", e.message, Icons.block);
        break;

      case ApiErrorType.server:
        _dlg(
          "Servidor no disponible",
          "Intenta nuevamente más tarde.",
          Icons.cloud_off,
        );
        break;

      case ApiErrorType.unknown:
        _dlg("Error", e.message, Icons.help_outline);
        break;
    }
  }

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

      // Siempre mostramos el detail (igual que antes)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(detail)));

      // Si es DEV, mostramos el código (igual que antes)
      if (devCodigo.isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("✅ Código (DEV): $devCodigo")));
      }

      // Si no vino reset_id (igual que antes)
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
    } on ApiException catch (e) {
      await _handleApiError(e);
    } catch (e) {
      if (!mounted) return;
      _dlg("Error inesperado", e.toString(), Icons.help_outline);
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
