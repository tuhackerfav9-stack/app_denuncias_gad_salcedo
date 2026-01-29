import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:awesome_dialog/awesome_dialog.dart';

import '../../repositories/register_repository.dart';
import '../../settings/api_exception.dart';
import '../../settings/session.dart';

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
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final uid = args["uid"]?.toString();
      if (uid != null && uid.isNotEmpty) _uid = uid;
    }
  }

  // =========================
  // DIALOGOS PRO
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

  void _dlgInfo(String title, String desc) {
    AwesomeDialog(
      context: context,
      animType: AnimType.scale,
      title: title,
      desc: desc,
      btnOkText: "Ok",
      btnOkColor: primaryBlue,
      btnOkOnPress: () {},
      customHeader: _header(Icons.info_outline),
    ).show();
  }

  void _dlgError(String title, String desc) {
    AwesomeDialog(
      context: context,
      animType: AnimType.scale,
      title: title,
      desc: desc,
      btnOkText: "Entendido",
      btnOkColor: primaryBlue,
      btnOkOnPress: () {},
      customHeader: _header(Icons.error_outline),
    ).show();
  }

  Future<void> _handleApiError(ApiException e) async {
    if (!mounted) return;

    switch (e.type) {
      case ApiErrorType.network:
        _dlgError("Sin conexión", "Revisa tu conexión a internet.");
        break;

      case ApiErrorType.timeout:
        _dlgError(
          "Tiempo agotado",
          "El servidor no respondió. Intenta nuevamente.",
        );
        break;

      case ApiErrorType.unauthorized:
        await Session.clear();
        if (!mounted) return;
        _dlgInfo(
          "Sesión expirada",
          "Tu sesión no es válida. Inicia sesión nuevamente.",
        );
        Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
        break;

      case ApiErrorType.forbidden:
        _dlgError("Acceso denegado", e.message);
        break;

      case ApiErrorType.server:
        _dlgError("Servidor no disponible", "Intenta nuevamente más tarde.");
        break;

      case ApiErrorType.unknown:
        _dlgError("Error", e.message);
        break;
    }
  }

  // =========================
  // PICK IMAGEN
  // =========================
  Future<ImageSource?> _elegirFuente() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickFrontal() async {
    final source = await _elegirFuente();
    if (source == null) return;
    final x = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1280,
      maxHeight: 1280,
    );
    if (x == null) return;
    setState(() => cedulaFrontal = File(x.path));
  }

  Future<void> _pickTrasera() async {
    final source = await _elegirFuente();
    if (source == null) return;
    final x = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1280,
      maxHeight: 1280,
    );
    if (x == null) return;
    setState(() => cedulaTrasera = File(x.path));
  }

  // =========================
  // SUBIR DOCUMENTOS
  // =========================
  Future<void> subir() async {
    if (_uid == null || _uid!.isEmpty) {
      _dlgError("Error", "No se encontró el UID del registro.");
      return;
    }

    if (cedulaFrontal == null || cedulaTrasera == null) {
      final faltan = <String>[];
      if (cedulaFrontal == null) faltan.add('frontal');
      if (cedulaTrasera == null) faltan.add('trasera');
      _dlgInfo(
        "Documentos incompletos",
        "Falta subir la parte: ${faltan.join(' y ')}",
      );
      return;
    }

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

      Navigator.pushNamed(context, '/register5', arguments: {"uid": _uid});
    } on ApiException catch (e) {
      await _handleApiError(e);
    } catch (e) {
      if (!mounted) return;
      _dlgError("Error inesperado", e.toString());
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
                            'Subir',
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

// =========================
// CARD CÉDULA (SIN CAMBIOS)
// =========================
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
