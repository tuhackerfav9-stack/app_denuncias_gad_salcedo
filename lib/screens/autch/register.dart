import 'package:flutter/material.dart';

class Register extends StatelessWidget {
  const Register({super.key});

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

                // LOGO ARRIBA
                Image.asset(
                  'assets/logo_gad_municipal_letras.png',
                  height: 95,
                  fit: BoxFit.contain,
                ),

                const SizedBox(height: 24),

                // Cédula
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
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration(hint: 'ej.1234567890'),
                ),

                const SizedBox(height: 16),

                // Nombres
                const Text(
                  'Nombres',
                  style: TextStyle(
                    color: primaryBlue,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  decoration: _inputDecoration(hint: 'ej.Juan Santiago'),
                ),

                const SizedBox(height: 16),

                // Apellidos
                const Text(
                  'Apellidos',
                  style: TextStyle(
                    color: primaryBlue,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  decoration: _inputDecoration(hint: 'ej. Alcocer Cando'),
                ),

                const SizedBox(height: 16),

                // Teléfono
                const Text(
                  'Teléfono',
                  style: TextStyle(
                    color: primaryBlue,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  keyboardType: TextInputType.phone,
                  decoration: _inputDecoration(hint: 'ej.0900000000'),
                ),

                const SizedBox(height: 14),

                // Checkbox + texto
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // OJO: como esto es Stateless, dejo el checkbox “solo UI”
                    // (si quieres que funcione, lo hacemos Stateful en 2 min)
                    Transform.scale(
                      scale: 1.1,
                      child: Checkbox(
                        value: true,
                        onChanged: (v) {},
                        activeColor: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 12,
                          ),
                          children: const [
                            TextSpan(text: 'Al hacer clic, aceptas nuestros '),
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
                  ],
                ),

                const SizedBox(height: 16),

                // Botón Registrarme
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Registrarme',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                // Ilustración abajo
                Image.asset(
                  'assets/logo_gad_municipal_claro animacion.png',
                  height: 110,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Decoración reutilizable para que todos los inputs se vean iguales
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
    );
  }
}
