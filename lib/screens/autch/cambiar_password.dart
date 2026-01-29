import 'package:flutter/material.dart';
import 'package:awesome_dialog/awesome_dialog.dart';

import '../../repositories/password_reset_repository.dart';
import '../../settings/api_exception.dart';
import '../../settings/session.dart';

class CambiarPassword extends StatefulWidget {
  const CambiarPassword({super.key});

  @override
  State<CambiarPassword> createState() => _CambiarPasswordState();
}

class _CambiarPasswordState extends State<CambiarPassword> {
  static const Color primaryBlue = Color(0xFF2C64C4);

  final formKey = GlobalKey<FormState>();
  final pass1 = TextEditingController();
  final pass2 = TextEditingController();

  bool o1 = true;
  bool o2 = true;

  bool loading = false;
  String? resetId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      resetId = args["reset_id"]?.toString();
    }
  }

  @override
  void dispose() {
    pass1.dispose();
    pass2.dispose();
    super.dispose();
  }

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
        // en reset puede ser token/reset_id inválido o expirado
        await Session.clear();
        if (!mounted) return;
        _dlg(
          "Sesión expirada",
          "Vuelve a enviar el código y repite el proceso.",
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
        // aquí cae 422 (reglas) y otros mensajes del backend
        _dlg("Error", e.message, Icons.help_outline);
        break;
    }
  }

  Future<void> guardar() async {
    if (!formKey.currentState!.validate()) return;

    if (resetId == null || resetId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Falta reset_id (vuelve a enviar el código)'),
        ),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final repo = PasswordResetRepository();
      final resp = await repo.cambiarPassword(
        resetId: resetId!,
        password: pass1.text.trim(),
        password2: pass2.text.trim(),
      );

      if (!mounted) return;

      final detail = (resp["detail"] ?? "Contraseña actualizada ✅").toString();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(detail)));

      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
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

                  const SizedBox(height: 70),

                  const Text(
                    'Cambiar Contraseña',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: primaryBlue,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'Nueva contraseña',
                    style: TextStyle(
                      color: primaryBlue,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: pass1,
                    obscureText: o1,
                    decoration: _inputDecoration(
                      hint: '***************',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => o1 = !o1),
                        icon: Icon(
                          o1 ? Icons.visibility_off : Icons.visibility,
                        ),
                      ),
                    ),
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return 'Requerida';
                      if (value.length < 6) return 'Mínimo 6 caracteres';
                      return null;
                    },
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'Repetir contraseña',
                    style: TextStyle(
                      color: primaryBlue,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: pass2,
                    obscureText: o2,
                    decoration: _inputDecoration(
                      hint: '***************',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => o2 = !o2),
                        icon: Icon(
                          o2 ? Icons.visibility_off : Icons.visibility,
                        ),
                      ),
                    ),
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return 'Requerida';
                      if (value != pass1.text.trim()) return 'No coinciden';
                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  SizedBox(
                    height: 48,
                    child: TextButton(
                      onPressed: loading ? null : guardar,
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
                              'Guardar',
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

  static InputDecoration _inputDecoration({
    required String hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      suffixIcon: suffixIcon,
      hintStyle: const TextStyle(color: Colors.grey),
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
