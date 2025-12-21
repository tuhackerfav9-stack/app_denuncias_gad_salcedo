import 'package:flutter/material.dart';

class Register3 extends StatefulWidget {
  const Register3({super.key});

  @override
  State<Register3> createState() => _Register3State();
}

class _Register3State extends State<Register3> {
  static const Color primaryBlue = Color(0xFF2C64C4);

  final formKey = GlobalKey<FormState>();

  final ddController = TextEditingController();
  final mmController = TextEditingController();
  final yyyyController = TextEditingController();

  @override
  void dispose() {
    ddController.dispose();
    mmController.dispose();
    yyyyController.dispose();
    super.dispose();
  }

  bool _fechaValida(int d, int m, int y) {
    try {
      final date = DateTime(y, m, d);
      return date.year == y && date.month == m && date.day == d;
    } catch (_) {
      return false;
    }
  }

  void continuar() {
    final ok = formKey.currentState!.validate();
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revisa la fecha (DD/MM/YYYY)')),
      );
      return;
    }

    final dd = int.parse(ddController.text.trim());
    final mm = int.parse(mmController.text.trim());
    final yyyy = int.parse(yyyyController.text.trim());

    if (!_fechaValida(dd, mm, yyyy)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fecha inválida. Ej: 05/09/2002')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Fecha válida   ${ddController.text}/${mmController.text}/${yyyyController.text}',
        ),
      ),
    );

    //   navegar a register4
    Navigator.pushNamed(context, '/register4');
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
                    'Fecha de Nacimiento',
                    style: TextStyle(
                      color: primaryBlue,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: ddController,
                          keyboardType: TextInputType.number,
                          maxLength: 2,
                          decoration: _smallInputDecoration(hint: 'DD'),
                          validator: (v) {
                            final value = (v ?? '').trim();
                            if (value.isEmpty) return ' dia';
                            final n = int.tryParse(value);
                            if (n == null) return 'Solo números';
                            if (n < 1 || n > 31) return '1 - 31';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: mmController,
                          keyboardType: TextInputType.number,
                          maxLength: 2,
                          decoration: _smallInputDecoration(hint: 'MM'),
                          validator: (v) {
                            final value = (v ?? '').trim();
                            if (value.isEmpty) return ' mes';
                            final n = int.tryParse(value);
                            if (n == null) return 'Solo números';
                            if (n < 1 || n > 12) return '1 - 12';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: yyyyController,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          decoration: _smallInputDecoration(hint: 'YYYY'),
                          validator: (v) {
                            final value = (v ?? '').trim();
                            if (value.isEmpty) return ' año';
                            final n = int.tryParse(value);
                            if (n == null) return 'Solo números';
                            final yearNow = DateTime.now().year;
                            if (n < 1900 || n > yearNow) {
                              return '1900 - $yearNow';
                            }

                            return null;
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  //   Mensaje de ayuda (se ve bonito y evita confusión)
                  Text(
                    'Ejemplo: 05 / 09 / 2002',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),

                  const SizedBox(height: 14),

                  SizedBox(
                    height: 48,
                    child: TextButton(
                      onPressed: continuar,
                      style: TextButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Continuar',
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

                  const SizedBox(height: 90),

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

  static InputDecoration _smallInputDecoration({required String hint}) {
    return InputDecoration(
      counterText: '',
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade600),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
