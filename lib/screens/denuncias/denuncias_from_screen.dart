import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';

import '../../settings/session.dart';
import '../../repositories/denuncias_repository.dart';

class DenunciasFormScreen extends StatefulWidget {
  const DenunciasFormScreen({super.key});

  @override
  State<DenunciasFormScreen> createState() => _DenunciasFormScreenState();
}

class _DenunciasFormScreenState extends State<DenunciasFormScreen> {
  static const Color primaryBlue = Color(0xFF2C64C4);

  final formKey = GlobalKey<FormState>();
  bool _enviando = false;

  int currentIndex = 1;

  // Controllers
  final descripcionController = TextEditingController();
  final referenciaController = TextEditingController();

  // Tipo denuncia
  String? tipoDenuncia;
  final List<String> tipos = const [
    'Alumbrado público',
    'Basura / Aseo',
    'Vías / Baches',
    'Seguridad',
    'Ruido',
    'Otro',
  ];

  // Mapa/Ubicación
  GoogleMapController? mapController;
  Position? currentPosition;
  LatLng? puntoDenuncia;
  Set<Marker> markers = {};

  // =========================
  // EVIDENCIAS MULTIPLES
  // =========================
  final List<File> _fotos = [];
  final List<File> _videos = [];

  // Para mostrar evidencias cuando editas (urls del backend)
  final List<Map<String, dynamic>> _evidenciasRemotas = []; // {tipo,url}
  bool get _tieneEvidencias =>
      _fotos.isNotEmpty || _videos.isNotEmpty || _evidenciasRemotas.isNotEmpty;

  // Firma (canvas)
  final SignatureController signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  bool _firmaInteractuada = false;

  // Firma remota (si ya existe en borrador)
  String? _firmaUrlRemota;
  bool get _firmaBloqueada =>
      _modoEditarBorrador && (_firmaUrlRemota?.trim().isNotEmpty ?? false);

  // ======= MODO EDICIÓN BORRADOR =======
  bool _modoEditarBorrador = false;
  String? _borradorId;
  Map<String, dynamic>? _borradorData;
  bool _argsCargados = false;

