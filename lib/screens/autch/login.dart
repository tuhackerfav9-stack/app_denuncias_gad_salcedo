import 'package:flutter/material.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  static const Color primaryBlue = Color(0xFF2C64C4);

  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passController = TextEditingController();

  bool obscurePass = true;

  @override
  void dispose() {
    emailController.dispose();
    passController.dispose();
    super.dispose();
  }

  void _continuar() {
    if (!formKey.currentState!.validate()) return;

    //   Solo frontend: aquí luego conectas supabase o tu backend
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Login válido   (solo frontend)')),
    );

    // Ejemplo: ir a denuncias
    Navigator.pushReplacementNamed(context, '/denuncias');
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

                  // LOGO
                  Image.asset(
                    'assets/logo_gad_municipal_letras.png',
                    height: 95,
                    fit: BoxFit.contain,
                  ),

                  const SizedBox(height: 18),

                  // ILUSTRACIÓN
                  Image.asset(
                    'assets/logo_gad_municipal_claro animacion.png',
                    height: 110,
                    fit: BoxFit.contain,
                  ),

                  const SizedBox(height: 28),

                  // LABEL: usuario
                  const Text(
                    'usuario',
                    style: TextStyle(
                      color: primaryBlue,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // INPUT: email
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _inputDecoration(hint: 'email@domain.com'),
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return 'El correo es requerido';
                      final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                      if (!ok.hasMatch(value)) {
                        return 'Ingresa un correo válido';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 18),

                  // LABEL: contraseña
                  const Text(
                    'contraseña',
                    style: TextStyle(
                      color: primaryBlue,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // INPUT: password
                  TextFormField(
                    controller: passController,
                    obscureText: obscurePass,
                    decoration: _inputDecoration(
                      hint: '**********',
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => obscurePass = !obscurePass),
                        icon: Icon(
                          obscurePass ? Icons.visibility_off : Icons.visibility,
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

                  const SizedBox(height: 10),

                  // olvidaste contraseña
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, '/recuperar_password');
                      },
                      child: const Text(
                        'Te olvidaste la contraseña',
                        style: TextStyle(
                          color: Color.fromARGB(255, 97, 97, 97),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // BOTÓN
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _continuar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Continuar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ¿No tienes cuenta? Registrarse
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '¿No tienes una cuenta? ',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, '/register');
                        },
                        child: const Text(
                          'Registrarse',
                          style: TextStyle(
                            color: primaryBlue,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Divider(color: Colors.grey.shade200, height: 24),

                  const SizedBox(height: 10),

                  // Términos y Privacidad
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

                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      suffixIcon: suffixIcon,
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
