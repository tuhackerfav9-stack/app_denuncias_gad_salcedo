import 'package:flutter/material.dart';

// Ajusta el import según tu estructura
import '../../repositories/register_repository.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: no se encontró el uid del registro.'),
        ),
      );
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

      // resp puede traer {detail, usuario_id}
      final detail = (resp["detail"] ?? "Registro completo ✅").toString();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(detail)));

      // Recomendado: volver a Login para iniciar sesión ya con correo/password
      Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);

      // Si tú quieres mandarlo directo a denuncias, haz esto:
      // Navigator.pushNamedAndRemoveUntil(context, '/denuncias', (r) => false);
      // (pero recuerda: aun no hay login automático, así que SessionGuard te puede sacar)
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
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
