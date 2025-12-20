import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class Register4 extends StatefulWidget {
  const Register4({super.key});

  @override
  State<Register4> createState() => _Register4State();
}

class _Register4State extends State<Register4> {
  static const Color primaryBlue = Color(0xFF2C64C4);

  File? cedulaFrontal;
  File? cedulaTrasera;

  final ImagePicker picker = ImagePicker();

  Future<void> _pickFrontal() async {
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x == null) return;
    setState(() => cedulaFrontal = File(x.path));
  }

  Future<void> _pickTrasera() async {
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x == null) return;
    setState(() => cedulaTrasera = File(x.path));
  }

  void subir() {
    if (cedulaFrontal == null || cedulaTrasera == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sube la parte frontal y trasera ✅')),
      );
      return;
    }

    // ✅ Aquí luego conectas: subir a storage / backend
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cédula lista ✅ (solo frontend)')),
    );

    // Ejemplo navegación:
    // Navigator.pushNamed(context, '/register5');
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

                // LOGO ARRIBA
                Image.asset(
                  'assets/logo_gad_municipal_letras.png',
                  height: 95,
                  fit: BoxFit.contain,
                ),

                const SizedBox(height: 70),

                // TITULO
                const Text(
                  'Subir cédula',
                  style: TextStyle(
                    color: primaryBlue,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 12),

                // CARD FRONTAL
                _CedulaCard(
                  title: 'Cédula',
                  subtitle: 'Parte frontal',
                  file: cedulaFrontal,
                  onTap: _pickFrontal,
                  onRemove: () => setState(() => cedulaFrontal = null),
                ),

                const SizedBox(height: 12),

                // CARD TRASERA
                _CedulaCard(
                  title: 'Cédula',
                  subtitle: 'Parte trasera',
                  file: cedulaTrasera,
                  onTap: _pickTrasera,
                  onRemove: () => setState(() => cedulaTrasera = null),
                ),

                const SizedBox(height: 14),

                // BOTÓN SUBIR
                SizedBox(
                  height: 48,
                  child: TextButton(
                    onPressed: subir,
                    style: TextButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'subir',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // TÉRMINOS
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

                // IMAGEN ABAJO
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

// ====== WIDGET CARD ======

class _CedulaCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final File? file;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _CedulaCard({
    required this.title,
    required this.subtitle,
    required this.file,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
          color: Colors.white,
        ),
        child: Row(
          children: [
            // Preview
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.grey.shade200,
                image: file != null
                    ? DecorationImage(
                        image: FileImage(file!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: file == null
                  ? const Icon(Icons.credit_card, color: Colors.black54)
                  : null,
            ),
            const SizedBox(width: 12),

            // Textos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12.5,
                    ),
                  ),
                  if (file != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      file!.path.split('/').last,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Remove (si ya hay imagen)
            if (file != null)
              IconButton(onPressed: onRemove, icon: const Icon(Icons.close)),
          ],
        ),
      ),
    );
  }
}
