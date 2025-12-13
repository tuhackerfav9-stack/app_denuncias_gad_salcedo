import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';

class DenunciasFormScreen extends StatefulWidget {
  const DenunciasFormScreen({super.key});

  @override
  State<DenunciasFormScreen> createState() => _DenunciasFormScreenState();
}

class _DenunciasFormScreenState extends State<DenunciasFormScreen> {
  static const Color primaryBlue = Color(0xFF2C64C4);

  final formKey = GlobalKey<FormState>();

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

  @override
  void initState() {
    super.initState();
    _initUbicacion();
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
      puntoDenuncia = LatLng(pos.latitude, pos.longitude);
      markers = {
        Marker(
          markerId: const MarkerId('denuncia'),
          position: puntoDenuncia!,
          infoWindow: const InfoWindow(title: 'Lugar de denuncia'),
        ),
      };
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

  void _denunciar() {
    if (!formKey.currentState!.validate()) return;

    if (puntoDenuncia == null) {
      _snack('Selecciona el lugar de la denuncia en el mapa');
      return;
    }
    if (signatureController.isEmpty) {
      _snack('Firma antes de enviar');
      return;
    }

    _snack('Denuncia lista ✅ (solo frontend)');
  }

  void _abrirChatbot() {
    // Navigator.pushNamed(context, '/chatbot');
    _snack('Chatbot 🤖 (solo frontend)');
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final pos = currentPosition;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Denuncias',
          style: TextStyle(color: Color.fromARGB(255, 44, 100, 196)),
        ),
        centerTitle: true,
      ),

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
                  if (v == null || v.trim().isEmpty)
                    return 'La descripción es requerida';
                  if (v.trim().length < 10)
                    return 'Describe un poco más (mín. 10 caracteres)';
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
                          target: LatLng(pos.latitude, pos.longitude),
                          zoom: 16,
                        ),
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        markers: markers,
                        onMapCreated: (c) => mapController = c,
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

              // Denunciar
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: _denunciar,
                  style: TextButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    'Denunciar',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // FAB Robot 🤖 para chatbot
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryBlue,
        shape: const CircleBorder(),
        onPressed: _abrirChatbot,
        child: const Icon(Icons.smart_toy, color: Colors.white),
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
