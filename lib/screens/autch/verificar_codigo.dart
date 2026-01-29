import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:awesome_dialog/awesome_dialog.dart';

import '../../repositories/password_reset_repository.dart';
import '../../settings/api_exception.dart';
import '../../settings/session.dart';

class VerificarCodigo extends StatefulWidget {
  const VerificarCodigo({super.key});

  @override
  State<VerificarCodigo> createState() => _VerificarCodigoState();
}

class _VerificarCodigoState extends State<VerificarCodigo> {
  static const Color primaryBlue = Color(0xFF2C64C4);

  final List<TextEditingController> controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> focusNodes = List.generate(6, (_) => FocusNode());

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
    for (final c in controllers) {
      c.dispose();
    }
    for (final f in focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get codigo => controllers.map((c) => c.text.trim()).join();

  void _onChanged(int index, String value) {
    if (value.length > 1) {
      controllers[index].text = value.substring(value.length - 1);
      controllers[index].selection = const TextSelection.collapsed(offset: 1);
    }
    if (controllers[index].text.isNotEmpty && index < 5) {
      focusNodes[index + 1].requestFocus();
    }
  }

  void _onBackspace(int index, KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey.keyLabel != 'Backspace') return;

    if (controllers[index].text.isEmpty && index > 0) {
      focusNodes[index - 1].requestFocus();
      controllers[index - 1].clear();
    }
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

  Future<void> verificarCuenta() async {
    if (resetId == null || resetId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Falta reset_id (vuelve a enviar el código)'),
        ),
      );
      return;
    }

    if (codigo.length != 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ingresa los 6 dígitos ✅')));
      return;
    }

    setState(() => loading = true);

    try {
      final repo = PasswordResetRepository();
      await repo.verificarCodigo(resetId: resetId!, codigo6: codigo);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Código verificado ✅')));

      Navigator.pushNamed(
        context,
        '/cambiar_password',
        arguments: {"reset_id": resetId},
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),

                Image.asset(
                  'assets/logo_gad_municipal_letras.png',
                  height: 95,
                  fit: BoxFit.contain,
                ),

                const SizedBox(height: 90),

                const Text(
                  'Recuperar la Contraseña',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: primaryBlue,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 22),

                const Text(
                  'Codigo',
                  style: TextStyle(
                    color: primaryBlue,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (i) {
                    return SizedBox(
                      width: 45,
                      child: KeyboardListener(
                        focusNode: FocusNode(),
                        onKeyEvent: (e) => _onBackspace(i, e),
                        child: TextField(
                          controller: controllers[i],
                          focusNode: focusNodes[i],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 1,
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: primaryBlue,
                                width: 1.4,
                              ),
                            ),
                          ),
                          onChanged: (v) => _onChanged(i, v),
                        ),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  height: 48,
                  child: TextButton(
                    onPressed: loading ? null : verificarCuenta,
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
                            'Verificar Cuenta',
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
    );
  }
}
