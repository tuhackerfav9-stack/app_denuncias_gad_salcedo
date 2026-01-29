import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../settings/session.dart';
import '../../repositories/chatbot_repository.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen>
    with WidgetsBindingObserver {
  static const Color primaryBlue = Color(0xFF2C64C4);
  // ================== ERRORES (HTTP + INTERNET) ==================
  bool _containsAny(String s, List<String> keys) =>
      keys.any((k) => s.contains(k));

  String _extractStatus(String msg) {
    // intenta encontrar 401/403/422/500/503 en el texto de Exception
    final m = RegExp(r'\b(401|403|422|500|503)\b').firstMatch(msg);
    return m?.group(1) ?? "";
  }

  Future<void> _showErrorDialog({
    required String title,
    required String message,
    String? code,
    IconData icon = Icons.error_outline,
  }) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(icon, color: primaryBlue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                code == null || code.isEmpty ? title : "$title ($code)",
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cerrar"),
          ),
        ],
      ),
    );
  }

  Future<void> _handleApiError(Object e) async {
    final msg = e.toString();

    // ✅ Sin internet / DNS / socket
    if (e is SocketException ||
        _containsAny(msg.toLowerCase(), [
          "socketexception",
          "failed host lookup",
          "network is unreachable",
          "no address associated",
          "connection refused",
        ])) {
      await _showErrorDialog(
        title: "Sin conexión",
        code: "",
        icon: Icons.wifi_off,
        message:
            "No tienes internet o la red está fallando.\n\n"
            "• Revisa Wi-Fi/Datos\n"
            "• Intenta de nuevo",
      );
      return;
    }

    // ✅ Timeout
    if (e is TimeoutException || msg.toLowerCase().contains("timeout")) {
      await _showErrorDialog(
        title: "Tiempo de espera",
        icon: Icons.timer_outlined,
        message:
            "El servidor tardó demasiado en responder.\n\n"
            "Intenta nuevamente en unos segundos.",
      );
      return;
    }

    // ✅ Códigos HTTP detectados en el mensaje
    final code = _extractStatus(msg);

    if (code == "401") {
      await _showErrorDialog(
        title: "Sesión expirada",
        code: "401",
        icon: Icons.lock_outline,
        message:
            "Tu sesión ya no es válida.\n\n"
            "Vuelve a iniciar sesión.",
      );
      // opcional: forzar logout
      await Session.clear();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
      return;
    }

    if (code == "403") {
      await _showErrorDialog(
        title: "No autorizado",
        code: "403",
        icon: Icons.block,
        message:
            "No tienes permisos para realizar esta acción.\n\n"
            "Si crees que es un error, contacta al administrador.",
      );
      return;
    }

    if (code == "422") {
      await _showErrorDialog(
        title: "Datos no válidos",
        code: "422",
        icon: Icons.rule_folder_outlined,
        message:
            "Los datos están correctos en forma, pero fallan reglas de negocio.\n\n"
            "Revisa lo que escribiste (tipo, descripción, ubicación o evidencia).",
      );
      return;
    }

    if (code == "503") {
      await _showErrorDialog(
        title: "Servicio no disponible",
        code: "503",
        icon: Icons.cloud_off_outlined,
        message:
            "El servidor está caído o en mantenimiento.\n\n"
            "Intenta más tarde.",
      );
      return;
    }

    if (code == "500") {
      await _showErrorDialog(
        title: "Error del servidor",
        code: "500",
        icon: Icons.dns_outlined,
        message:
            "Ocurrió un error interno en el servidor.\n\n"
            "Intenta nuevamente.",
      );
      return;
    }

    // ✅ Desconocido (?)
    await _showErrorDialog(
      title: "Error desconocido",
      code: "",
      icon: Icons.help_outline,
      message:
          "Ocurrió un error inesperado.\n\n"
          "Detalle: $msg",
    );
  }

  final repo = ChatbotRepository();

  final TextEditingController msgController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final FocusNode inputFocus = FocusNode();

  int currentIndex = 2;
  bool _keyboardVisible = false;

  String? _convId;
  String? _borradorId;

  bool _starting = true;
  bool _sending = false;

  final List<_ChatMessage> messages = [];

  // Evidencia (1 adjunto por vez, estilo ChatGPT)
  File? _mediaFile;
  bool _mediaEsVideo = false;

  // Firma (opcional en chat)
  final SignatureController signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  bool _firmaInteractuada = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    inputFocus.addListener(() => setState(() {}));
    _startChat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    msgController.dispose();
    scrollController.dispose();
    inputFocus.dispose();
    signatureController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final visible = bottom > 0;
    if (visible != _keyboardVisible) {
      setState(() => _keyboardVisible = visible);
    }
  }

  // =========================================================
  // Persistir archivo seleccionado (evita PathNotFound en cache)
  // =========================================================
  Future<File> _persistPickedFile(XFile x) async {
    final dir = await getApplicationSupportDirectory(); // estable
    final ext = p.extension(x.path);
    final name = "evid_${DateTime.now().millisecondsSinceEpoch}$ext";
    final newPath = p.join(dir.path, name);

    final newFile = await File(x.path).copy(newPath);
    return newFile;
  }

  // ================== START CHAT ==================
  Future<void> _startChat() async {
    setState(() {
      _starting = true;
      _sending = false;
      _convId = null;
      _borradorId = null;
      _mediaFile = null;
      _mediaEsVideo = false;
      _firmaInteractuada = false;
      signatureController.clear();
      messages.clear();
    });

    try {
      final access = await Session.access();
      if (access == null || access.isEmpty) {
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
        return;
      }

      final res = await repo.start();
      _convId = res["conversacion_id"]?.toString();
      _borradorId = null;

      messages.add(
        _ChatMessage(
          text:
              "Hola 👋 ¿Qué deseas denunciar hoy?\n"
              "Puedes escribir el nombre o el número:\n\n"
              "1. Alumbrado público\n"
              "2. Basura / Aseo\n"
              "3. Vías / Baches\n"
              "4. Seguridad\n"
              "5. Ruido\n"
              "6. Otros\n\n"
              "Luego cuéntame qué pasó y dónde fue 📍",
          isMe: false,
        ),
      );

      setState(() => _starting = false);
      _scrollToBottom();
    } catch (e) {
      setState(() => _starting = false);
      await _handleApiError(e);
    }
  }

  // ================== SEND MESSAGE ==================
  Future<void> _sendText([String? overrideText]) async {
    final text = (overrideText ?? msgController.text).trim();
    if (text.isEmpty) return;
    if (_sending || _starting) return;

    if (_convId == null || _convId!.isEmpty) {
      _toast("⚠️ No hay conversación, reiniciando...");
      await _startChat();
      if (_convId == null || _convId!.isEmpty) return;
    }

    // 👇 Guardamos si había adjunto en este envío (para subirlo después del mensaje)
    final File? mediaToUpload = _mediaFile;
    final bool mediaIsVideo = _mediaEsVideo;

    // ✅ Validación: si el archivo ya no existe, no intentes subir
    if (mediaToUpload != null && !await mediaToUpload.exists()) {
      _toast("❌ El archivo ya no existe. Vuelve a adjuntar.");
      return;
    }

    setState(() {
      _sending = true;

      messages.add(_ChatMessage(text: text, isMe: true));
      if (overrideText == null) msgController.clear();

      // estilo chat: limpias el adjunto después de enviar
      if (mediaToUpload != null) {
        _mediaFile = null;
        _mediaEsVideo = false;
      }

      messages.add(
        _ChatMessage(text: "Escribiendo...", isMe: false, isTyping: true),
      );
    });

    _scrollToBottom();

    try {
      // 1) mandamos el texto al bot
      final res = await repo.sendMessage(
        conversacionId: _convId!,
        mensaje: text,
      );

      final botText = (res["respuesta"] ?? "").toString().trim();
      final denunciaId = res["denuncia_id"]?.toString();

      // snapshot borrador
      final borr = res["borrador"];
      if (borr is Map) {
        final id = borr["id"]?.toString();
        if (id != null && id.isNotEmpty && id.toLowerCase() != "null") {
          _borradorId = id;
        }
      }

      // 2) si había adjunto, lo subimos AUTOMÁTICO
      if (mediaToUpload != null) {
        if (_borradorId == null || _borradorId!.isEmpty) {
          _toast(
            "📎 Adjuntado listo. Envía 1 mensaje más para crear borrador.",
          );
        } else {
          final tipo = mediaIsVideo ? "video" : "foto";
          try {
            _toast("⏫ Subiendo $tipo...");
            await repo.subirEvidencia(
              borradorId: _borradorId!,
              archivo: mediaToUpload,
              tipo: tipo,
            );
            _toast("✅ Evidencia subida");
          } catch (e) {
            //_toast(" Error subiendo evidencia: $e");
            await _handleApiError(e);
          }
        }
      }

      setState(() {
        messages.removeWhere((m) => m.isTyping);
        messages.add(
          _ChatMessage(
            text: botText.isNotEmpty
                ? botText
                : "¿Me confirmas el tipo de denuncia y una breve descripción?",
            isMe: false,
          ),
        );
        _sending = false;
      });

      _scrollToBottom();

      if (denunciaId != null && denunciaId.isNotEmpty) {
        _toast("✅ Denuncia enviada: $denunciaId");
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/denuncias', (r) => false);
      }
    } catch (e) {
      setState(() {
        messages.removeWhere((m) => m.isTyping);
        messages.add(
          _ChatMessage(
            text: "❌ Error enviando mensaje",
            isMe: false,
            isError: true,
          ),
        );
        _sending = false;
      });
      _scrollToBottom();
      await _handleApiError(e);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 60), () {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent + 220,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  // ================== UBICACIÓN ==================
  Future<void> _sendCurrentLocation() async {
    if (_starting || _sending) return;

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _toast("📍 Activa el GPS del teléfono.");
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied) {
        _toast("📍 Permiso de ubicación denegado.");
        return;
      }
      if (perm == LocationPermission.deniedForever) {
        _toast("📍 Permiso denegado permanentemente. Habilítalo en Ajustes.");
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await _sendText("lat: ${pos.latitude} lng: ${pos.longitude}");
    } catch (e) {
      _toast("❌ No se pudo obtener ubicación: $e");
    }
  }

  // ================== EVIDENCIA (GALERÍA + CÁMARA) ==================
  Future<void> _pickFoto() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1280,
      maxHeight: 1280,
    );
    if (x == null) return;

    final f = await _persistPickedFile(x);

    setState(() {
      _mediaFile = f;
      _mediaEsVideo = false;
    });
    _toast("📷 Foto lista para enviar");
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final x = await picker.pickVideo(source: ImageSource.gallery);
    if (x == null) return;

    final f = await _persistPickedFile(x);

    setState(() {
      _mediaFile = f;
      _mediaEsVideo = true;
    });
    _toast("🎥 Video listo para enviar");
  }

  Future<void> _takeFotoCamera() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1280,
      maxHeight: 1280,
    );
    if (x == null) return;

    final f = await _persistPickedFile(x);

    setState(() {
      _mediaFile = f;
      _mediaEsVideo = false;
    });
    _toast("📷 Foto tomada lista para enviar");
  }

  Future<void> _takeVideoCamera() async {
    final picker = ImagePicker();
    final x = await picker.pickVideo(source: ImageSource.camera);
    if (x == null) return;

    final f = await _persistPickedFile(x);

    setState(() {
      _mediaFile = f;
      _mediaEsVideo = true;
    });
    _toast("🎥 Video grabado listo para enviar");
  }

  void _removeAttachment() {
    setState(() {
      _mediaFile = null;
      _mediaEsVideo = false;
    });
  }

  // ================== FIRMA ==================
  bool _firmaValida() {
    final pts = signatureController.points;
    return _firmaInteractuada && pts.isNotEmpty && pts.length >= 2;
  }

  Future<List<int>> _obtenerFirmaBytesObligatoria() async {
    if (!_firmaValida()) throw Exception("Firma no válida.");
    await Future.delayed(const Duration(milliseconds: 80));
    final png = await signatureController.toPngBytes();
    if (png == null || png.isEmpty) {
      throw Exception("No se pudo generar PNG de la firma.");
    }
    return png;
  }

  Future<void> _subirFirma() async {
    if (_borradorId == null || _borradorId!.isEmpty) {
      _toast("⚠️ Aún no hay borrador. Escribe primero tipo + descripción.");
      return;
    }

    try {
      final bytes = await _obtenerFirmaBytesObligatoria();
      _toast("⏫ Subiendo firma...");
      await repo.subirFirma(borradorId: _borradorId!, pngBytes: bytes);
      _toast("✅ Firma subida");
      signatureController.clear();
      setState(() => _firmaInteractuada = false);
    } catch (e) {
      await _handleApiError(e);
    }
  }

  // ================== SHEET ADJUNTOS ==================
  void _openAttachmentsSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AttachTile(
                  icon: Icons.photo_library_outlined,
                  title: 'Elegir foto (Galería)',
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickFoto();
                  },
                ),
                _AttachTile(
                  icon: Icons.photo_camera_outlined,
                  title: 'Tomar foto (Cámara)',
                  onTap: () async {
                    Navigator.pop(context);
                    await _takeFotoCamera();
                  },
                ),
                _AttachTile(
                  icon: Icons.video_library_outlined,
                  title: 'Elegir video (Galería)',
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickVideo();
                  },
                ),
                _AttachTile(
                  icon: Icons.videocam_outlined,
                  title: 'Grabar video (Cámara)',
                  onTap: () async {
                    Navigator.pop(context);
                    await _takeVideoCamera();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openFirmaDialog() {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Firma"),
          content: SizedBox(
            height: 180,
            width: double.maxFinite,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Listener(
                onPointerDown: (_) {
                  if (!_firmaInteractuada) {
                    setState(() => _firmaInteractuada = true);
                  }
                },
                onPointerMove: (_) {
                  if (!_firmaInteractuada) {
                    setState(() => _firmaInteractuada = true);
                  }
                },
                child: Signature(
                  controller: signatureController,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                signatureController.clear();
                setState(() => _firmaInteractuada = false);
              },
              child: const Text("Limpiar"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cerrar"),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _subirFirma();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text("Subir"),
            ),
          ],
        );
      },
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ================== navegación inferior ==================
  void _onBottomNavTap(int index) {
    setState(() => currentIndex = index);

    if (index == 0) Navigator.pushNamed(context, '/denuncias');
    if (index == 1) Navigator.pushNamed(context, '/form/denuncias');
    if (index == 2) {}
    if (index == 3) Navigator.pushNamed(context, '/mapadenuncias');
  }

  // ================== UI ==================
  @override
  Widget build(BuildContext context) {
    final hasAttachment = _mediaFile != null;

    return Scaffold(
      backgroundColor: Colors.white,

      // Drawer (NO TOCAR)
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 10),
              FutureBuilder(
                future: Future.wait([Session.tipo(), Session.email()]),
                builder: (context, snap) {
                  final tipo = snap.data?[0] ?? "Ciudadano";
                  final email = snap.data?[1] ?? "sin correo";
                  final letra = email.isNotEmpty ? email[0].toUpperCase() : "C";

                  return ListTile(
                    leading: CircleAvatar(child: Text(letra)),
                    title: Text(tipo == "ciudadano" ? "Ciudadano" : tipo),
                    subtitle: Text(email),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text("Perfil"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/perfil');
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text("Ayuda"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/ayuda');
                },
              ),
              const Spacer(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text("Cerrar sesión"),
                onTap: () async {
                  Navigator.pop(context);
                  await Session.clear();
                  if (!context.mounted) return;
                  Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),

      // AppBar (NO TOCAR)
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: primaryBlue),
        title: const Text(
          "Chatbot",
          style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            onPressed: _starting ? null : _startChat,
            icon: const Icon(Icons.refresh),
            tooltip: "Reiniciar chat",
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: FutureBuilder<String?>(
              future: Session.email(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }
                final email = snapshot.data ?? "";
                final letra = email.isNotEmpty ? email[0].toUpperCase() : "C";
                return CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey.shade300,
                  child: Text(
                    letra,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          if (_starting)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              color: Colors.grey.shade100,
              child: const Center(child: Text("Iniciando conversación...")),
            ),

          // estado mini (NO TOCAR)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Row(
              children: [
                _miniChip(
                  label: _convId == null ? "sin conversación" : "conversación",
                  ok: _convId != null,
                ),
                const SizedBox(width: 8),
                _miniChip(
                  label: _borradorId == null
                      ? "sin borrador"
                      : "borrador listo",
                  ok: _borradorId != null,
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              itemCount: messages.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) return const SizedBox(height: 6);
                final msg = messages[i - 1];
                return _Bubble(message: msg);
              },
            ),
          ),

          // ===== Input “Gemini-like” =====
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Preview adjunto
                  if (hasAttachment)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          if (!_mediaEsVideo && _mediaFile != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                _mediaFile!,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _mediaEsVideo ? Icons.videocam : Icons.image,
                                color: primaryBlue,
                              ),
                            ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _mediaFile!.path.split('/').last,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _removeAttachment,
                            icon: const Icon(Icons.close),
                            tooltip: "Quitar adjunto",
                          ),
                        ],
                      ),
                    ),

                  // Barra tipo pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        _RoundIconBtn(
                          icon: Icons.attach_file,
                          tooltip: "Adjuntar",
                          onTap: _starting ? null : _openAttachmentsSheet,
                        ),
                        const SizedBox(width: 6),
                        _RoundIconBtn(
                          icon: Icons.my_location,
                          tooltip: "Enviar ubicación",
                          onTap: _starting ? null : _sendCurrentLocation,
                        ),
                        const SizedBox(width: 6),
                        _RoundIconBtn(
                          icon: Icons.border_color_outlined,
                          tooltip: "Firma",
                          onTap: _starting ? null : _openFirmaDialog,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            focusNode: inputFocus,
                            controller: msgController,
                            minLines: 1,
                            maxLines: 4,
                            enabled: !_starting,
                            onSubmitted: (_) => _sendText(),
                            decoration: const InputDecoration(
                              hintText: 'Escribir mensaje...',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: (_sending || _starting) ? null : _sendText,
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: (_sending || _starting)
                                  ? Colors.grey
                                  : primaryBlue,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar: _keyboardVisible
          ? null
          : BottomNavigationBar(
              currentIndex: currentIndex,
              onTap: _onBottomNavTap,
              type: BottomNavigationBarType.fixed,
              showSelectedLabels: false,
              showUnselectedLabels: false,
              selectedItemColor: primaryBlue,
              unselectedItemColor: Colors.grey.shade600,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: "Inicio",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.format_align_center),
                  label: "denuncias",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.smart_toy),
                  label: "chat",
                ),
                BottomNavigationBarItem(icon: Icon(Icons.map), label: "mapa"),
              ],
            ),
    );
  }

  Widget _miniChip({required String label, required bool ok}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ok ? Colors.green.shade50 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: ok ? Colors.green.shade200 : Colors.grey.shade300,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: ok ? Colors.green.shade800 : Colors.grey.shade800,
        ),
      ),
    );
  }
}

