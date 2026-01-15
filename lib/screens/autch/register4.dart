import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// Ajusta el import según tu estructura
import '../../repositories/register_repository.dart';

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

  bool _subiendo = false;
  String? _uid;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    //  Recupera el uid del borrador desde argumentos
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final uid = args["uid"]?.toString();
      if (uid != null && uid.isNotEmpty) {
        _uid = uid;
      }
    }
  }

  Future<ImageSource?> _elegirFuente() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 6),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Galería'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera),
                  title: const Text('Cámara'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickFrontal() async {
    final source = await _elegirFuente();
    if (source == null) return;

    final x = await picker.pickImage(source: source, imageQuality: 85);
    if (x == null) return;
    setState(() => cedulaFrontal = File(x.path));
  }

  Future<void> _pickTrasera() async {
    final source = await _elegirFuente();
    if (source == null) return;

    final x = await picker.pickImage(source: source, imageQuality: 85);
    if (x == null) return;
    setState(() => cedulaTrasera = File(x.path));
  }

  Future<void> subir() async {
    // 1) Validaciones
    if (_uid == null || _uid!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: no se encontró el uid del registro.'),
        ),
      );
      return;
    }

    if (cedulaFrontal == null || cedulaTrasera == null) {
      final faltan = <String>[];
      if (cedulaFrontal == null) faltan.add('frontal');
      if (cedulaTrasera == null) faltan.add('trasera');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falta subir la parte: ${faltan.join(' y ')}')),
      );
      return;
    }

    // 2) Subida real
    setState(() => _subiendo = true);

    try {
      final repo = RegisterRepository();

      await repo.subirDocumentos(
        uid: _uid!,
        cedulaFrontal: cedulaFrontal!,
        cedulaTrasera: cedulaTrasera!,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Documentos guardados ✅')));

      // Mantén el uid para el paso 5
      Navigator.pushNamed(context, '/register5', arguments: {"uid": _uid});
    } catch (e) {
      if (!mounted) return;

      // Si tu repo lanza Exception con "detail", aquí se mostrará el mensaje del backend
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _subiendo = false);
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

                const SizedBox(height: 70),

                const Text(
                  'Subir cédula',
                  style: TextStyle(
                    color: primaryBlue,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 12),

                _CedulaCard(
                  title: 'Cédula',
                  subtitle: 'Parte frontal',
                  file: cedulaFrontal,
                  onTap: _subiendo ? () {} : _pickFrontal,
                  onRemove: _subiendo
                      ? () {}
                      : () => setState(() => cedulaFrontal = null),
                ),

                const SizedBox(height: 12),

                _CedulaCard(
                  title: 'Cédula',
                  subtitle: 'Parte trasera',
                  file: cedulaTrasera,
                  onTap: _subiendo ? () {} : _pickTrasera,
                  onRemove: _subiendo
                      ? () {}
                      : () => setState(() => cedulaTrasera = null),
                ),

                const SizedBox(height: 14),

                SizedBox(
                  height: 48,
                  child: TextButton(
                    onPressed: _subiendo ? null : subir,
                    style: TextButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _subiendo
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'subir',
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

            if (file != null)
              IconButton(onPressed: onRemove, icon: const Icon(Icons.close)),
          ],
        ),
      ),
    );
  }
}
