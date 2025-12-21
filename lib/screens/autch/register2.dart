import 'package:flutter/material.dart';

class Register2 extends StatefulWidget {
  const Register2({super.key});

  @override
  State<Register2> createState() => _Register2State();
}

class _Register2State extends State<Register2> {
  static const Color primaryBlue = Color(0xFF2C64C4);

  final formKey = GlobalKey<FormState>();
  final correoController = TextEditingController();

  @override
  void dispose() {
    correoController.dispose();
    super.dispose();
  }

  Future<void> verificarCorreo() async {
    if (!formKey.currentState!.validate()) return;

    //   Solo frontend: simular envío
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Código enviado  (solo frontend)')),
    );

    final ok = await _mostrarDialogOTP();

    if (ok == true && mounted) {
      Navigator.pushNamed(context, '/register3');
    }
  }

  Future<bool?> _mostrarDialogOTP() async {
    final controllers = List.generate(6, (_) => TextEditingController());
    final focusNodes = List.generate(6, (_) => FocusNode());

    String getCodigo() => controllers.map((c) => c.text.trim()).join();

    bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        void onChanged(int index, String value) {
          // Solo 1 dígito
          if (value.length > 1) {
            controllers[index].text = value.substring(value.length - 1);
            controllers[index].selection = const TextSelection.collapsed(
              offset: 1,
            );
          }

          // Avanza al siguiente
          if (controllers[index].text.isNotEmpty && index < 5) {
            focusNodes[index + 1].requestFocus();
          }
        }

        void verificar() {
          final code = getCodigo();
          if (code.length != 6) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ingresa los 6 dígitos')),
            );
            return;
          }

          Navigator.pop(ctx, true);
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Verificar correo',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: primaryBlue,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Codigo',
                  style: TextStyle(
                    color: primaryBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (i) {
                    return SizedBox(
                      width: 40,
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
                            vertical: 12,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: primaryBlue,
                              width: 1.4,
                            ),
                          ),
                        ),
                        onChanged: (v) => onChanged(i, v),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  height: 44,
                  child: TextButton(
                    onPressed: verificar,
                    style: TextButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Verificar Cuenta',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );

    //   limpiar memoria
    for (final c in controllers) {
      c.dispose();
    }
    for (final f in focusNodes) {
      f.dispose();
    }

    return result;
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
                    'Correo Electrónico',
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
                    decoration: _inputDecoration(hint: 'ej.juancasa@gmail.com'),
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return 'El correo es requerido';
                      final emailOk = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                      if (!emailOk.hasMatch(value)) {
                        return 'Ingresa un correo válido';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  SizedBox(
                    height: 48,
                    child: TextButton(
                      onPressed: verificarCorreo,
                      style: TextButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Verificar Correo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

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