  @override
  void initState() {
    super.initState();
    _initUbicacion();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_argsCargados) return;
    _argsCargados = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final modo = (args["modo"] ?? "").toString();
      if (modo == "editar_borrador") {
        _modoEditarBorrador = true;
        _borradorId = (args["borrador_id"] ?? "").toString();
        final data = args["data"];
        if (data is Map) {
          _borradorData = Map<String, dynamic>.from(data);
          _precargarDesdeBorrador(_borradorData!);
        }
      }
    }
  }

  // =========================
  // Precarga edición
  // =========================
  void _precargarDesdeBorrador(Map<String, dynamic> b) {
    final desc = (b["descripcion"] ?? "").toString();
    final ref = (b["referencia"] ?? "").toString();
    if (desc.isNotEmpty) descripcionController.text = desc;
    if (ref.isNotEmpty) referenciaController.text = ref;

    final tipoId = b["tipo_denuncia_id"];
    if (tipoId is int && tipoId >= 1 && tipoId <= tipos.length) {
      tipoDenuncia = tipos[tipoId - 1];
    } else if (tipoId is String) {
      final parsed = int.tryParse(tipoId);
      if (parsed != null && parsed >= 1 && parsed <= tipos.length) {
        tipoDenuncia = tipos[parsed - 1];
      }
    }

    final lat = _toDouble(b["latitud"]);
    final lng = _toDouble(b["longitud"]);
    if (lat != null && lng != null) {
      final p = LatLng(lat, lng);
      puntoDenuncia = p;
      markers = {
        Marker(
          markerId: const MarkerId('denuncia'),
          position: p,
          infoWindow: const InfoWindow(title: 'Lugar de denuncia'),
        ),
      };

      WidgetsBinding.instance.addPostFrameCallback((_) {
        mapController?.animateCamera(CameraUpdate.newLatLngZoom(p, 16));
        if (mounted) setState(() {});
      });
    }

    // ===== Firma remota (bloquea canvas) =====
    // puede venir como firma_url directo o firma: {firma_url: ...}
    final firmaUrl =
        (b["firma_url"] ?? b["firmaUrl"] ?? b["url_firma"])?.toString() ??
        (b["firma"] is Map
            ? (b["firma"]["firma_url"] ?? b["firma"]["url"])?.toString()
            : null);

    if (firmaUrl != null && firmaUrl.trim().isNotEmpty) {
      _firmaUrlRemota = firmaUrl.trim();
      signatureController.clear();
      _firmaInteractuada = false;
    }

    // ===== Evidencias remotas =====
    _evidenciasRemotas.clear();

    final raw =
        b["evidencias"] ??
        b["evidencia"] ??
        b["media"] ??
        (b["results"] ?? null);

    List list = [];
    if (raw is List) {
      list = raw;
    } else if (raw is Map && raw["results"] is List) {
      list = raw["results"] as List;
    }

    for (final e in list) {
      if (e is Map) {
        final tipo = (e["tipo"] ?? "").toString().toLowerCase().trim();
        final url = (e["url_archivo"] ?? e["url"] ?? "").toString().trim();
        if (url.isEmpty) continue;
        _evidenciasRemotas.add({
          "tipo": tipo.isEmpty ? "archivo" : tipo,
          "url": url,
        });
      }
    }

    if (mounted) setState(() {});
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  @override
  void dispose() {
    descripcionController.dispose();
    referenciaController.dispose();
    signatureController.dispose();
    super.dispose();
  }

  // =========================
  // Ubicación
  // =========================
  Future<void> _initUbicacion() async {
    final ok = await _permisosUbicacion();
    if (!ok) return;

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      currentPosition = pos;

      if (puntoDenuncia == null) {
        puntoDenuncia = LatLng(pos.latitude, pos.longitude);
        markers = {
          Marker(
            markerId: const MarkerId('denuncia'),
            position: puntoDenuncia!,
            infoWindow: const InfoWindow(title: 'Lugar de denuncia'),
          ),
        };
      }
    });
  }

  Future<bool> _permisosUbicacion() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      _snack('Activa el GPS del teléfono');
      return false;
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      _snack('Permiso de ubicación denegado');
      return false;
    }
    if (perm == LocationPermission.deniedForever) {
      _snack('Permiso denegado permanentemente. Habilítalo en Ajustes.');
      return false;
    }
    return true;
  }

  // =========================
  // Evidencias: pick multiple
  // =========================
  Future<void> _pickFotosMultiples() async {
    final picker = ImagePicker();
    final xs = await picker.pickMultiImage(imageQuality: 85);
    if (xs.isEmpty) return;

    setState(() {
      for (final x in xs) {
        _fotos.add(File(x.path));
      }
    });
  }

  Future<void> _pickFotoUna() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x == null) return;

    setState(() {
      _fotos.add(File(x.path));
    });
  }

  Future<void> _pickVideoUno() async {
    final picker = ImagePicker();
    final x = await picker.pickVideo(source: ImageSource.gallery);
    if (x == null) return;

    setState(() {
      _videos.add(File(x.path));
    });
  }

  void _removeFoto(int index) {
    setState(() => _fotos.removeAt(index));
  }

  void _removeVideo(int index) {
    setState(() => _videos.removeAt(index));
  }

  // =========================
  // Firma
  // =========================
  bool _firmaValida() {
    final pts = signatureController.points;
    return _firmaInteractuada && pts.isNotEmpty && pts.length >= 2;
  }

  Future<List<int>> _obtenerFirmaBytesObligatoria() async {
    if (_firmaBloqueada) {
      throw Exception(
        "La firma ya existe en el borrador (no se vuelve a firmar).",
      );
    }

    if (!_firmaValida()) {
      throw Exception("Firma obligatoria: no se detectó firma válida.");
    }

    await Future.delayed(const Duration(milliseconds: 80));

    final pts = signatureController.points;
    if (pts.isEmpty || pts.length < 2) {
      throw Exception("Firma obligatoria: no se capturaron trazos.");
    }

    final png = await signatureController.toPngBytes();
    if (png == null || png.isEmpty) {
      throw Exception("Firma obligatoria: no se pudo generar PNG.");
    }

    return png;
  }

  // =========================
  // Enviar denuncia (mantiene tu rollback)
  // =========================
  Future<void> _denunciar() async {
    if (!formKey.currentState!.validate()) return;

    if (puntoDenuncia == null) {
      _snack('Selecciona el lugar de la denuncia en el mapa');
      return;
    }

    // Firma obligatoria SOLO si no hay firma remota
    if (!_firmaBloqueada && !_firmaValida()) {
      _snack('Firma antes de enviar');
      return;
    }

    if (_enviando) return;

    final idx = tipos.indexOf(tipoDenuncia ?? "");
    if (idx == -1) {
      _snack("Tipo de denuncia inválido");
      return;
    }
    final tipoId = idx + 1;

    final lat = puntoDenuncia!.latitude;
    final lng = puntoDenuncia!.longitude;

    setState(() => _enviando = true);

    final repo = DenunciasRepository();
    String borradorIdFinal = "";
    bool borradorCreadoEnEsteEnvio = false;

    try {
      // 1) Firma bytes (solo si hace falta)
      List<int>? firmaBytes;
      if (!_firmaBloqueada) {
        firmaBytes = await _obtenerFirmaBytesObligatoria();
      }

      // 2) Crear/Actualizar borrador
      if (_modoEditarBorrador) {
        final id = _borradorId;
        if (id == null || id.isEmpty) {
          throw Exception("No llegó borrador_id para editar");
        }

        await repo.actualizarBorrador(
          borradorId: id,
          tipoDenunciaId: tipoId,
          descripcion: descripcionController.text.trim(),
          latitud: lat,
          longitud: lng,
          referencia: referenciaController.text.trim(),
        );
        borradorIdFinal = id;
      } else {
        final res = await repo.crearBorrador(
          tipoDenunciaId: tipoId,
          descripcion: descripcionController.text.trim(),
          latitud: lat,
          longitud: lng,
          referencia: referenciaController.text.trim(),
          origen: "formulario",
        );

        borradorIdFinal = (res["borrador_id"] ?? "").toString();
        if (borradorIdFinal.isEmpty) {
          throw Exception("No llegó borrador_id del backend");
        }
        borradorCreadoEnEsteEnvio = true;
      }

      // 3) Subir evidencias nuevas (MULTIPLES)
      for (final f in _fotos) {
        await repo.subirEvidenciaBorrador(
          borradorId: borradorIdFinal,
          archivo: f,
          tipo: "foto",
        );
      }
      for (final v in _videos) {
        await repo.subirEvidenciaBorrador(
          borradorId: borradorIdFinal,
          archivo: v,
          tipo: "video",
        );
      }

      // 4) Subir firma (solo si no existía)
      if (!_firmaBloqueada && firmaBytes != null) {
        await repo.subirFirmaBorrador(
          borradorId: borradorIdFinal,
          pngBytes: firmaBytes,
        );
      }

      _snack(" Denuncia enviada correctamente.");

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/denuncias', (r) => false);
    } catch (e) {
      // ROLLBACK si creó borrador en este envío
      if (borradorCreadoEnEsteEnvio && borradorIdFinal.isNotEmpty) {
        try {
          await repo.eliminarBorrador(borradorIdFinal);
        } catch (_) {}
      }
      _snack("❌ Error: $e");
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _abrirChatbot() {
    Navigator.pushNamed(context, '/chatbot');
    _snack('Chatbot 🤖 (solo frontend)');
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // Navegación inferior (NO TOCAR)
  void _onBottomNavTap(int index) {
    setState(() => currentIndex = index);

    if (index == 0) Navigator.pushNamed(context, '/denuncias');
    if (index == 1) Navigator.pushNamed(context, '/form/denuncias');
    if (index == 2) Navigator.pushNamed(context, '/chatbot');
    if (index == 3) Navigator.pushNamed(context, '/mapadenuncias');
  }

  // =========================
  // UI evidencias (preview)
  // =========================
  Widget _chipFile({
    required IconData icon,
    required String label,
    required VoidCallback onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.shade300),
        color: Colors.white,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: primaryBlue),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(label, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 6),
          InkWell(onTap: onRemove, child: const Icon(Icons.close, size: 18)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pos = currentPosition;

    return Scaffold(
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
          "Denuncias",
          style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w600),
        ),
        actions: [
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

      // BODY (validaciones intactas)
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: formKey,
          child: Column(
            children: [
              _label('Tipo de denuncia'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: tipoDenuncia,
                items: tipos
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => tipoDenuncia = v),
                validator: (v) => (v == null || v.isEmpty)
                    ? 'Seleccione el tipo de denuncia'
                    : null,
                decoration: InputDecoration(
                  hintText: 'seleccione el tipo de denuncia',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              _label('Descripcion'),
              const SizedBox(height: 8),
              TextFormField(
                controller: descripcionController,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'La descripción es requerida';
                  }
                  if (v.trim().length < 10) {
                    return 'Describe un poco más (mín. 10 caracteres)';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  hintText: 'ej. quiero denunciar que .....',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              _label('Mapa'),
              const SizedBox(height: 8),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                clipBehavior: Clip.antiAlias,
                child: pos == null
                    ? const Center(child: CircularProgressIndicator())
                    : GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target:
                              puntoDenuncia ??
                              LatLng(pos.latitude, pos.longitude),
                          zoom: 16,
                        ),
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        markers: markers,
                        onMapCreated: (c) {
                          mapController = c;
                          if (puntoDenuncia != null) {
                            c.animateCamera(
                              CameraUpdate.newLatLngZoom(puntoDenuncia!, 16),
                            );
                          }
                        },
                        onTap: (latLng) {
                          setState(() {
                            puntoDenuncia = latLng;
                            markers = {
                              Marker(
                                markerId: const MarkerId('denuncia'),
                                position: latLng,
                                infoWindow: const InfoWindow(
                                  title: 'Lugar de denuncia',
                                ),
                              ),
                            };
                          });
                        },
                      ),
              ),

              const SizedBox(height: 15),

              _label('Subir evidencias (fotos y/o videos)'),
              const SizedBox(height: 8),

              // Botones (multiples)
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _pickFotosMultiples,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Fotos'),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _pickVideoUno,
                      icon: const Icon(Icons.videocam),
                      label: const Text('Video'),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Botón extra por si el cel no soporta pickMulti en algunos casos
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _pickFotoUna,
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text("Agregar 1 foto"),
                ),
              ),

              // Preview evidencias nuevas + remotas
              if (_tieneEvidencias) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Evidencias seleccionadas: "
                    "${_fotos.length} foto(s), ${_videos.length} video(s)"
                    "${_evidenciasRemotas.isNotEmpty ? " • +${_evidenciasRemotas.length} en el borrador" : ""}",
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    // Fotos nuevas
                    for (int i = 0; i < _fotos.length; i++)
                      _chipFile(
                        icon: Icons.image,
                        label: _fotos[i].path.split('/').last,
                        onRemove: () => _removeFoto(i),
                      ),

                    // Videos nuevos
                    for (int i = 0; i < _videos.length; i++)
                      _chipFile(
                        icon: Icons.videocam,
                        label: _videos[i].path.split('/').last,
                        onRemove: () => _removeVideo(i),
                      ),

                    // Remotas (solo visual, no se eliminan aquí)
                    for (final ev in _evidenciasRemotas)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.grey.shade300),
                          color: Colors.grey.shade100,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              (ev["tipo"]?.toString().toLowerCase().contains(
                                        "video",
                                      ) ??
                                      false)
                                  ? Icons.videocam
                                  : Icons.image,
                              size: 18,
                              color: Colors.black54,
                            ),
                            const SizedBox(width: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 200),
                              child: Text(
                                "Borrador: ${(ev["url"] ?? "").toString().split('/').last}",
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],

              const SizedBox(height: 15),

              _label('Referencia del lugar'),
              const SizedBox(height: 8),
              TextFormField(
                controller: referenciaController,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ingrese una referencia del lugar'
                    : null,
                decoration: InputDecoration(
                  hintText: 'ej. frente al parque central, junto a...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              _label('Firma'),
              const SizedBox(height: 8),

              // Firma: si ya existe, se bloquea y se muestra imagen
              if (_firmaBloqueada) ...[
                Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey.shade300),
                    color: Colors.white,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.network(
                    _firmaUrlRemota!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Text("No se pudo cargar la firma guardada."),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Firma ya registrada (no es necesario firmar nuevamente).",
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
              ] else ...[
                Container(
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey.shade300),
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
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      signatureController.clear();
                      setState(() => _firmaInteractuada = false);
                    },
                    child: const Text('Limpiar firma'),
                  ),
                ),
              ],

              const SizedBox(height: 15),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: _enviando ? null : _denunciar,
                  style: TextButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    _modoEditarBorrador ? 'Guardar cambios' : 'Denunciar',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryBlue,
        shape: const CircleBorder(),
        onPressed: _abrirChatbot,
        child: const Icon(Icons.smart_toy, color: Colors.white),
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: _onBottomNavTap,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        selectedItemColor: primaryBlue,
        unselectedItemColor: Colors.grey.shade600,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Inicio"),
          BottomNavigationBarItem(
            icon: Icon(Icons.format_align_center),
            label: "denuncias",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.smart_toy), label: "chat"),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: "mapa"),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(color: primaryBlue, fontWeight: FontWeight.w600),
      ),
    );
  }
}
