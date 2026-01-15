import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';

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

  // Evidencia
  File? _mediaFile;
  bool _mediaEsVideo = false;

  // Firma (opcional en chat; la dejé como herramienta)
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
      _borradorId = null; // start NO crea borrador (como quieres)

      messages.add(
        _ChatMessage(
          text:
              "Hola 👋 ¿Qué deseas denunciar hoy?\n"
              "Elige una opción escribiendo el número:\n\n"
              "1️. Alumbrado público.\n"
              "2️. Basura / Aseo.\n"
              "3️. Vías / Baches.\n"
              "4️. Seguridad.\n"
              "5️. Ruido.\n"
              "6. Otros.\n"
              "Al comenzar la denuncia crearé un borrador donde iré anotando tu denuncia para luego enviarla.",
          isMe: false,
        ),
      );

      setState(() => _starting = false);
      _scrollToBottom();
    } catch (e) {
      setState(() => _starting = false);
      _toast("❌ No se pudo iniciar el chat: $e");
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

    setState(() {
      _sending = true;
      messages.add(_ChatMessage(text: text, isMe: true));
      if (overrideText == null) msgController.clear();
      messages.add(
        _ChatMessage(text: "Escribiendo...", isMe: false, isTyping: true),
      );
    });

    _scrollToBottom();

    try {
      final res = await repo.sendMessage(
        conversacionId: _convId!,
        mensaje: text,
      );

      final botText = (res["respuesta"] ?? "").toString().trim();
      final denunciaId = res["denuncia_id"]?.toString();

      // si backend devuelve borrador snapshot -> guardamos id
      final borr = res["borrador"];
      if (borr is Map) {
        final id = borr["id"]?.toString();
        if (id != null && id.isNotEmpty && id.toLowerCase() != "null") {
          _borradorId = id;
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
            text: "❌ Error enviando mensaje: $e",
            isMe: false,
            isError: true,
          ),
        );
        _sending = false;
      });
      _scrollToBottom();
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

      // tu backend ya parsea lat/lng por regex
      await _sendText("lat: ${pos.latitude} lng: ${pos.longitude}");
    } catch (e) {
      _toast("❌ No se pudo obtener ubicación: $e");
    }
  }

  // ================== EVIDENCIA ==================
  Future<void> _pickFoto() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x == null) return;
    setState(() {
      _mediaFile = File(x.path);
      _mediaEsVideo = false;
    });
    _toast("📷 Foto seleccionada");
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final x = await picker.pickVideo(source: ImageSource.gallery);
    if (x == null) return;
    setState(() {
      _mediaFile = File(x.path);
      _mediaEsVideo = true;
    });
    _toast("🎥 Video seleccionado");
  }

  Future<void> _subirEvidenciaSeleccionada() async {
    if (_borradorId == null || _borradorId!.isEmpty) {
      _toast("⚠️ Aún no hay borrador. Escribe tipo + descripción primero.");
      return;
    }
    if (_mediaFile == null) {
      _toast("⚠️ Selecciona una foto o video primero.");
      return;
    }

    final tipo = _mediaEsVideo ? "video" : "foto";

    try {
      _toast("⏫ Subiendo $tipo...");
      await repo.subirEvidencia(
        borradorId: _borradorId!,
        archivo: _mediaFile!,
        tipo: tipo,
      );
      _toast("✅ Evidencia subida");
      setState(() => _mediaFile = null);
    } catch (e) {
      _toast("❌ Error subiendo evidencia: $e");
    }
  }

  // ================== FIRMA ==================
  bool _firmaValida() {
    final pts = signatureController.points;
    return _firmaInteractuada && pts.isNotEmpty && pts.length >= 2;
  }

  Future<List<int>> _obtenerFirmaBytesObligatoria() async {
    if (!_firmaValida()) {
      throw Exception("Firma no válida.");
    }
    await Future.delayed(const Duration(milliseconds: 80));
    final png = await signatureController.toPngBytes();
    if (png == null || png.isEmpty) {
      throw Exception("No se pudo generar PNG de la firma.");
    }
    return png;
  }

  Future<void> _subirFirma() async {
    if (_borradorId == null || _borradorId!.isEmpty) {
      _toast("⚠️ Aún no hay borrador. Escribe tipo + descripción primero.");
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
      _toast("❌ Error firma: $e");
    }
  }

  // ================== ATTACHMENTS SHEET ==================
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
                  icon: Icons.my_location,
                  title: 'Enviar ubicación actual',
                  onTap: () async {
                    Navigator.pop(context);
                    await _sendCurrentLocation();
                  },
                ),
                _AttachTile(
                  icon: Icons.photo,
                  title: 'Elegir foto',
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickFoto();
                  },
                ),
                _AttachTile(
                  icon: Icons.videocam,
                  title: 'Elegir video',
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickVideo();
                  },
                ),
                _AttachTile(
                  icon: Icons.cloud_upload,
                  title: 'Subir evidencia (foto/video) al borrador',
                  onTap: () async {
                    Navigator.pop(context);
                    await _subirEvidenciaSeleccionada();
                  },
                ),
                _AttachTile(
                  icon: Icons.border_color_outlined,
                  title: 'Firmar y subir firma',
                  onTap: () {
                    Navigator.pop(context);
                    _openFirmaDialog();
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
                  if (!_firmaInteractuada)
                    setState(() => _firmaInteractuada = true);
                },
                onPointerMove: (_) {
                  if (!_firmaInteractuada)
                    setState(() => _firmaInteractuada = true);
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
    return Scaffold(
      backgroundColor: Colors.white,

      // Drawer (igual a tu estilo)
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

      // AppBar (igual estética)
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

          // estado mini
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

          if (_mediaFile != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      _mediaEsVideo ? Icons.videocam : Icons.image,
                      color: primaryBlue,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _mediaFile!.path.split('/').last,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _mediaFile = null),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
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

          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: _openAttachmentsSheet,
                            icon: const Icon(Icons.attach_file),
                            color: Colors.grey.shade700,
                          ),
                          Expanded(
                            child: TextField(
                              focusNode: inputFocus,
                              controller: msgController,
                              minLines: 1,
                              maxLines: 4,
                              enabled: !_starting,
                              onSubmitted: (_) => _sendText(),
                              decoration: const InputDecoration(
                                hintText: 'Mensaje...',
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: (_sending || _starting)
                          ? Colors.grey
                          : primaryBlue,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: (_sending || _starting) ? null : _sendText,
                      icon: const Icon(Icons.send, color: Colors.white),
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
