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

  // Media
  File? mediaFile;
  bool mediaEsVideo = false;

  // Firma
  final SignatureController signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

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

    // Cargar args SOLO UNA vez (aquí sí existe context)
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

  void _precargarDesdeBorrador(Map<String, dynamic> b) {
    // Descripción / referencia
    final desc = (b["descripcion"] ?? "").toString();
    final ref = (b["referencia"] ?? "").toString();
    if (desc.isNotEmpty) descripcionController.text = desc;
    if (ref.isNotEmpty) referenciaController.text = ref;

    // Tipo por id (1..6)
    final tipoId = b["tipo_denuncia_id"];
    if (tipoId is int && tipoId >= 1 && tipoId <= tipos.length) {
      tipoDenuncia = tipos[tipoId - 1];
    } else if (tipoId is String) {
      final parsed = int.tryParse(tipoId);
      if (parsed != null && parsed >= 1 && parsed <= tipos.length) {
        tipoDenuncia = tipos[parsed - 1];
      }
    }

    // Ubicación lat/lng
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

      // mover cámara si el mapa ya está creado
      WidgetsBinding.instance.addPostFrameCallback((_) {
        mapController?.animateCamera(CameraUpdate.newLatLngZoom(p, 16));
        if (mounted) setState(() {});
      });
    } else {
      if (mounted) setState(() {});
    }
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

  Future<void> _initUbicacion() async {
    final ok = await _permisosUbicacion();
    if (!ok) return;

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      currentPosition = pos;

      // Si NO hay punto precargado, usa mi ubicación actual
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

  Future<void> _pickFoto() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x == null) return;
    setState(() {
      mediaFile = File(x.path);
      mediaEsVideo = false;
    });
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final x = await picker.pickVideo(source: ImageSource.gallery);
    if (x == null) return;
    setState(() {
      mediaFile = File(x.path);
      mediaEsVideo = true;
    });
  }

  Future<void> _denunciar() async {
    if (!formKey.currentState!.validate()) return;

    if (puntoDenuncia == null) {
      _snack('Selecciona el lugar de la denuncia en el mapa');
      return;
    }
    if (signatureController.isEmpty) {
      _snack('Firma antes de enviar');
      return;
    }

    if (_enviando) return;

    // texto -> id (1..6)
    final idx = tipos.indexOf(tipoDenuncia ?? "");
    if (idx == -1) {
      _snack("Tipo de denuncia inválido");
      return;
    }
    final tipoId = idx + 1;

    final lat = puntoDenuncia!.latitude;
    final lng = puntoDenuncia!.longitude;

    setState(() => _enviando = true);

    try {
      final repo = DenunciasRepository();

      if (_modoEditarBorrador) {
        final id = _borradorId;
        if (id == null || id.isEmpty) {
          _snack("❌ No llegó borrador_id para editar");
          return;
        }

        // PUT /api/denuncias/borradores/<id>/
        final res = await repo.actualizarBorrador(
          borradorId: id,
          tipoDenunciaId: tipoId,
          descripcion: descripcionController.text.trim(),
          latitud: lat,
          longitud: lng,
          referencia: referenciaController.text.trim(),
          // direccionTexto: null,
        );

        final expSeg =
            (res["expira_en_seg"] ?? _borradorData?["expira_en_seg"] ?? 0);
        _snack("✅ Cambios guardados. Expira en $expSeg seg.");

        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/denuncias', (r) => false);
      } else {
        // POST /api/denuncias/borradores/
        final res = await repo.crearBorrador(
          tipoDenunciaId: tipoId,
          descripcion: descripcionController.text.trim(),
          latitud: lat,
          longitud: lng,
          referencia: referenciaController.text.trim(),
          origen: "formulario",
        );

        final borradorId = (res["borrador_id"] ?? res["id"] ?? "").toString();
        final expSeg = (res["expira_en_seg"] ?? 0);

        _snack("✅ Borrador creado ($borradorId). Expira en $expSeg seg.");

        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/denuncias', (r) => false);
      }
    } catch (e) {
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
              // Tipo
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

              // Descripción
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

              // Mapa
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
                          // Si venimos editando y ya hay punto, centra
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

              // Media
              _label('Subir Foto o video'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _pickFoto,
                      icon: const Icon(Icons.photo),
                      label: const Text('Foto'),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _pickVideo,
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

              const SizedBox(height: 10),

              if (mediaFile != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        mediaEsVideo ? Icons.videocam : Icons.image,
                        color: primaryBlue,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          mediaFile!.path.split('/').last,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => mediaFile = null),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 15),

              // Referencia
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

              // Firma
              _label('Firma'),
              const SizedBox(height: 8),
              Container(
                height: 140,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                clipBehavior: Clip.antiAlias,
                child: Signature(
                  controller: signatureController,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => signatureController.clear(),
                  child: const Text('Limpiar firma'),
                ),
              ),

              const SizedBox(height: 15),

              // Denunciar / Guardar
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

      // FAB chatbot (NO TOCAR)
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryBlue,
        shape: const CircleBorder(),
        onPressed: _abrirChatbot,
        child: const Icon(Icons.smart_toy, color: Colors.white),
      ),

      // Bottom nav (NO TOCAR)
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
