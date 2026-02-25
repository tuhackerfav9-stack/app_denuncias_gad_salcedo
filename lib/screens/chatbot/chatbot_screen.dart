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
import '../../services/chatbot_service.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

// =======================
// Models internos (parte 1)
// =======================

class _PendingMedia {
  final File file;
  final bool isVideo;

  const _PendingMedia({required this.file, required this.isVideo});
}

class _ChatAttachment {
  final File file;
  final bool isVideo;
  final String label;

  const _ChatAttachment({
    required this.file,
    required this.isVideo,
    required this.label,
  });
}

class _ChatMessage {
  final String text;
  final bool isMe;
  final bool isTyping;
  final bool isError;
  final _ChatAttachment? attachment;

  const _ChatMessage({
    required this.text,
    required this.isMe,
    this.isTyping = false,
    this.isError = false,
    this.attachment,
  });
}

class _ChatbotScreenState extends State<ChatbotScreen>
    with WidgetsBindingObserver {
  static const Color primaryBlue = Color(0xFF2C64C4);

  // ================== REPO + SERVICE ==================
  final ChatbotRepository repo = ChatbotRepository();

  /// Si tu ChatbotService actual recibe repo, cambia esta línea por:
  /// late final ChatbotService botService = ChatbotService(repo: repo);
  late final ChatbotService botService = ChatbotService();

  // ================== UI STATE ==================
  final TextEditingController msgController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final FocusNode inputFocus = FocusNode();

  int currentIndex = 2;
  bool _keyboardVisible = false;

  String? _convId;
  String? _borradorId;

  bool _starting = true;
  bool _sending = false;
  bool _uploadingMedia = false;

  // Estado backend borrador
  bool _listoParaEnviar = false;
  List<String> _faltantes = [];

  // Indicadores visuales (UI)
  int _fotosSubidas = 0;
  int _videosSubidos = 0;
  bool _firmaSubida = false;

  final List<_ChatMessage> messages = [];

  // Evidencias pendientes (cola real)
  final List<_PendingMedia> _pendingMedia = [];

  // Preview en composer (último adjunto seleccionado)
  File? _mediaFile;
  bool _mediaEsVideo = false;

  // Firma (opcional)
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
    inputFocus.addListener(() {
      if (mounted) setState(() {});
    });
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
    if (!mounted) return;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final visible = bottom > 0;
    if (visible != _keyboardVisible) {
      setState(() => _keyboardVisible = visible);
    }
  }

  // ================== ERRORES (HTTP + INTERNET) ==================

  bool _containsAny(String s, List<String> keys) =>
      keys.any((k) => s.contains(k));

  String _extractStatus(String msg) {
    final m = RegExp(r'\b(401|403|404|422|500|503)\b').firstMatch(msg);
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
                (code == null || code.isEmpty) ? title : "$title ($code)",
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
    final msgLow = msg.toLowerCase();

    if (e is SocketException ||
        _containsAny(msgLow, [
          "socketexception",
          "failed host lookup",
          "network is unreachable",
          "no address associated",
          "connection refused",
        ])) {
      await _showErrorDialog(
        title: "Sin conexión",
        icon: Icons.wifi_off,
        message:
            "No tienes internet o la red está fallando.\n\n"
            "• Revisa Wi-Fi/Datos\n"
            "• Intenta de nuevo",
      );
      return;
    }

    if (e is TimeoutException || msgLow.contains("timeout")) {
      await _showErrorDialog(
        title: "Tiempo de espera",
        icon: Icons.timer_outlined,
        message:
            "El servidor tardó demasiado en responder.\n\nIntenta nuevamente.",
      );
      return;
    }

    final code = _extractStatus(msg);

    if (code == "401") {
      await _showErrorDialog(
        title: "Sesión expirada",
        code: "401",
        icon: Icons.lock_outline,
        message: "Tu sesión ya no es válida.\n\nVuelve a iniciar sesión.",
      );
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

    // 404 de borrador (caso típico si se intentó subir evidencia después de finalizar)
    if (code == "404" && msgLow.contains("borrador no existe")) {
      await _showErrorDialog(
        title: "Borrador no disponible",
        code: "404",
        icon: Icons.info_outline,
        message:
            "El borrador ya no existe porque la denuncia probablemente ya fue enviada.\n\n"
            "Si ves el ID de denuncia en el chat, la denuncia sí se creó ✅",
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
            "El servidor está caído o en mantenimiento.\n\nIntenta más tarde.",
      );
      return;
    }

    if (code == "500") {
      await _showErrorDialog(
        title: "Error del servidor",
        code: "500",
        icon: Icons.dns_outlined,
        message:
            "Ocurrió un error interno en el servidor.\n\nIntenta nuevamente.",
      );
      return;
    }

    await _showErrorDialog(
      title: "Error desconocido",
      icon: Icons.help_outline,
      message: "Ocurrió un error inesperado.\n\nDetalle: $msg",
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // =========================================================
  // Helpers de texto / estado
  // =========================================================

  bool _isConfirmWord(String text) {
    final t = text.trim().toLowerCase();
    return t == "si" ||
        t == "sí" ||
        t == "enviar" ||
        t == "enviar denuncia" ||
        t == "confirmo";
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 70), () {
      if (!mounted) return;
      if (!scrollController.hasClients) return;

      scrollController.animateTo(
        scrollController.position.maxScrollExtent + 220,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  String _safeFileName(File f) => f.path.split(RegExp(r'[\\/]+')).last;

  String _faltantesHuman() {
    if (_faltantes.isEmpty) return "";
    final map = <String, String>{
      "tipo_denuncia_id": "tipo",
      "descripcion": "descripción",
      "ubicacion": "ubicación",
    };
    final xs = _faltantes.map((x) => map[x] ?? x).toList();
    return "Falta: ${xs.join(', ')}";
  }

  void _updateBorradorStateFromResponse(dynamic borr) {
    if (borr is Map) {
      final id = (borr["id"] ?? "").toString();
      if (id.isNotEmpty && id.toLowerCase() != "null") {
        _borradorId = id;
      }
      _listoParaEnviar = (borr["listo_para_enviar"] == true);

      final f = borr["faltantes"];
      _faltantes = (f is List)
          ? f.map((e) => e.toString()).toList()
          : <String>[];
    } else {
      _listoParaEnviar = false;
      _faltantes = <String>[];
    }
  }

  // =========================================================
  // Persistir archivo seleccionado
  // =========================================================

  Future<File> _persistPickedFile(XFile x) async {
    final dir = await getApplicationSupportDirectory();
    final ext = p.extension(x.path);
    final name = "evid_${DateTime.now().millisecondsSinceEpoch}$ext";
    final newPath = p.join(dir.path, name);
    return File(x.path).copy(newPath);
  }

  // =========================================================
  // Extracted (ayuda al backend V2 a crear/actualizar borrador)
  // =========================================================

  Map<String, dynamic> _buildExtracted(String text) {
    final t = text.trim();
    final low = t.toLowerCase();

    // lat/lng flexible
    final m = RegExp(
      r'lat(?:itud)?\s*[:=]?\s*(-?\d+(?:\.\d+)?)\s*.*?(?:lon(?:gitud)?|lng)\s*[:=]?\s*(-?\d+(?:\.\d+)?)',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(t);

    if (m != null) {
      return {
        "latitud": double.tryParse(m.group(1) ?? ""),
        "longitud": double.tryParse(m.group(2) ?? ""),
      };
    }

    if (low.startsWith("referencia:")) {
      return {"referencia": t.substring("referencia:".length).trim()};
    }

    if (low.startsWith("dirección:") || low.startsWith("direccion:")) {
      final cut = low.startsWith("dirección:") ? "dirección:" : "direccion:";
      return {"referencia": t.substring(cut.length).trim()};
    }

    if (low.startsWith("tipo:")) {
      return {"tipo_texto": t.substring("tipo:".length).trim()};
    }

    if (low.startsWith("descripcion:") || low.startsWith("descripción:")) {
      final cut = low.startsWith("descripcion:")
          ? "descripcion:"
          : "descripción:";
      return {"descripcion": t.substring(cut.length).trim()};
    }

    // Heurística suave para referencia si el usuario responde algo como:
    // "frente al gad", "cerca del parque", etc.
    final looksLikeReference = RegExp(
      r'^(frente|cerca|junto|alado|al lado|por|por la|por el)\b',
      caseSensitive: false,
    ).hasMatch(t);

    if (looksLikeReference && t.length <= 120) {
      return {"referencia": t};
    }

    // Heurística para tipo si es mensaje muy corto (ej: "baches", "basura")
    final words = t.split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
    if (words.length <= 3 && t.length <= 30) {
      return {"tipo_texto": t};
    }

    // Fallback: descripción
    return {"descripcion": t};
  }

  // ================== START CHAT ==================

  Future<void> _startChat() async {
    setState(() {
      _starting = true;
      _sending = false;
      _uploadingMedia = false;

      _convId = null;
      _borradorId = null;

      _listoParaEnviar = false;
      _faltantes = [];

      _fotosSubidas = 0;
      _videosSubidos = 0;
      _firmaSubida = false;

      _pendingMedia.clear();
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

      // 1) inicia conversación en backend
      final startRes = await repo.startV2();
      _convId = startRes["conversacion_id"]?.toString();

      // 2) inicia historial de Gemini (frontend)
      await botService.start();

      setState(() {
        messages.add(
          const _ChatMessage(
            text:
                "Hola 👋 ¿Qué deseas denunciar hoy?\n"
                "Ejemplos: basura, alumbrado, baches, agua potable…",
            isMe: false,
          ),
        );
        _starting = false;
      });

      _scrollToBottom();
    } catch (e) {
      setState(() => _starting = false);
      await _handleApiError(e);
    }
  }

  // ================== ENVÍO PRINCIPAL ==================

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
        const _ChatMessage(text: "Escribiendo...", isMe: false, isTyping: true),
      );
    });
    _scrollToBottom();

    try {
      // ✅ Fix importante:
      // Si el usuario confirma "enviar" y ya hay borrador + evidencias pendientes,
      // subimos primero la evidencia para evitar 404 después de finalizar.
      final willConfirm = _isConfirmWord(text);
      if (willConfirm && _pendingMedia.isNotEmpty && _borradorId != null) {
        _toast("⏫ Subiendo evidencias antes de enviar...");
        await _tryUploadPendingMedia();
      }

      final extracted = _buildExtracted(text);

      // 1) Gemini
      final geminiText = await botService.askGemini(text);
      final String? botResponseToSend = geminiText.startsWith("⚠️")
          ? null
          : geminiText;

      // 2) Sync backend V2 (guarda historial + actualiza borrador + puede finalizar)
      final res = await repo.syncV2(
        conversacionId: _convId!,
        mensaje: text,
        botResponse: botResponseToSend,
        extracted: extracted,
      );

      // 3) Actualiza estado del borrador
      _updateBorradorStateFromResponse(res["borrador"]);

      // 4) Texto oficial a mostrar
      String serverText =
          (res["respuesta"] ?? (botResponseToSend ?? geminiText))
              .toString()
              .trim();

      final source = (res["source"] ?? "").toString().toLowerCase();
      final denunciaIdRaw = (res["denuncia_id"] ?? "").toString();
      final denunciaId =
          (denunciaIdRaw.isNotEmpty && denunciaIdRaw.toLowerCase() != "null")
          ? denunciaIdRaw
          : null;

      // Anti-mentira (si Gemini dijo "enviada" pero backend no la finalizó)
      if (denunciaId == null &&
          source == "gemini" &&
          serverText.toLowerCase().contains("enviad")) {
        serverText =
            "Ya tengo tu información ✅\n"
            "Si deseas, adjunta evidencia (foto/video) y firma.\n"
            "Cuando estés listo, presiona el botón ✅ o escribe “enviar”.";
      }

      setState(() {
        messages.removeWhere((m) => m.isTyping);
        messages.add(_ChatMessage(text: serverText, isMe: false));
        _sending = false;
      });
      _scrollToBottom();

      // 5) Si ya se finalizó, NO subir más evidencia al borrador (evita 404)
      if (denunciaId != null) {
        _pendingMedia.clear();
        _mediaFile = null;
        _mediaEsVideo = false;
        _borradorId = null;
        _listoParaEnviar = false;
        _faltantes = [];

        _toast("✅ Denuncia enviada: $denunciaId");
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/denuncias', (r) => false);
        return;
      }

      // 6) Si no finalizó y ahora ya existe borrador, subir pendientes automáticamente
      await _tryUploadPendingMedia();
    } catch (e) {
      setState(() {
        messages.removeWhere((m) => m.isTyping);
        messages.add(
          const _ChatMessage(
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

  // ================== EVIDENCIA (SELECCIÓN) ==================

  Future<void> _addPendingMedia({
    required File file,
    required bool isVideo,
    bool updateComposerPreview = true,
  }) async {
    if (!mounted) return;

    setState(() {
      _pendingMedia.add(_PendingMedia(file: file, isVideo: isVideo));
      if (updateComposerPreview) {
        _mediaFile = file;
        _mediaEsVideo = isVideo;
      }
    });

    _toast(isVideo ? "🎥 Video agregado" : "📷 Foto agregada");

    // Si ya hay borrador, intenta subir de una (automático)
    if (_borradorId != null &&
        _borradorId!.isNotEmpty &&
        !_sending &&
        !_starting) {
      await _tryUploadPendingMedia();
    }
  }

  Future<void> _pickFoto() async {
    final picker = ImagePicker();

    // ✅ Múltiples fotos
    final xs = await picker.pickMultiImage(
      imageQuality: 80,
      maxWidth: 1280,
      maxHeight: 1280,
    );

    if (xs.isEmpty) return;

    for (int i = 0; i < xs.length; i++) {
      final f = await _persistPickedFile(xs[i]);
      await _addPendingMedia(
        file: f,
        isVideo: false,
        updateComposerPreview: i == xs.length - 1,
      );
    }

    _toast("📷 ${xs.length} foto(s) lista(s)");
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final x = await picker.pickVideo(source: ImageSource.gallery);
    if (x == null) return;

    final f = await _persistPickedFile(x);
    await _addPendingMedia(file: f, isVideo: true);
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
    await _addPendingMedia(file: f, isVideo: false);
  }

  Future<void> _takeVideoCamera() async {
    final picker = ImagePicker();
    final x = await picker.pickVideo(source: ImageSource.camera);
    if (x == null) return;

    final f = await _persistPickedFile(x);
    await _addPendingMedia(file: f, isVideo: true);
  }

  void _removeAttachment() {
    if (_mediaFile == null) return;

    final previewPath = _mediaFile!.path;
    setState(() {
      // quita de la cola el preview actual si todavía está pendiente
      _pendingMedia.removeWhere((e) => e.file.path == previewPath);

      _mediaFile = null;
      _mediaEsVideo = false;

      // si quedan pendientes, mostrar el último como preview
      if (_pendingMedia.isNotEmpty) {
        final last = _pendingMedia.last;
        _mediaFile = last.file;
        _mediaEsVideo = last.isVideo;
      }
    });

    _toast("🗑️ Adjunto quitado");
  }

  // ================== EVIDENCIA (SUBIDA AUTOMÁTICA) ==================

  Future<void> _tryUploadPendingMedia() async {
    if (_uploadingMedia) return;
    if (_borradorId == null || _borradorId!.isEmpty) return;
    if (_pendingMedia.isEmpty) return;

    _uploadingMedia = true;

    try {
      while (_pendingMedia.isNotEmpty) {
        final item = _pendingMedia.first;
        final tipo = item.isVideo ? "video" : "foto";

        await repo.subirEvidencia(
          borradorId: _borradorId!,
          archivo: item.file,
          tipo: tipo,
        );

        // Si subió OK, recién quitamos de la cola
        _pendingMedia.removeAt(0);

        if (!mounted) return;

        setState(() {
          if (item.isVideo) {
            _videosSubidos++;
          } else {
            _fotosSubidas++;
          }

          messages.add(
            _ChatMessage(
              text: item.isVideo ? "🎥 Video subido" : "📷 Foto subida",
              isMe: true,
              attachment: _ChatAttachment(
                file: item.file,
                isVideo: item.isVideo,
                label: _safeFileName(item.file),
              ),
            ),
          );

          // Si el preview era justo el que se subió, limpia/actualiza preview
          if (_mediaFile?.path == item.file.path) {
            _mediaFile = _pendingMedia.isNotEmpty
                ? _pendingMedia.last.file
                : null;
            _mediaEsVideo = _pendingMedia.isNotEmpty
                ? _pendingMedia.last.isVideo
                : false;
          }
        });

        _scrollToBottom();
      }

      _toast("✅ Evidencia subida");
    } catch (e) {
      // NO vaciamos cola si falla. El item sigue pendiente.
      await _handleApiError(e);
    } finally {
      _uploadingMedia = false;
    }
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
      _toast("⚠️ Aún no hay borrador. Escribe tipo + descripción primero.");
      return;
    }

    try {
      final bytes = await _obtenerFirmaBytesObligatoria();

      _toast("⏫ Subiendo firma...");
      await repo.subirFirma(borradorId: _borradorId!, pngBytes: bytes);

      // Guardar preview local como mensaje en chat
      final dir = await getApplicationSupportDirectory();
      final path = p.join(
        dir.path,
        "firma_${DateTime.now().millisecondsSinceEpoch}.png",
      );
      final f = await File(path).writeAsBytes(bytes);

      if (!mounted) return;

      setState(() {
        _firmaSubida = true;
        messages.add(
          _ChatMessage(
            text: "✍️ Firma subida",
            isMe: true,
            attachment: _ChatAttachment(
              file: f,
              isVideo: false,
              label: "firma.png",
            ),
          ),
        );
      });

      signatureController.clear();
      setState(() => _firmaInteractuada = false);

      _toast("✅ Firma subida");
      _scrollToBottom();
    } catch (e) {
      await _handleApiError(e);
    }
  }

  // ================== BOTTOM SHEETS / DIALOGS ==================

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
                  title: 'Elegir foto(s) (Galería)',
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

  // ================== navegación inferior ==================

  void _onBottomNavTap(int index) {
    setState(() => currentIndex = index);

    if (index == 0) Navigator.pushNamed(context, '/denuncias');
    if (index == 1) Navigator.pushNamed(context, '/form/denuncias');
    if (index == 2) return;
    if (index == 3) Navigator.pushNamed(context, '/mapadenuncias');
  }

  // ================== UI (PARTE 2 CONTINÚA AQUÍ) ==================
  // ================== UI (PARTE 2 FINAL) ==================
  @override
  Widget build(BuildContext context) {
    final hasAttachmentPreview = _mediaFile != null;
    final pendingCount = _pendingMedia.length;

    return Scaffold(
      backgroundColor: Colors.white,

      // Drawer (manteniendo tu estilo)
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

      // AppBar
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

          // Chips de estado (pro + útiles)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _miniChip(
                    label: _convId == null
                        ? "sin conversación"
                        : "conversación",
                    ok: _convId != null,
                  ),
                  _miniChip(
                    label: _borradorId == null ? "sin borrador" : "borrador",
                    ok: _borradorId != null,
                  ),
                  if (_borradorId != null)
                    _miniChip(
                      label: _listoParaEnviar
                          ? "lista para enviar"
                          : (_faltantesHuman().isEmpty
                                ? "completando datos"
                                : _faltantesHuman()),
                      ok: _listoParaEnviar,
                      warning: !_listoParaEnviar,
                    ),
                  if (_fotosSubidas > 0) _countChip("📷", _fotosSubidas),
                  if (_videosSubidos > 0) _countChip("🎥", _videosSubidos),
                  if (_firmaSubida) _miniChip(label: "✍️ firma", ok: true),
                  if (pendingCount > 0)
                    _miniChip(
                      label: "pendientes: $pendingCount",
                      ok: false,
                      warning: true,
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 4),

          // Lista de mensajes
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

          // Composer
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Preview del adjunto pendiente (último seleccionado)
                  if (hasAttachmentPreview)
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
                                errorBuilder: (_, __, ___) => Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _safeFileName(_mediaFile!),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  pendingCount > 1
                                      ? "$pendingCount archivos pendientes"
                                      : "1 archivo pendiente",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
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
                          onTap: (_starting || _sending || _uploadingMedia)
                              ? null
                              : _openAttachmentsSheet,
                        ),
                        const SizedBox(width: 6),
                        _RoundIconBtn(
                          icon: Icons.my_location,
                          tooltip: "Enviar ubicación",
                          onTap: (_starting || _sending)
                              ? null
                              : _sendCurrentLocation,
                        ),
                        const SizedBox(width: 6),
                        _RoundIconBtn(
                          icon: Icons.border_color_outlined,
                          tooltip: "Firma",
                          onTap: (_starting || _sending)
                              ? null
                              : _openFirmaDialog,
                        ),

                        // Botón enviar denuncia (confirmación explícita)
                        if (_listoParaEnviar) ...[
                          const SizedBox(width: 6),
                          _RoundIconBtn(
                            icon: Icons.check_circle,
                            tooltip: "Enviar denuncia",
                            onTap: (_sending || _starting || _uploadingMedia)
                                ? null
                                : () => _sendText("enviar"),
                          ),
                        ],

                        const SizedBox(width: 8),

                        Expanded(
                          child: TextField(
                            focusNode: inputFocus,
                            controller: msgController,
                            minLines: 1,
                            maxLines: 4,
                            enabled: !_starting && !_uploadingMedia,
                            onSubmitted: (_) => _sendText(),
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: _uploadingMedia
                                  ? 'Subiendo evidencia...'
                                  : 'Escribir mensaje...',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        InkWell(
                          onTap: (_sending || _starting || _uploadingMedia)
                              ? null
                              : _sendText,
                          borderRadius: BorderRadius.circular(999),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: (_sending || _starting || _uploadingMedia)
                                  ? Colors.grey
                                  : primaryBlue,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: (_sending || _uploadingMedia)
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
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

  // =======================
  // Widgets auxiliares del State
  // =======================

  Widget _countChip(String label, int n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Text(
        "$label $n",
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.blue.shade800,
        ),
      ),
    );
  }

  Widget _miniChip({
    required String label,
    required bool ok,
    bool warning = false,
  }) {
    final bg = ok
        ? Colors.green.shade50
        : (warning ? Colors.orange.shade50 : Colors.grey.shade200);
    final border = ok
        ? Colors.green.shade200
        : (warning ? Colors.orange.shade200 : Colors.grey.shade300);
    final fg = ok
        ? Colors.green.shade800
        : (warning ? Colors.orange.shade800 : Colors.grey.shade800);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

// =======================
// Widgets / componentes visuales finales
// (van FUERA del State)
// =======================

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
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Column(
                crossAxisAlignment: message.isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.attachment != null) ...[
                    _AttachmentView(
                      att: message.attachment!,
                      isMe: message.isMe,
                    ),
                    if (message.text.trim().isNotEmpty)
                      const SizedBox(height: 8),
                  ],
                  if (message.text.trim().isNotEmpty)
                    SelectableText(
                      message.text,
                      style: TextStyle(color: fg, fontSize: 13.5, height: 1.25),
                    ),
                ],
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

class _AttachmentView extends StatelessWidget {
  final _ChatAttachment att;
  final bool isMe;

  const _AttachmentView({required this.att, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final border = isMe ? Colors.white.withOpacity(0.35) : Colors.grey.shade400;

    return Container(
      width: 230,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(14),
        color: isMe
            ? Colors.white.withOpacity(0.12)
            : Colors.white.withOpacity(0.55),
      ),
      child: Row(
        children: [
          if (!att.isVideo)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                att.file,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.image_not_supported_outlined),
                ),
              ),
            )
          else
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.videocam, color: Colors.black54),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  att.isVideo ? "Video" : "Imagen",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isMe ? Colors.white : Colors.black87,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  att.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.black54,
                    fontSize: 11.8,
                  ),
                ),
              ],
            ),
          ),
        ],
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
          child: Icon(
            icon,
            size: 20,
            color: enabled ? Colors.grey.shade800 : Colors.grey.shade500,
          ),
        ),
      ),
    );
  }
}
