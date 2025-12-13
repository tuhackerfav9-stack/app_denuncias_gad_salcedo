import 'package:flutter/material.dart';

class Login extends StatelessWidget {
  const Login({super.key});

  static const Color primaryBlue = Color(0xFF2C64C4);

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

                // LOGO (SALCEDO GAD MUNICIPAL)
                Image.asset(
                  'assets/logo_gad_municipal_letras.png',
                  height: 95,
                  fit: BoxFit.contain,
                ),

                const SizedBox(height: 18),

                // ILUSTRACIÓN (iglesia / línea)
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
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'email@domain.com',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
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
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: '**********',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
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
                ),

                const SizedBox(height: 22),

                // BOTÓN
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      // Solo frontend: aquí luego conectas tu lógica
                    },
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
                        // Navegación a register (luego lo conectas)
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

                // Línea separadora suave
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
    );
  }
}