// ===== modelos y widgets internos =====

class _ChatMessage {
  final String text;
  final bool isMe;
  final bool isTyping;
  final bool isError;

  _ChatMessage({
    required this.text,
    required this.isMe,
    this.isTyping = false,
    this.isError = false,
  });
}

class _Bubble extends StatelessWidget {
  final _ChatMessage message;
  const _Bubble({required this.message});

  static const Color primaryBlue = Color(0xFF2C64C4);

  @override
  Widget build(BuildContext context) {
    final bg = message.isMe
        ? primaryBlue
        : (message.isError ? Colors.red.shade50 : Colors.grey.shade200);

    final fg = message.isMe
        ? Colors.white
        : (message.isError ? Colors.red.shade800 : Colors.black87);

    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                message.text,
                style: TextStyle(color: fg, fontSize: 13.5, height: 1.25),
              ),
            ),
            if (message.isTyping) ...[
              const SizedBox(width: 10),
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2, color: fg),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AttachTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _AttachTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.grey.shade200,
        child: Icon(icon, color: Colors.black87),
      ),
      title: Text(title),
      onTap: onTap,
    );
  }
}

class _RoundIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _RoundIconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: enabled ? Colors.white : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Icon(icon, size: 20, color: Colors.grey.shade800),
        ),
      ),
    );
  }
}
