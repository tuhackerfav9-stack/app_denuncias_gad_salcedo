import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../../repositories/denuncias_repository.dart';
import '../../settings/session.dart';

class MapaDenunciasScreen extends StatefulWidget {
  const MapaDenunciasScreen({super.key});

  @override
  State<MapaDenunciasScreen> createState() => _MapaDenunciasScreenState();
}

class _MapaDenunciasScreenState extends State<MapaDenunciasScreen> {
  static const Color primaryBlue = Color(0xFF2C64C4);

  final TextEditingController searchController = TextEditingController();
  final repo = DenunciasRepository();

  int currentIndex = 3;

  // filtros UI (chips)
  String filtro = 'todos';

  // centro Salcedo
  static const LatLng initialCenter = LatLng(-0.9333, -78.6167);

  // Controller seguro
  final Completer<GoogleMapController> _mapCompleter =
      Completer<GoogleMapController>();
  GoogleMapController? _mapController;

  // estado datos
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  Set<Marker> _markers = {};

  // geo
  double? _lat0;
  double? _lng0;

  // debounce + control respuestas viejas
  Timer? _debounce;
  int _requestSeq = 0;

  @override
  void initState() {
    super.initState();

    _initGeoAndLoad();

    // Debounce: 400ms
    searchController.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 400), () {
        _loadFromApi();
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    searchController.dispose();
    _mapController = null;
    super.dispose();
  }

