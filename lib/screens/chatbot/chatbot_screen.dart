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
// Models internos
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

class _TipoItem {
  final String nombre;
  final String depto;

  const _TipoItem({required this.nombre, required this.depto});
}

class _ChatbotScreenState extends State<ChatbotScreen>
    with WidgetsBindingObserver {
  static const Color primaryBlue = Color(0xFF2C64C4);

  // ================== REPO + SERVICE ==================
  final ChatbotRepository repo = ChatbotRepository();
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

  // Estado backend
  List<String> _faltantes = [];

  // Flags de flujo textual
  bool _hasTipo = false;
  bool _hasDescripcion = false;
  bool _hasLocation = false;
  bool _hasReferencia = false;

  // Evidencia y firma
  int _fotosSubidas = 0;
  int _videosSubidos = 0;
  bool _firmaSubida = false;

  final List<_ChatMessage> messages = [];

  // Evidencias pendientes
  final List<_PendingMedia> _pendingMedia = [];

  // Preview en composer
  File? _mediaFile;
  bool _mediaEsVideo = false;

  // Firma
  final SignatureController signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  bool _firmaInteractuada = false;

  // Catálogo de tipos reales
  List<_TipoItem> _tiposCache = [];
  bool _tiposLoaded = false;
  int _tiposPage = 0;
  static const int _tiposPerPage = 12;

  // Sugerencias top-3
  List<_TipoItem> _lastTipoSuggestions = [];
  bool _awaitingTipoPick = false;

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

  // ================== ERRORES ==================

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
            "• Revisa Wi-Fi o Datos móviles\n"
            "• Intenta nuevamente",
      );
      return;
    }

    if (e is TimeoutException || msgLow.contains("timeout")) {
      await _showErrorDialog(
        title: "Tiempo de espera",
        icon: Icons.timer_outlined,
        message:
            "El servidor tardó demasiado en responder.\n\n"
            "Intenta nuevamente.",
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
            "Los datos tienen formato válido, pero fallan reglas de negocio.\n\n"
            "Revisa tipo, descripción, ubicación o evidencia.",
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

  // ================== Helpers de texto ==================

  bool _isConfirmWord(String text) {
    final t = text.trim().toLowerCase();
    return t == "si" ||
        t == "sí" ||
        t == "enviar" ||
        t == "enviar denuncia" ||
        t == "confirmo";
  }

  bool _isCancelWord(String text) {
    final t = text.trim().toLowerCase();
    return t == "no" || t == "cancelar";
  }

  bool _isLikelyLocationPayload(String text) {
    return RegExp(
      r'lat(?:itud)?\s*[:=]?\s*-?\d+(?:\.\d+)?\s*.*?(?:lon(?:gitud)?|lng)\s*[:=]?\s*-?\d+(?:\.\d+)?',
      caseSensitive: false,
      dotAll: true,
    ).hasMatch(text);
  }

  bool _isStructuredCommand(String text) {
    final low = text.trim().toLowerCase();
    return low.startsWith("tipo:") ||
        low.startsWith("referencia:") ||
        low.startsWith("direccion:") ||
        low.startsWith("dirección:") ||
        low.startsWith("descripcion:") ||
        low.startsWith("descripción:");
  }

  bool _isTiposQuery(String text) {
    final t = text.trim().toLowerCase();
    if (t.startsWith("tipo:")) return false;

    return RegExp(
          r'^(tipos|ver tipos|mostrar tipos|lista de tipos|qué tipos hay|que tipos hay)$',
          caseSensitive: false,
        ).hasMatch(t) ||
        t.contains("qué puedo denunciar") ||
        t.contains("que puedo denunciar") ||
        t.contains("qué denuncias puedo hacer") ||
        t.contains("que denuncias puedo hacer");
  }

  bool _isMoreTiposQuery(String text) {
    final t = text.trim().toLowerCase();
    return t == "mas" || t == "más" || t == "ver mas" || t == "ver más";
  }

  bool _isProgressQuery(String text) {
    final t = text.toLowerCase().trim();
    return t.contains("qué datos tienes") ||
        t.contains("que datos tienes") ||
        t.contains("qué datos tengo") ||
        t.contains("que datos tengo") ||
        t.contains("qué falta") ||
        t.contains("que falta") ||
        t.contains("qué me falta") ||
        t.contains("que me falta") ||
        t.contains("cuáles faltan") ||
        t.contains("cuales faltan") ||
        t.contains("qué has guardado") ||
        t.contains("que has guardado") ||
        t.contains("qué tienes guardado") ||
        t.contains("que tienes guardado") ||
        t.contains("dime qué tienes") ||
        t.contains("dime que tienes") ||
        t.contains("cómo va mi denuncia") ||
        t.contains("como va mi denuncia") ||
        t.contains("estado de mi denuncia");
  }

  bool _isOutOfScope(String text) {
    final t = text.toLowerCase();
    return RegExp(
      r'(matem|biolog|tarea|deber|programaci[oó]n|historia|ingl[eé]s|lengua|literatura|ejercicio)',
      caseSensitive: false,
    ).hasMatch(t);
  }

  bool _looksAskingTipo(String botText) {
    final low = botText.toLowerCase();
    return low.contains("¿qué tipo de denuncia es") ||
        low.contains("que tipo de denuncia es") ||
        low.contains("dime “tipos”") ||
        low.contains("dime \"tipos\"");
  }

  bool _looksAskingDescripcion(String botText) {
    final low = botText.toLowerCase();
    return low.contains("cuéntame qué pasó") ||
        low.contains("cuentame que paso") ||
        low.contains("breve descripción") ||
        low.contains("breve descripcion") ||
        low.contains("descríbeme brevemente") ||
        low.contains("describeme brevemente");
  }

  bool _looksAskingLocation(String botText) {
    final low = botText.toLowerCase();
    return low.contains("envíame tu ubicación") ||
        low.contains("enviame tu ubicacion") ||
        low.contains("botón de ubicación") ||
        low.contains("boton de ubicacion");
  }

  bool _looksAskingReference(String botText) {
    final low = botText.toLowerCase();
    return low.contains("indícame una referencia") ||
        low.contains("indicame una referencia") ||
        low.contains("frente a") ||
        low.contains("cerca de") ||
        low.contains("junto a");
  }

  String _normalizeBotText(String input) {
    var s = input.replaceAll('\r\n', '\n').trim();
    if (s.isEmpty) return s;

    s = s.replaceAllMapped(
      RegExp(r'\*\*(.*?)\*\*', dotAll: true),
      (m) => (m.group(1) ?? '').trim(),
    );
    s = s.replaceAllMapped(
      RegExp(r'__(.*?)__', dotAll: true),
      (m) => (m.group(1) ?? '').trim(),
    );
    s = s.replaceAllMapped(
      RegExp(r'`([^`]+)`'),
      (m) => (m.group(1) ?? '').trim(),
    );
    s = s.replaceAllMapped(
      RegExp(r'(?<!\*)\*(?!\s)(.*?)(?<!\s)\*(?!\*)', dotAll: true),
      (m) => (m.group(1) ?? '').trim(),
    );

    s = s.replaceAllMapped(RegExp(r'^\s*\*\s+', multiLine: true), (_) => '• ');
    s = s.replaceAll(RegExp(r'[ \t]+\n'), '\n');
    s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return s.trim();
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

  // ================== Flujo UI ==================

  bool get _tieneEvidenciaSubida => (_fotosSubidas + _videosSubidos) > 0;
  bool get _tieneEvidenciaPendiente => _pendingMedia.isNotEmpty;

  bool get _datosBaseUI =>
      _hasTipo && _hasDescripcion && _hasLocation && _hasReferencia;

  bool get _listaFinalUI =>
      _borradorId != null &&
      _datosBaseUI &&
      _tieneEvidenciaSubida &&
      _firmaSubida &&
      !_tieneEvidenciaPendiente;

  void _activarModoSoloEnviarSiCorresponde() {
    if (!_listaFinalUI) return;
    if (msgController.text.isNotEmpty) msgController.clear();
    if (inputFocus.hasFocus) inputFocus.unfocus();
  }

  String _faltantesHuman() {
    if (_faltantes.isEmpty) return "";
    final map = <String, String>{
      "tipo_denuncia_id": "tipo",
      "descripcion": "descripción",
      "ubicacion": "ubicación",
      "referencia": "referencia",
    };
    final xs = _faltantes.map((x) => map[x] ?? x).toList();
    return "Falta: ${xs.join(', ')}";
  }

  String _nextStepPrompt() {
    if (!_hasTipo) {
      return "Perfecto ✅\n"
          "Primero necesito identificar el tipo de denuncia.\n"
          "Escribe el tipo o, si prefieres, escribe “tipos” para ver la lista.";
    }

    if (!_hasDescripcion) {
      return "Gracias ✅\n"
          "Ahora cuéntame qué pasó en una breve descripción.";
    }

    if (!_hasLocation) {
      return "Listo ✅ Ahora necesito la ubicación 📍.\n"
          "Envíala con el botón de Ubicación de la app.";
    }

    if (!_hasReferencia) {
      return "Perfecto ✅\n"
          "Ahora indícame una referencia para ubicar mejor el lugar.\n"
          "Ejemplo: “frente a…”, “cerca de…”, “junto a…”.";
    }

    return _uploadStagePrompt();
  }

  String _uploadStagePrompt() {
    return "Ya tengo los datos base de tu denuncia ✅\n"
        "Ahora sube evidencia (foto o video) y tu firma para completar el proceso.\n"
        "Cuando todo esté listo, se habilitará el botón negro para enviar.";
  }

  String _buildProgressReply() {
    final datos = <String>[];
    final faltan = <String>[];

    if (_hasTipo) {
      datos.add("• Tipo de denuncia");
    } else {
      faltan.add("• Tipo de denuncia");
    }

    if (_hasDescripcion) {
      datos.add("• Descripción");
    } else {
      faltan.add("• Descripción");
    }

    if (_hasLocation) {
      datos.add("• Ubicación");
    } else {
      faltan.add("• Ubicación");
    }

    if (_hasReferencia) {
      datos.add("• Referencia");
    } else {
      faltan.add("• Referencia");
    }

    if (_tieneEvidenciaSubida) {
      datos.add("• Evidencia");
    } else {
      faltan.add("• Evidencia");
    }

    if (_firmaSubida) {
      datos.add("• Firma");
    } else {
      faltan.add("• Firma");
    }

    final b = StringBuffer();
    b.writeln("Esto tengo registrado hasta ahora ✅");
    b.writeln();

    if (datos.isNotEmpty) {
      for (final d in datos) {
        b.writeln(d);
      }
    } else {
      b.writeln("Aún no tengo datos suficientes.");
    }

    if (faltan.isNotEmpty) {
      b.writeln();
      b.writeln("Todavía falta:");
      for (final f in faltan) {
        b.writeln(f);
      }
    }

    if (_datosBaseUI && !_listaFinalUI) {
      b.writeln();
      b.writeln(
        "Ya están completos los datos base. Ahora necesitas subir evidencia y firma.",
      );
    }

    return b.toString().trim();
  }

  //void _updateFlagsFromFaltantes() {
  //  if (_borradorId == null) return;
  //
  //  if (_faltantes.contains("tipo_denuncia_id")) {
  //    _hasTipo = false;
  //  } else if (_faltantes.isNotEmpty) {
  //    _hasTipo = true;
  //  }
  //
  //  if (_faltantes.contains("descripcion")) {
  //    _hasDescripcion = false;
  //  } else if (_faltantes.isNotEmpty) {
  //    _hasDescripcion = true;
  //  }
  //
  //  if (_faltantes.contains("ubicacion")) {
  //    _hasLocation = false;
  //  } else if (_faltantes.isNotEmpty) {
  //    _hasLocation = true;
  //  }
  //
  //  // referencia la seguimos controlando principalmente desde frontend
  //  if (_faltantes.contains("referencia")) {
  //    _hasReferencia = false;
  //  }
  //}

  void _updateBorradorStateFromResponse(dynamic borr) {
    if (borr is Map) {
      final map = Map<String, dynamic>.from(borr);

      final id = (map["id"] ?? "").toString().trim();
      _borradorId = (id.isNotEmpty && id.toLowerCase() != "null") ? id : null;

      final f = map["faltantes"];
      _faltantes = (f is List)
          ? f.map((e) => e.toString()).toList()
          : <String>[];

      final datosRaw = map["datos"];
      final datos = datosRaw is Map
          ? Map<String, dynamic>.from(datosRaw)
          : <String, dynamic>{};

      final tipoId = datos["tipo_denuncia_id"];
      final descripcion = (datos["descripcion"] ?? "").toString().trim();
      final referencia = (datos["referencia"] ?? "").toString().trim();
      final lat = datos["latitud"];
      final lng = datos["longitud"];

      _hasTipo = tipoId != null && !_faltantes.contains("tipo_denuncia_id");
      _hasDescripcion =
          descripcion.isNotEmpty && !_faltantes.contains("descripcion");
      _hasLocation =
          lat != null && lng != null && !_faltantes.contains("ubicacion");
      _hasReferencia =
          referencia.isNotEmpty && !_faltantes.contains("referencia");
    } else {
      _borradorId = null;
      _faltantes = <String>[];

      _hasTipo = false;
      _hasDescripcion = false;
      _hasLocation = false;
      _hasReferencia = false;
    }
  }

  // ================== Tipos reales ==================

  String _norm(String s) {
    var x = s.toLowerCase().trim();
    x = x.replaceAll(RegExp(r'[áàäâ]'), 'a');
    x = x.replaceAll(RegExp(r'[éèëê]'), 'e');
    x = x.replaceAll(RegExp(r'[íìïî]'), 'i');
    x = x.replaceAll(RegExp(r'[óòöô]'), 'o');
    x = x.replaceAll(RegExp(r'[úùüû]'), 'u');
    x = x.replaceAll('ñ', 'n');
    x = x.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    x = x.replaceAll(RegExp(r'\s+'), ' ').trim();
    return x;
  }

  int _tipoScore(String query, String tipo) {
    final q = _norm(query);
    final t = _norm(tipo);

    if (q.isEmpty || t.isEmpty) return 0;
    if (q == t) return 100;
    if (t.contains(q)) return 85;
    if (q.contains(t)) return 70;

    final qTokens = q.split(' ').where((e) => e.isNotEmpty).toSet();
    final tTokens = t.split(' ').where((e) => e.isNotEmpty).toSet();
    if (qTokens.isEmpty || tTokens.isEmpty) return 0;

    final inter = qTokens.intersection(tTokens).length;
    final union = qTokens.union(tTokens).length;
    final jaccard = union == 0 ? 0.0 : inter / union;

    int bonus = 0;
    if (q.contains("basura") && t.contains("basura")) bonus += 8;
    if (q.contains("quema") && t.contains("quema")) bonus += 8;
    if (q.contains("agua") && t.contains("agua")) bonus += 8;
    if (q.contains("bache") && t.contains("bache")) bonus += 8;
    if (q.contains("alumbrado") && t.contains("alumbrado")) bonus += 8;

    return (50 * jaccard + bonus).round();
  }

  Future<void> _ensureTiposLoaded() async {
    if (_tiposLoaded) return;

    try {
      final res = await repo.tiposV2();

      List<dynamic> raw = [];
      for (final key in ["tipos", "results", "data", "items"]) {
        final v = res[key];
        if (v is List) {
          raw = v;
          break;
        }
      }

      if (raw.isEmpty) {
        for (final v in res.values) {
          if (v is List) {
            raw = v;
            break;
          }
        }
      }

      final List<_TipoItem> items = [];
      for (final e in raw) {
        if (e is Map) {
          final m = Map<String, dynamic>.from(e);
          final nombre = (m["nombre"] ?? m["tipo"] ?? m["name"] ?? "")
              .toString()
              .trim();
          final depto =
              (m["departamento_nombre"] ??
                      m["departamento"] ??
                      m["direccion"] ??
                      "")
                  .toString()
                  .trim();

          if (nombre.isNotEmpty) {
            items.add(_TipoItem(nombre: nombre, depto: depto));
          }
        } else if (e is String && e.trim().isNotEmpty) {
          items.add(_TipoItem(nombre: e.trim(), depto: ""));
        }
      }

      final seen = <String>{};
      final unique = <_TipoItem>[];
      for (final it in items) {
        final k = _norm(it.nombre);
        if (seen.add(k)) unique.add(it);
      }

      _tiposCache = unique;
      _tiposLoaded = true;
      _tiposPage = 0;
    } catch (_) {
      _tiposCache = [];
      _tiposLoaded = true;
      _tiposPage = 0;
    }
  }

  String _tiposPageMessage({required bool includeHint}) {
    if (_tiposCache.isEmpty) {
      return "Puedo ayudarte con denuncias municipales.\n\n"
          "Cuéntame tu caso (por ejemplo: baches, basura, alumbrado, agua potable) "
          "y te ayudo a escoger el tipo correcto.";
    }

    final start = _tiposPage * _tiposPerPage;
    final end = (start + _tiposPerPage) > _tiposCache.length
        ? _tiposCache.length
        : (start + _tiposPerPage);

    final slice = _tiposCache.sublist(start, end);

    final b = StringBuffer();
    b.writeln("Estos son algunos tipos de denuncia disponibles:");
    b.writeln();

    for (final it in slice) {
      b.writeln("• ${it.nombre}");
    }

    if (end < _tiposCache.length) {
      b.writeln();
      b.writeln("Escribe “más” para ver más tipos.");
    }

    if (includeHint) {
      b.writeln();
      b.writeln("También puedes escribir el tipo o describir tu caso.");
    }

    return b.toString().trim();
  }

  List<_TipoItem> _topSuggestions(String userText, {int k = 3}) {
    if (_tiposCache.isEmpty) return [];

    final scored = _tiposCache
        .map((t) => MapEntry(t, _tipoScore(userText, t.nombre)))
        .where((e) => e.value > 0)
        .toList();

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(k).map((e) => e.key).toList();
  }

  _TipoItem? _bestTipoMatch(String userText) {
    if (_tiposCache.isEmpty) return null;

    _TipoItem? best;
    int bestScore = 0;

    for (final t in _tiposCache) {
      final s = _tipoScore(userText, t.nombre);
      if (s > bestScore) {
        bestScore = s;
        best = t;
      }
    }

    if (best != null && bestScore >= 80) return best;
    return null;
  }

  // ================== Persistir archivo ==================

  Future<File> _persistPickedFile(XFile x) async {
    final dir = await getApplicationSupportDirectory();
    final ext = p.extension(x.path);
    final name = "evid_${DateTime.now().millisecondsSinceEpoch}$ext";
    final newPath = p.join(dir.path, name);
    return File(x.path).copy(newPath);
  }

  // ================== Extracted ==================

  Map<String, dynamic> _buildExtracted(String text) {
    final t = text.trim();
    final low = t.toLowerCase();

    if (t.isEmpty) return {};
    if (_isConfirmWord(t) || _isCancelWord(t)) return {};
    if (_isOutOfScope(t)) return {};
    if (_isProgressQuery(t)) return {};

    final m = RegExp(
      r'lat(?:itud)?\s*[:=]?\s*(-?\d+(?:\.\d+)?)\s*.*?(?:lon(?:gitud)?|lng)\s*[:=]?\s*(-?\d+(?:\.\d+)?)',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(t);

    if (m != null) {
      final lat = double.tryParse(m.group(1) ?? "");
      final lng = double.tryParse(m.group(2) ?? "");
      if (lat != null && lng != null) {
        return {"latitud": lat, "longitud": lng};
      }
      return {};
    }

    if (low.startsWith("referencia:")) {
      final v = t.substring("referencia:".length).trim();
      return v.isEmpty ? {} : {"referencia": v};
    }

    if (low.startsWith("dirección:") || low.startsWith("direccion:")) {
      final cut = low.startsWith("dirección:") ? "dirección:" : "direccion:";
      final v = t.substring(cut.length).trim();
      return v.isEmpty ? {} : {"referencia": v};
    }

    if (low.startsWith("tipo:")) {
      final v = t.substring("tipo:".length).trim();
      return v.isEmpty ? {} : {"tipo_texto": v};
    }

    if (low.startsWith("descripcion:") || low.startsWith("descripción:")) {
      final cut = low.startsWith("descripcion:")
          ? "descripcion:"
          : "descripción:";
      final v = t.substring(cut.length).trim();
      return v.isEmpty ? {} : {"descripcion": v};
    }

    // Si ya tengo ubicación y aún falta referencia, priorizar referencia
    final looksLikeReference = RegExp(
      r'^(frente|cerca|junto|alado|al lado|por|por la|por el)\b',
      caseSensitive: false,
    ).hasMatch(t);

    if (_hasLocation && !_hasReferencia) {
      if (looksLikeReference && t.length <= 160) {
        return {"referencia": t};
      }

      if (!t.contains('?') &&
          !_isTiposQuery(t) &&
          !_isMoreTiposQuery(t) &&
          t.length <= 160 &&
          t.split(RegExp(r'\s+')).length <= 12) {
        return {"referencia": t};
      }
    }

    // Si ya tengo tipo pero falta descripción, el siguiente texto útil va como descripción
    if (_hasTipo && !_hasDescripcion && t.length >= 8) {
      return {"descripcion": t};
    }

    // Si aún no hay tipo y el texto es corto, se intenta como tipo_texto
    final words = t.split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
    if (!_hasTipo && words.length <= 6 && t.length <= 60) {
      return {"tipo_texto": t};
    }

    // Fallback a descripción si parece un relato municipal
    const keys = [
      "basura",
      "alumbrado",
      "luminaria",
      "bache",
      "hueco",
      "agua",
      "alcantarillado",
      "fuga",
      "contamin",
      "quema",
      "calle",
      "vereda",
      "acera",
      "obra",
      "parque",
      "riesgo",
      "botadero",
    ];
    final isComplaint = keys.any((k) => low.contains(k));
    if (isComplaint && t.length >= 8) {
      return {"descripcion": t};
    }

    return {};
  }

  // ================== START CHAT ==================

  Future<void> _startChat() async {
    setState(() {
      _starting = true;
      _sending = false;
      _uploadingMedia = false;

      _convId = null;
      _borradorId = null;
      _faltantes = [];

      _hasTipo = false;
      _hasDescripcion = false;
      _hasLocation = false;
      _hasReferencia = false;

      _fotosSubidas = 0;
      _videosSubidos = 0;
      _firmaSubida = false;

      _pendingMedia.clear();
      _mediaFile = null;
      _mediaEsVideo = false;

      _awaitingTipoPick = false;
      _lastTipoSuggestions = [];
      _tiposPage = 0;

      _firmaInteractuada = false;
      signatureController.clear();

      msgController.clear();
      inputFocus.unfocus();

      messages.clear();
    });

    try {
      final access = await Session.access();
      if (access == null || access.isEmpty) {
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
        return;
      }

      await _ensureTiposLoaded();

      final startRes = await repo.startV2();
      _convId = startRes["conversacion_id"]?.toString();

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
    if (_listaFinalUI && overrideText == null) {
      _activarModoSoloEnviarSiCorresponde();
      return;
    }

    String text = (overrideText ?? msgController.text).trim();

    if (text.isEmpty && overrideText == null && _listaFinalUI) {
      text = "enviar";
    }

    if (text.isEmpty) return;
    if (_sending || _starting) return;

    if (_convId == null || _convId!.isEmpty) {
      await _startChat();
      if (_convId == null || _convId!.isEmpty) return;
    }

    // Si está esperando selección 1/2/3
    if (_awaitingTipoPick) {
      final pick = int.tryParse(text.trim());
      if (pick != null && pick >= 1 && pick <= _lastTipoSuggestions.length) {
        final chosen = _lastTipoSuggestions[pick - 1];
        final extractedPick = {"tipo_texto": chosen.nombre};

        await _sendTextInternal(
          userVisibleText: text,
          textForBackend: chosen.nombre,
          forcedExtracted: extractedPick,
          forceBypassGemini: true,
        );
        return;
      }
    }

    await _sendTextInternal(
      userVisibleText: text,
      textForBackend: text,
      forcedExtracted: null,
      forceBypassGemini: false,
    );
  }

  Future<void> _sendTextInternal({
    required String userVisibleText,
    required String textForBackend,
    required Map<String, dynamic>? forcedExtracted,
    required bool forceBypassGemini,
  }) async {
    final visible = userVisibleText.trim();
    final backendText = textForBackend.trim();
    if (visible.isEmpty || backendText.isEmpty) return;

    setState(() {
      _sending = true;
      messages.add(_ChatMessage(text: visible, isMe: true));
      msgController.clear();
      messages.add(
        const _ChatMessage(text: "Escribiendo...", isMe: false, isTyping: true),
      );
    });
    _scrollToBottom();

    try {
      final willConfirm = _isConfirmWord(backendText);
      final tiposQuery = _isTiposQuery(backendText);
      final moreTipos = _isMoreTiposQuery(backendText);
      final progressQuery = _isProgressQuery(backendText);

      // 1) Consultas de progreso
      if (progressQuery) {
        final reply = _buildProgressReply();

        final res = await repo.syncV2(
          conversacionId: _convId!,
          mensaje: backendText,
          botResponse: reply,
          extracted: null,
        );

        _updateBorradorStateFromResponse(res["borrador"]);

        setState(() {
          messages.removeWhere((m) => m.isTyping);
          messages.add(_ChatMessage(text: reply, isMe: false));
          _sending = false;
        });
        _scrollToBottom();
        return;
      }

      // 2) Tipos paginados
      if (tiposQuery) {
        await _ensureTiposLoaded();
        _tiposPage = 0;
        final reply = _tiposPageMessage(includeHint: true);

        final res = await repo.syncV2(
          conversacionId: _convId!,
          mensaje: backendText,
          botResponse: reply,
          extracted: null,
        );

        _updateBorradorStateFromResponse(res["borrador"]);
        _awaitingTipoPick = false;
        _lastTipoSuggestions = [];

        setState(() {
          messages.removeWhere((m) => m.isTyping);
          messages.add(_ChatMessage(text: reply, isMe: false));
          _sending = false;
        });
        _scrollToBottom();
        return;
      }

      if (moreTipos) {
        await _ensureTiposLoaded();
        final maxPage = (_tiposCache.isEmpty)
            ? 0
            : ((_tiposCache.length - 1) ~/ _tiposPerPage);

        if (_tiposPage < maxPage) _tiposPage++;

        final reply = _tiposPageMessage(includeHint: true);

        final res = await repo.syncV2(
          conversacionId: _convId!,
          mensaje: backendText,
          botResponse: reply,
          extracted: null,
        );

        _updateBorradorStateFromResponse(res["borrador"]);

        setState(() {
          messages.removeWhere((m) => m.isTyping);
          messages.add(_ChatMessage(text: reply, isMe: false));
          _sending = false;
        });
        _scrollToBottom();
        return;
      }

      await _ensureTiposLoaded();

      Map<String, dynamic> extracted =
          forcedExtracted ?? _buildExtracted(backendText);

      // Si confirma y hay evidencias pendientes, subir primero
      if (willConfirm && _pendingMedia.isNotEmpty && _borradorId != null) {
        await _tryUploadPendingMedia();
      }

      // 3) Resolver tipo SOLO si todavía NO hay tipo
      if (!_hasTipo &&
          !extracted.containsKey("tipo_texto") &&
          !_isStructuredCommand(backendText) &&
          !willConfirm &&
          !_isLikelyLocationPayload(backendText) &&
          !_isCancelWord(backendText) &&
          !_isOutOfScope(backendText)) {
        final best = _bestTipoMatch(backendText);

        if (best != null) {
          extracted = {...extracted, "tipo_texto": best.nombre};
        } else {
          final top = _topSuggestions(backendText, k: 3);

          if (top.isNotEmpty && backendText.length <= 70) {
            _awaitingTipoPick = true;
            _lastTipoSuggestions = top;

            final msg = StringBuffer()
              ..writeln(
                "Para ayudarte mejor, ¿cuál de estos tipos se parece más a tu caso? ✅",
              )
              ..writeln()
              ..writeln("1) ${top[0].nombre}")
              ..writeln(top.length >= 2 ? "2) ${top[1].nombre}" : "")
              ..writeln(top.length >= 3 ? "3) ${top[2].nombre}" : "")
              ..writeln()
              ..writeln(
                "Responde con 1, 2 o 3. También puedes escribir “tipos” para ver la lista.",
              );

            final reply = msg.toString().trim();

            final res = await repo.syncV2(
              conversacionId: _convId!,
              mensaje: backendText,
              botResponse: reply,
              extracted: extracted.isEmpty ? null : extracted,
            );

            _updateBorradorStateFromResponse(res["borrador"]);

            setState(() {
              messages.removeWhere((m) => m.isTyping);
              messages.add(_ChatMessage(text: reply, isMe: false));
              _sending = false;
            });
            _scrollToBottom();
            return;
          }
        }
      } else {
        _awaitingTipoPick = false;
        _lastTipoSuggestions = [];
      }

      // 4) Actualizar flags por lo que el usuario acaba de mandar
      if (extracted.containsKey("tipo_texto")) _hasTipo = true;
      if (extracted.containsKey("descripcion")) _hasDescripcion = true;
      if (extracted.containsKey("referencia")) _hasReferencia = true;
      if (extracted.containsKey("latitud") &&
          extracted.containsKey("longitud")) {
        _hasLocation = true;
      }

      final bypassGemini =
          forceBypassGemini ||
          willConfirm ||
          _isStructuredCommand(backendText) ||
          _isLikelyLocationPayload(backendText);

      String geminiText = "";
      String? botResponseToSend;

      if (_isOutOfScope(backendText)) {
        geminiText = await botService.askGemini(backendText);
        if (!geminiText.startsWith("⚠️")) {
          botResponseToSend = _normalizeBotText(geminiText);
        }
      } else if (!bypassGemini) {
        geminiText = await botService.askGemini(backendText);
        if (!geminiText.startsWith("⚠️")) {
          botResponseToSend = _normalizeBotText(geminiText);
        }
      }

      // 5) Sync backend
      final res = await repo.syncV2(
        conversacionId: _convId!,
        mensaje: backendText,
        botResponse: botResponseToSend,
        extracted: extracted.isEmpty ? null : extracted,
      );

      _updateBorradorStateFromResponse(res["borrador"]);
      _activarModoSoloEnviarSiCorresponde();

      String serverText =
          (res["respuesta"] ?? (botResponseToSend ?? geminiText))
              .toString()
              .trim();

      serverText = _normalizeBotText(serverText);

      // Fuera de alcance: mostrar SIEMPRE la respuesta de Gemini
      if (_isOutOfScope(backendText) && botResponseToSend != null) {
        serverText = botResponseToSend;
      }

      // 6) Evitar preguntas redundantes
      if (_hasTipo && _looksAskingTipo(serverText)) {
        serverText = _nextStepPrompt();
      }
      if (_hasDescripcion && _looksAskingDescripcion(serverText)) {
        serverText = _nextStepPrompt();
      }
      if (_hasLocation && _looksAskingLocation(serverText)) {
        serverText = _nextStepPrompt();
      }
      if (_hasReferencia && _looksAskingReference(serverText)) {
        serverText = _nextStepPrompt();
      }

      // 7) Si ya están completos los datos textuales, NO permitir flujo "sí/no"
      if (_datosBaseUI) {
        serverText = _uploadStagePrompt();
      } else if (serverText.isEmpty) {
        serverText = _nextStepPrompt();
      }

      final denunciaIdRaw = (res["denuncia_id"] ?? "").toString().trim();
      final denunciaId =
          (denunciaIdRaw.isNotEmpty && denunciaIdRaw.toLowerCase() != "null")
          ? denunciaIdRaw
          : null;

      setState(() {
        messages.removeWhere((m) => m.isTyping);
        messages.add(_ChatMessage(text: serverText, isMe: false));
        _sending = false;
      });
      _scrollToBottom();

      if (denunciaId != null) {
        _pendingMedia.clear();
        _mediaFile = null;
        _mediaEsVideo = false;

        _borradorId = null;
        _faltantes = [];

        _hasTipo = false;
        _hasDescripcion = false;
        _hasLocation = false;
        _hasReferencia = false;

        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/denuncias', (r) => false);
        return;
      }

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
    if (_hasLocation) return;

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

      _hasLocation = true;
      await _sendText("lat: ${pos.latitude} lng: ${pos.longitude}");
    } catch (_) {
      _toast("❌ No se pudo obtener ubicación.");
    }
  }

  // ================== EVIDENCIA ==================

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

    if (_borradorId != null &&
        _borradorId!.isNotEmpty &&
        !_sending &&
        !_starting) {
      await _tryUploadPendingMedia();
    }
  }

  Future<void> _pickFoto() async {
    final picker = ImagePicker();
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
      _pendingMedia.removeWhere((e) => e.file.path == previewPath);
      _mediaFile = null;
      _mediaEsVideo = false;

      if (_pendingMedia.isNotEmpty) {
        final last = _pendingMedia.last;
        _mediaFile = last.file;
        _mediaEsVideo = last.isVideo;
      }
    });
  }

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

          if (_mediaFile?.path == item.file.path) {
            if (_pendingMedia.isNotEmpty) {
              final last = _pendingMedia.last;
              _mediaFile = last.file;
              _mediaEsVideo = last.isVideo;
            } else {
              _mediaFile = null;
              _mediaEsVideo = false;
            }
          }
        });

        _scrollToBottom();
      }

      _activarModoSoloEnviarSiCorresponde();
    } catch (e) {
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
    if (_borradorId == null || _borradorId!.isEmpty || !_datosBaseUI) {
      _toast("⚠️ Primero completa tipo, descripción, ubicación y referencia.");
      return;
    }

    try {
      final bytes = await _obtenerFirmaBytesObligatoria();
      await repo.subirFirma(borradorId: _borradorId!, pngBytes: bytes);

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

      _activarModoSoloEnviarSiCorresponde();
      _scrollToBottom();
    } catch (e) {
      await _handleApiError(e);
    }
  }

  // ================== BOTTOM SHEETS / DIALOGS ==================
  // LA PARTE 2 CONTINÚA DESDE AQUÍ
  // ================== BOTTOM SHEETS / DIALOGS ==================
  // ================== BOTTOM SHEETS / DIALOGS ==================
  void _openAttachmentsSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            "Firma",
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            height: 190,
            width: double.maxFinite,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(14),
                color: Colors.white,
              ),
              clipBehavior: Clip.antiAlias,
              child: Listener(
                onPointerDown: (_) {
                  if (!_firmaInteractuada && mounted) {
                    setState(() => _firmaInteractuada = true);
                  }
                },
                onPointerMove: (_) {
                  if (!_firmaInteractuada && mounted) {
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
                if (mounted) setState(() => _firmaInteractuada = false);
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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

    if (index == 0) {
      Navigator.pushNamed(context, '/denuncias');
      return;
    }
    if (index == 1) {
      Navigator.pushNamed(context, '/form/denuncias');
      return;
    }
    if (index == 2) return;
    if (index == 3) {
      Navigator.pushNamed(context, '/mapadenuncias');
      return;
    }
  }

  // ================== UI ==================
  @override
  Widget build(BuildContext context) {
    final hasAttachmentPreview = _mediaFile != null;
    final pendingCount = _pendingMedia.length;

    final bool hasUploadedEvidence = _tieneEvidenciaSubida;
    final bool hasPendingEvidence = _tieneEvidenciaPendiente;
    final bool readyToFinalSubmit = _listaFinalUI;

    // ✅ Cuando datos base ya están completos, bloqueamos escritura
    // y dejamos solo evidencia + firma.
    final bool lockTextByBaseReady =
        _borradorId != null && _datosBaseUI && !readyToFinalSubmit;

    // ✅ Cuando todo está completo, bloqueamos todo menos botón final.
    final bool lockComposerByFinal = readyToFinalSubmit;

    final bool isBusy = _sending || _starting || _uploadingMedia;

    final bool canUseAttach =
        !isBusy && _borradorId != null && _datosBaseUI && !readyToFinalSubmit;

    final bool canUseLocation =
        !isBusy && !lockComposerByFinal && !_hasLocation && !_datosBaseUI;

    final bool canUseFirma =
        !isBusy && _borradorId != null && _datosBaseUI && !readyToFinalSubmit;

    final bool canType =
        !_starting &&
        !_uploadingMedia &&
        !lockTextByBaseReady &&
        !lockComposerByFinal;

    final bool canTapPrimary =
        !isBusy &&
        (readyToFinalSubmit || (!lockTextByBaseReady && !lockComposerByFinal));

    final bool primarySendsDenuncia = readyToFinalSubmit;

    final String inputHint = _uploadingMedia
        ? 'Subiendo evidencia...'
        : readyToFinalSubmit
        ? 'Todo listo ✅ Presiona el botón negro para enviar'
        : lockTextByBaseReady
        ? 'Adjunta evidencia y firma para habilitar el envío'
        : (_awaitingTipoPick ? 'Responde 1, 2 o 3…' : 'Escribir mensaje...');

    return Scaffold(
      backgroundColor: Colors.white,

      // Drawer
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 10),
              FutureBuilder<List<dynamic>>(
                future: Future.wait<dynamic>([Session.tipo(), Session.email()]),
                builder: (context, snap) {
                  final data = snap.data ?? const [];
                  final tipo =
                      (data.isNotEmpty ? data[0] : null) ?? "Ciudadano";
                  final email =
                      (data.length > 1 ? data[1] : null) ?? "sin correo";
                  final emailStr = email.toString();
                  final letra = emailStr.isNotEmpty
                      ? emailStr[0].toUpperCase()
                      : "C";

                  return ListTile(
                    leading: CircleAvatar(child: Text(letra)),
                    title: Text(
                      tipo.toString() == "ciudadano"
                          ? "Ciudadano"
                          : tipo.toString(),
                    ),
                    subtitle: Text(emailStr),
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
          style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w700),
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
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
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
              child: const Center(
                child: Text(
                  "Iniciando conversación...",
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ),

          // Chips de estado
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
                      label: _datosBaseUI
                          ? "datos base OK"
                          : (_faltantesHuman().isEmpty
                                ? "completando datos"
                                : _faltantesHuman()),
                      ok: _datosBaseUI,
                      warning: !_datosBaseUI,
                    ),

                  if (_borradorId != null)
                    _miniChip(
                      label: hasPendingEvidence
                          ? "evidencia pendiente ($pendingCount)"
                          : (hasUploadedEvidence
                                ? "evidencia OK"
                                : "Falta: evidencia"),
                      ok: hasUploadedEvidence && !hasPendingEvidence,
                      warning: !hasUploadedEvidence || hasPendingEvidence,
                    ),

                  if (_borradorId != null)
                    _miniChip(
                      label: _firmaSubida ? "✍️ firma OK" : "Falta: firma",
                      ok: _firmaSubida,
                      warning: !_firmaSubida,
                    ),

                  if (_fotosSubidas > 0) _countChip("📷", _fotosSubidas),
                  if (_videosSubidos > 0) _countChip("🎥", _videosSubidos),

                  if (readyToFinalSubmit)
                    _miniChip(label: "lista para enviar", ok: true),
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
                  //if (lockTextByBaseReady)
                  //  Container(
                  //    width: double.infinity,
                  //    margin: const EdgeInsets.only(bottom: 10),
                  //    padding: const EdgeInsets.symmetric(
                  //      horizontal: 14,
                  //      vertical: 12,
                  //    ),
                  //    decoration: BoxDecoration(
                  //      color: Colors.green.shade50,
                  //      borderRadius: BorderRadius.circular(16),
                  //      border: Border.all(color: Colors.green.shade200),
                  //    ),
                  //    child: Text(
                  //      "Ya tengo los datos base de tu denuncia ✅\n"
                  //      "Ahora adjunta evidencia (foto/video) y tu firma para habilitar el envío final.",
                  //      style: TextStyle(
                  //        color: Colors.green.shade900,
                  //        fontSize: 13,
                  //        height: 1.3,
                  //        fontWeight: FontWeight.w600,
                  //      ),
                  //    ),
                  //  ),
                  //
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
                            onPressed: canUseAttach ? _removeAttachment : null,
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
                          tooltip: _datosBaseUI
                              ? "Adjuntar evidencia"
                              : "Completa primero los datos base",
                          onTap: canUseAttach ? _openAttachmentsSheet : null,
                        ),
                        const SizedBox(width: 6),
                        _RoundIconBtn(
                          icon: Icons.my_location,
                          tooltip: _hasLocation
                              ? "Ubicación ya enviada"
                              : "Enviar ubicación",
                          onTap: canUseLocation ? _sendCurrentLocation : null,
                        ),
                        const SizedBox(width: 6),
                        _RoundIconBtn(
                          icon: Icons.border_color_outlined,
                          tooltip: _datosBaseUI
                              ? "Subir firma"
                              : "Completa primero los datos base",
                          onTap: canUseFirma ? _openFirmaDialog : null,
                        ),
                        const SizedBox(width: 8),

                        Expanded(
                          child: TextField(
                            focusNode: inputFocus,
                            controller: msgController,
                            minLines: 1,
                            maxLines: 4,
                            enabled: canType,
                            onSubmitted: (_) => _sendText(),
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: inputHint,
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
                          onTap: canTapPrimary
                              ? () => _sendText(
                                  primarySendsDenuncia ? "enviar" : null,
                                )
                              : null,
                          borderRadius: BorderRadius.circular(999),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: !canTapPrimary
                                  ? Colors.grey
                                  : (primarySendsDenuncia
                                        ? Colors.black87
                                        : primaryBlue),
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: !canTapPrimary
                                  ? null
                                  : [
                                      BoxShadow(
                                        color:
                                            (primarySendsDenuncia
                                                    ? Colors.black
                                                    : primaryBlue)
                                                .withValues(alpha: 0.15),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
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
                                : Icon(
                                    primarySendsDenuncia
                                        ? Icons.check
                                        : Icons.send,
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
                      style: TextStyle(color: fg, fontSize: 13.7, height: 1.3),
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
    final border = isMe
        ? Colors.white.withValues(alpha: 0.35)
        : Colors.grey.shade400;

    return Container(
      width: 240,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(14),
        color: isMe
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.60),
      ),
      child: Row(
        children: [
          if (!att.isVideo)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                att.file,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.image_not_supported_outlined),
                ),
              ),
            )
          else
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.08),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: CircleAvatar(
        backgroundColor: Colors.grey.shade200,
        child: Icon(icon, color: Colors.black87),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
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
