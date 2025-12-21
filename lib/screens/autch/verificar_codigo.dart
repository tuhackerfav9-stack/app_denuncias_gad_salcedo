import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    // Solo 1 dígito
    if (value.length > 1) {
      controllers[index].text = value.substring(value.length - 1);
      controllers[index].selection = TextSelection.fromPosition(
        const TextPosition(offset: 1),
      );
    }

    // Avanza al siguiente
    if (controllers[index].text.isNotEmpty && index < 5) {
      focusNodes[index + 1].requestFocus();
    }
  }

  void _onBackspace(int index, KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey.keyLabel != 'Backspace') return;

    // Si está vacío, vuelve al anterior
    if (controllers[index].text.isEmpty && index > 0) {
      focusNodes[index - 1].requestFocus();
      controllers[index - 1].clear();
    }
  }

  void verificarCuenta() {
    if (codigo.length != 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ingresa los 6 dígitos ✅')));
      return;
    }

    // ✅ Solo frontend
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Código verificado ✅ (solo frontend)')),
    );

    Navigator.pushNamed(context, '/cambiar_password');
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

                // Logo
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

                // 6 cajas
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (i) {
                    return SizedBox(
                      width: 45,
                      child: KeyboardListener(
                        focusNode: FocusNode(), // listener aparte
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
                    onPressed: verificarCuenta,
                    style: TextButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Verificar Cuenta',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Términos
                Text.rich(
                  TextSpan(
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 11.5,
                    ),
                    children: const [
                      TextSpan(
                        text: 'Al hacer clic en continuar, aceptas nuestros ',
                      ),
                      TextSpan(
                        text: 'Términos de\nServicio',
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(text: ' y nuestra '),
                      TextSpan(
                        text: 'Política de Privacidad',
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 70),

                // Imagen abajo
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
