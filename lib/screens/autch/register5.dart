import 'package:flutter/material.dart';
import 'package:awesome_dialog/awesome_dialog.dart';

import '../../repositories/register_repository.dart';
import '../../settings/api_exception.dart';
import '../../settings/session.dart';

class Register5 extends StatefulWidget {
  const Register5({super.key});

  @override
  State<Register5> createState() => _Register5State();
}

class _Register5State extends State<Register5> {
  static const Color primaryBlue = Color(0xFF2C64C4);

  final formKey = GlobalKey<FormState>();

  final passController = TextEditingController();
  final pass2Controller = TextEditingController();

  bool aceptarTerminos = false;
  bool ocultar1 = true;
  bool ocultar2 = true;

  bool _loading = false;
  String? _uid;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final uid = args["uid"]?.toString();
      if (uid != null && uid.isNotEmpty) _uid = uid;
    }
  }

  @override
  void dispose() {
    passController.dispose();
    pass2Controller.dispose();
    super.dispose();
  }

  // =========================
  // DIALOGOS PRO (mismo estilo)
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

  Future<void> _handleApiError(ApiException e) async {
    if (!mounted) return;

    switch (e.type) {
      case ApiErrorType.network:
        _dlgError("Sin conexión", "Revisa tu conexión a internet.");
        break;

      case ApiErrorType.timeout:
        _dlgError(
          "Tiempo agotado",
          "El servidor no respondió. Intenta nuevamente.",
        );
        break;

      case ApiErrorType.unauthorized:
        await Session.clear();
        if (!mounted) return;
        _dlgInfo(
          "Sesión expirada",
          "Tu sesión no es válida. Inicia sesión nuevamente.",
        );
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
  }

  Future<void> iniciar() async {
    if (!formKey.currentState!.validate()) return;

    if (!aceptarTerminos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes aceptar los Términos y la Política'),
        ),
      );
      return;
    }

    if (_uid == null || _uid!.isEmpty) {
      _dlgError("Error", "No se encontró el uid del registro.");
      return;
    }

    setState(() => _loading = true);

    try {
      final repo = RegisterRepository();

      final resp = await repo.finalizar(
        uid: _uid!,
        password: passController.text.trim(),
      );

      if (!mounted) return;

      final detail = (resp["detail"] ?? "Registro completo ✅").toString();

      // éxito: mantenemos SnackBar como tú lo tenías
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(detail)));

      // volver a login
      Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
    } on ApiException catch (e) {
      await _handleApiError(e);
    } catch (e) {
      if (!mounted) return;
      _dlgError("Error inesperado", e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
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
                    'Contraseña',
                    style: TextStyle(
                      color: primaryBlue,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: passController,
                    obscureText: ocultar1,
                    decoration: _inputDecoration(
                      hint: '***************',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => ocultar1 = !ocultar1),
                        icon: Icon(
                          ocultar1 ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return 'La contraseña es requerida';
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
                    controller: pass2Controller,
                    obscureText: ocultar2,
                    decoration: _inputDecoration(
                      hint: '***************',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => ocultar2 = !ocultar2),
                        icon: Icon(
                          ocultar2 ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return 'Repite la contraseña';
                      if (value != passController.text.trim()) {
                        return 'Las contraseñas no coinciden';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 10),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: aceptarTerminos,
                        activeColor: primaryBlue,
                        onChanged: _loading
                            ? null
                            : (v) =>
                                  setState(() => aceptarTerminos = v ?? false),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text.rich(
                            TextSpan(
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 11.5,
                              ),
                              children: const [
                                TextSpan(
                                  text: 'Al hacer clic, aceptas nuestros ',
                                ),
                                TextSpan(
                                  text: 'Términos de Servicio',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextSpan(text: '\ny nuestra '),
                                TextSpan(
                                  text: 'Política de Privacidad',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  SizedBox(
                    height: 48,
                    child: TextButton(
                      onPressed: _loading ? null : iniciar,
                      style: TextButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Iniciar',
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
      hintStyle: TextStyle(color: Colors.grey.shade500),
      suffixIcon: suffixIcon,
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