  Future<void> _initGeoAndLoad() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (enabled) {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.whileInUse ||
            perm == LocationPermission.always) {
          final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          _lat0 = pos.latitude;
          _lng0 = pos.longitude;
        }
      }
    } catch (_) {
      // si falla, no pasa nada
    }

    await _loadFromApi();
  }

  // ✅ IDs quemados (según tu tabla real)
  int? _tipoIdFromFiltro(String f) {
    switch (f) {
      case "luz": // Alumbrado público (id 1)
        return 1;

      case "luminaria": // Luminarias dañadas (id 2)
        return 2;

      case "basura": // Acumulación de basura (id 3)
        return 3;

      case "agua": // Falta de agua potable (id 5)
        return 5;

      case "alcantarillado": // Alcantarillado tapado (id 8)
        return 8;

      case "baches": // Baches o huecos (id 14)
        return 14;

      case "calles": // Calles en mal estado (id 13)
        return 13;

      case "riesgo": // Riesgo estructural (id 23)
        return 23;

      case "otro": // Otro (id 31)
        return 31;

      case "todos":
      default:
        return null;
    }
  }

  Future<void> _loadFromApi() async {
    final mySeq = ++_requestSeq;

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final q = searchController.text.trim();
      final tipoId = _tipoIdFromFiltro(filtro);

      final res = await repo.getMapa(
        lat: _lat0,
        lng: _lng0,
        radioKm: 55,
        soloHoy: false,
        soloMias: true,
        tipoDenunciaId: tipoId, //  int? real
        q: q.isEmpty ? null : q,
      );

      if (!mounted || mySeq != _requestSeq) return;

      final list = (res["items"] as List?) ?? [];
      final items = list
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      final markers = items.map((m) {
        final id = (m["id"] ?? "").toString();

        final lat = (m["latitud"] as num).toDouble();
        final lng = (m["longitud"] as num).toDouble();

        final tipo = (m["tipo_denuncia_nombre"] ?? "Denuncia").toString();
        final estado = (m["estado"] ?? "").toString();
        final desc = (m["descripcion"] ?? "").toString();

        return Marker(
          markerId: MarkerId(id),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: tipo,
            snippet: estado.isEmpty ? desc : "$estado • $desc",
            onTap: () {
              Navigator.pushNamed(context, '/detalle_denuncia', arguments: m);
            },
          ),
        );
      }).toSet();

      setState(() {
        _items = items;
        _markers = markers;
        _loading = false;
        _error = null;
      });

      // centrar seguro
      if (_items.isNotEmpty) {
        await _safeAnimateToFirst(_items.first);
      }
    } catch (e) {
      if (!mounted || mySeq != _requestSeq) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _safeAnimateToFirst(Map<String, dynamic> first) async {
    try {
      final controller = _mapController ?? await _mapCompleter.future;
      if (!mounted) return;

      final lat = (first["latitud"] as num).toDouble();
      final lng = (first["longitud"] as num).toDouble();

      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(lat, lng), 14),
      );
    } catch (_) {}
  }

  void _onBottomNavTap(int index) {
    setState(() => currentIndex = index);
    if (index == 0) Navigator.pushNamed(context, '/denuncias');
    if (index == 1) Navigator.pushNamed(context, '/form/denuncias');
    if (index == 2) Navigator.pushNamed(context, '/chatbot');
    if (index == 3) {}
  }

  void _setFiltro(String f) {
    setState(() => filtro = f);
    _loadFromApi();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

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

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: primaryBlue),
        centerTitle: true,
        title: const Text(
          'Mapa denuncias',
          style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(onPressed: _loadFromApi, icon: const Icon(Icons.refresh)),
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

      // mapa siempre montado + overlays
      body: Column(
        children: [
          // buscador
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Buscar',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),

          // chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    text: 'luz',
                    icon: Icons.lightbulb_outline,
                    selected: filtro == 'luz',
                    onTap: () => _setFiltro('luz'),
                  ),
                  _FilterChip(
                    text: 'basura',
                    icon: Icons.delete_outline,
                    selected: filtro == 'basura',
                    onTap: () => _setFiltro('basura'),
                  ),
                  _FilterChip(
                    text: 'baches',
                    icon: Icons.construction_outlined,
                    selected: filtro == 'baches',
                    onTap: () => _setFiltro('baches'),
                  ),
                  _FilterChip(
                    text: 'agua',
                    icon: Icons.water_drop_outlined,
                    selected: filtro == 'agua',
                    onTap: () => _setFiltro('agua'),
                  ),
                  _FilterChip(
                    text: 'alcantarillado',
                    icon: Icons.plumbing_outlined,
                    selected: filtro == 'alcantarillado',
                    onTap: () => _setFiltro('alcantarillado'),
                  ),
                  _FilterChip(
                    text: 'riesgo',
                    icon: Icons.warning_amber_outlined,
                    selected: filtro == 'riesgo',
                    onTap: () => _setFiltro('riesgo'),
                  ),
                  _FilterChip(
                    text: 'otro',
                    icon: Icons.description_outlined,
                    selected: filtro == 'otro',
                    onTap: () => _setFiltro('otro'),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _setFiltro('todos'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        filtro == 'todos' ? 'Todos ✓' : 'Todos',
                        style: TextStyle(
                          color: filtro == 'todos'
                              ? primaryBlue
                              : Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: initialCenter,
                    zoom: 15,
                  ),
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  markers: _markers,
                  onMapCreated: (c) {
                    _mapController = c;
                    if (!_mapCompleter.isCompleted) {
                      _mapCompleter.complete(c);
                    }
                  },
                ),

                if (_loading)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      color: Colors.white.withOpacity(0.85),
                      child: const Center(
                        child: SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  ),

                if (_error != null)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Error cargando: $_error",
                              style: TextStyle(color: Colors.red.shade700),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          TextButton(
                            onPressed: _loadFromApi,
                            child: const Text("Reintentar"),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
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
}

class _FilterChip extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.text,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  static const Color primaryBlue = Color(0xFF2C64C4);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? primaryBlue.withAlpha(26) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? primaryBlue : Colors.grey.shade300,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? primaryBlue : Colors.grey.shade700,
              ),
              const SizedBox(width: 6),
              Text(
                text,
                style: TextStyle(
                  color: selected ? primaryBlue : Colors.grey.shade800,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
