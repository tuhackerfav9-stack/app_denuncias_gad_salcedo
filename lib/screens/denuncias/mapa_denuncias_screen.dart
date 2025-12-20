import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapaDenunciasScreen extends StatefulWidget {
  const MapaDenunciasScreen({super.key});

  @override
  State<MapaDenunciasScreen> createState() => _MapaDenunciasScreenState();
}

class _MapaDenunciasScreenState extends State<MapaDenunciasScreen> {
  static const Color primaryBlue = Color(0xFF2C64C4);

  final TextEditingController searchController = TextEditingController();

  // ✅ filtros tipo chip (como tu imagen)
  String filtro = 'todos';

  // ✅ Centro del mapa (pon cualquier coord por ahora; luego será tu ciudad/ubicación)
  static const LatLng initialCenter = LatLng(
    -0.9333,
    -78.6167,
  ); // Ejemplo Ecuador

  // ✅ Datos dummy (solo frontend)
  final List<_DenunciaMapItem> denuncias = [
    _DenunciaMapItem(
      tipo: 'luz publica',
      descripcion: 'poste apagado',
      fecha: '2025-12-20',
      position: LatLng(-0.9327, -78.6161),
    ),
    _DenunciaMapItem(
      tipo: 'basura',
      descripcion: 'basura parque',
      fecha: '2025-12-19',
      position: LatLng(-0.9335, -78.6174),
    ),
    _DenunciaMapItem(
      tipo: 'vial',
      descripcion: 'vía dañada',
      fecha: '2025-12-18',
      position: LatLng(-0.9342, -78.6165),
    ),
    _DenunciaMapItem(
      tipo: 'luz publica',
      descripcion: 'luz intermitente',
      fecha: '2025-12-17',
      position: LatLng(-0.9330, -78.6154),
    ),
    _DenunciaMapItem(
      tipo: 'otros',
      descripcion: 'ruido en la noche',
      fecha: '2025-12-16',
      position: LatLng(-0.9322, -78.6170),
    ),
    _DenunciaMapItem(
      tipo: 'mi denuncia',
      descripcion: 'reporte propio',
      fecha: '2025-12-15',
      position: LatLng(-0.9332, -78.6167),
      highlight: true,
    ),
  ];

  GoogleMapController? mapController;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // ========= Filtrado (solo UI) =========
  List<_DenunciaMapItem> get _filtradas {
    final q = searchController.text.trim().toLowerCase();

    return denuncias.where((d) {
      final matchFiltro = (filtro == 'todos') ? true : d.tipo == filtro;
      final matchSearch = q.isEmpty
          ? true
          : ('${d.tipo} ${d.descripcion} ${d.fecha}'.toLowerCase()).contains(q);
      return matchFiltro && matchSearch;
    }).toList();
  }

  // ========= UI =========
  @override
  Widget build(BuildContext context) {
    final items = _filtradas;

    return Scaffold(
      backgroundColor: Colors.white,

      // Drawer como tus otras pantallas
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 10),
              const ListTile(
                leading: CircleAvatar(child: Icon(Icons.person)),
                title: Text("Ciudadano"),
                subtitle: Text("usuario@correo.com"),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.map),
                title: const Text("Mapa denuncias"),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.report),
                title: const Text("Mis denuncias"),
                onTap: () {
                  Navigator.pop(context);
                  // Navigator.pushNamed(context, '/denuncias');
                },
              ),
              const Spacer(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text("Cerrar sesión"),
                onTap: () => Navigator.pop(context),
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
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey.shade300,
              child: const Icon(Icons.person, size: 18, color: Colors.black54),
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          // ✅ Buscador (como tu imagen)
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
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Buscar',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),

          // ✅ Chips de filtro
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    text: 'basura',
                    icon: Icons.favorite_border,
                    selected: filtro == 'basura',
                    onTap: () => setState(() => filtro = 'basura'),
                  ),
                  _FilterChip(
                    text: 'vial',
                    icon: Icons.aod,
                    selected: filtro == 'vial',
                    onTap: () => setState(() => filtro = 'vial'),
                  ),
                  _FilterChip(
                    text: 'luz publica',
                    icon: Icons.person_outline,
                    selected: filtro == 'luz publica',
                    onTap: () => setState(() => filtro = 'luz publica'),
                  ),
                  _FilterChip(
                    text: 'otros',
                    icon: Icons.description_outlined,
                    selected: filtro == 'otros',
                    onTap: () => setState(() => filtro = 'otros'),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => setState(() => filtro = 'todos'),
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

          // ✅ Mapa + “mensajes” encima
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
                  onMapCreated: (c) => mapController = c,
                  // (Opcional) markers invisibles -> por ahora no los muestro, porque tu mock usa “labels”
                ),

                // ✅ Labels tipo “mensaje”, NO botones (como tu imagen)
                ...items.map(
                  (d) => _DenunciaLabel(item: d, onTap: () => _showDetalle(d)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDetalle(_DenunciaMapItem d) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('d.tipo.toUpperCase()'),
        content: Text(
          '${d.descripcion}\nFecha: ${d.fecha}\n\n(Detalle solo UI)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

// ===================== MODELO UI =====================

class _DenunciaMapItem {
  final String tipo;
  final String descripcion;
  final String fecha;
  final LatLng position;
  final bool highlight;

  _DenunciaMapItem({
    required this.tipo,
    required this.descripcion,
    required this.fecha,
    required this.position,
    this.highlight = false,
  });
}

// ===================== CHIP FILTRO =====================

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
            color: selected
                ? primaryBlue.withValues(alpha: 0.10)
                : Colors.white,
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

// ===================== LABEL MENSAJE ENCIMA DEL MAPA =====================
// Nota: Esto es UI “mock”: posiciono las etiquetas con offsets fijos
// para que se parezca a tu captura.
// Luego, cuando tengas denuncias reales, las puedes mapear con
// Marker + InfoWindow / o usar un overlay calculando pixel position.

class _DenunciaLabel extends StatelessWidget {
  final _DenunciaMapItem item;
  final VoidCallback onTap;

  const _DenunciaLabel({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // offsets fijos según tipo (solo para parecerse al mock)
    final pos = _mockOffset(item);

    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: item.highlight ? Colors.black87 : Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.8),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(
              color: item.highlight ? Colors.black87 : Colors.grey.shade300,
            ),
          ),
          child: Text(
            item.tipo, // en tu mock se ve solo el texto
            style: TextStyle(
              color: item.highlight ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }

  // Ajusta estos offsets si quieres que quede 100% igual a tu imagen
  Offset _mockOffset(_DenunciaMapItem d) {
    switch (d.tipo) {
      case 'mi denuncia':
        return const Offset(140, 140);
      case 'luz publica':
        return const Offset(20, 90);
      case 'basura':
        return const Offset(210, 110);
      case 'vial':
        return const Offset(220, 170);
      case 'otros':
        return const Offset(80, 180);
      default:
        return const Offset(140, 120);
    }
  }
}
