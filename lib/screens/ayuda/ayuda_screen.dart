import 'package:flutter/material.dart';

class AyudaScreen extends StatefulWidget {
  const AyudaScreen({super.key});

  @override
  State<AyudaScreen> createState() => _AyudaScreenState();
}

class _AyudaScreenState extends State<AyudaScreen> {
  static const Color primaryBlue = Color(0xFF2C64C4);

  final TextEditingController searchController = TextEditingController();

  // filtro por categoría (chips)
  String chipSeleccionado = 'todos';

  // navegación inferior
  int currentIndex = 0;

  // datos dummy (solo frontend)
  final List<_HelpItem> items = const [
    _HelpItem(
      pregunta: '¿Por qué debo subir mi cédula?',
      respuesta:
          'Se solicita la cédula para identificar al ciudadano y evitar denuncias falsas. '
          'Tus datos se usan únicamente para gestionar la denuncia y dar seguimiento.',
      categoria: 'registro',
    ),
    _HelpItem(
      pregunta: '¿Qué hace el chatbot?',
      respuesta:
          'El chatbot te guía para redactar correctamente tu denuncia: te pregunta el tipo, descripción, '
          'ubicación y evidencia. Luego te ayuda a enviarla.',
      categoria: 'chatbot',
    ),
    _HelpItem(
      pregunta: '¿Cómo ayuda el chatbot a redactar una denuncia?',
      respuesta:
          'Te hace preguntas paso a paso, te sugiere qué información incluir y te ayuda a adjuntar evidencias '
          '(foto, video o documentos) para que tu denuncia sea más clara.',
      categoria: 'chatbot',
    ),
    _HelpItem(
      pregunta: '¿Qué es una denuncia?',
      respuesta:
          'Una denuncia es un reporte formal de un problema o incidente (basura, vías, alumbrado, etc.) '
          'para que el municipio pueda revisarlo y gestionarlo.',
      categoria: 'general',
    ),
    _HelpItem(
      pregunta: '¿Cómo denunciar desde la app?',
      respuesta:
          '1) Elige el tipo de denuncia\n'
          '2) Describe el problema\n'
          '3) Selecciona la ubicación en el mapa\n'
          '4) Adjunta evidencia\n'
          '5) Firma y envía',
      categoria: 'como denunciar',
    ),
    _HelpItem(
      pregunta: '¿Hay cosas que no puedo denunciar?',
      respuesta:
          'Sí. No se aceptan denuncias falsas, amenazas, contenido ofensivo o temas fuera de competencia municipal. '
          'Para emergencias, contacta a los servicios correspondientes.',
      categoria: 'restricciones',
    ),

    // ===== 10+ preguntas nuevas =====
    _HelpItem(
      pregunta: '¿Cómo sé si mi denuncia fue recibida?',
      respuesta:
          'Al enviar la denuncia, verás un mensaje de confirmación. Luego podrás verla en “Mis denuncias” '
          'con su estado (pendiente/en revisión/atendida).',
      categoria: 'general',
    ),
    _HelpItem(
      pregunta: '¿Puedo denunciar de forma anónima?',
      respuesta:
          'Por seguridad del sistema, el registro ayuda a evitar denuncias falsas. '
          'Tu información se usa para seguimiento y validación.',
      categoria: 'registro',
    ),
    _HelpItem(
      pregunta: '¿Qué pasa si me equivoco al escribir la denuncia?',
      respuesta:
          'Puedes crear una nueva denuncia con la información correcta. Si el sistema permite edición, '
          'podrás corregir antes de que sea atendida.',
      categoria: 'otros',
    ),
    _HelpItem(
      pregunta: '¿Qué tipo de evidencia puedo subir?',
      respuesta:
          'Puedes subir foto, video o documentos. Mientras más clara sea la evidencia, más fácil será validar el caso.',
      categoria: 'otros',
    ),
    _HelpItem(
      pregunta: '¿Por qué debo firmar la denuncia?',
      respuesta:
          'La firma sirve como confirmación del ciudadano de que la información enviada es real y válida.',
      categoria: 'registro',
    ),
    _HelpItem(
      pregunta: '¿Qué hago si el mapa no carga?',
      respuesta:
          'Revisa tu conexión a internet y habilita permisos de ubicación. Si continúa, reinicia la app.',
      categoria: 'otros',
    ),
    _HelpItem(
      pregunta: '¿Qué hago si el GPS no detecta mi ubicación?',
      respuesta:
          'Asegúrate de tener el GPS activado, permisos de ubicación concedidos y precisión alta en el teléfono.',
      categoria: 'otros',
    ),
    _HelpItem(
      pregunta: '¿Puedo denunciar el mismo problema varias veces?',
      respuesta:
          'La app busca evitar duplicados. Si ya existe una denuncia similar, revisa el mapa y el historial antes de enviar otra.',
      categoria: 'restricciones',
    ),
    _HelpItem(
      pregunta: '¿Cuánto tiempo tarda en atenderse una denuncia?',
      respuesta:
          'Depende del tipo de denuncia y disponibilidad. Puedes revisar el estado en “Mis denuncias”.',
      categoria: 'general',
    ),
    _HelpItem(
      pregunta: '¿Cómo cambio mi contraseña?',
      respuesta:
          'Desde tu perfil podrás cambiar tu contraseña. También puedes usar “Recuperar contraseña” desde el login.',
      categoria: 'registro',
    ),
    _HelpItem(
      pregunta: '¿El chatbot puede enviar la denuncia por mí?',
      respuesta:
          'El chatbot puede ayudarte a redactar y completar datos. Al final, tú confirmas el envío.',
      categoria: 'chatbot',
    ),
  ];

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // ====== filtrado ======
  List<_HelpItem> get _filtrados {
    final q = searchController.text.trim().toLowerCase();

    return items.where((it) {
      final cat = it.categoria.toLowerCase();
      final matchChip = (chipSeleccionado == 'todos')
          ? true
          : cat == chipSeleccionado;
      final matchSearch = q.isEmpty
          ? true
          : (it.pregunta.toLowerCase().contains(q) ||
                it.respuesta.toLowerCase().contains(q));
      return matchChip && matchSearch;
    }).toList();
  }

  // ====== modal detalle ======
  void _showDetalle(_HelpItem item) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      item.pregunta,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      item.respuesta,
                      style: const TextStyle(fontSize: 13.5, height: 1.35),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              Positioned(
                right: 6,
                top: 6,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ====== bottom nav ======
  void _onBottomNavTap(int index) {
    setState(() => currentIndex = index);

    if (index == 0) Navigator.pushNamed(context, '/denuncias');
    if (index == 1) Navigator.pushNamed(context, '/form/denuncias');
    if (index == 2) Navigator.pushNamed(context, '/chatbot');
    if (index == 3) Navigator.pushNamed(context, '/mapadenuncias');
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtrados;

    return Scaffold(
      backgroundColor: Colors.white,

      // Drawer (Ayuda activo/resaltado)
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
                leading: const Icon(Icons.person_outline),
                title: const Text("Perfil"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/perfil');
                },
              ),

              // ✅ AYUDA ACTIVO (resaltado)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: primaryBlue.withAlpha((0.10 * 255).round()),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  leading: const Icon(Icons.info_outline, color: primaryBlue),
                  title: const Text(
                    "Ayuda",
                    style: TextStyle(
                      color: primaryBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    // ya estás en ayuda
                  },
                ),
              ),

              const Spacer(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text("Cerrar sesión"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(context, '/');
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
          'Ayuda',
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
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Buscar',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),

          // chips (con scroll horizontal, no overflow)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ChipSug(
                    icon: Icons.apps,
                    text: 'todos',
                    selected: chipSeleccionado == 'todos',
                    onTap: () => setState(() => chipSeleccionado = 'todos'),
                  ),
                  const SizedBox(width: 8),
                  _ChipSug(
                    icon: Icons.report,
                    text: 'como denunciar',
                    selected: chipSeleccionado == 'como denunciar',
                    onTap: () =>
                        setState(() => chipSeleccionado = 'como denunciar'),
                  ),
                  const SizedBox(width: 8),
                  _ChipSug(
                    icon: Icons.block,
                    text: 'restricciones',
                    selected: chipSeleccionado == 'restricciones',
                    onTap: () =>
                        setState(() => chipSeleccionado = 'restricciones'),
                  ),
                  const SizedBox(width: 8),
                  _ChipSug(
                    icon: Icons.smart_toy,
                    text: 'chatbot',
                    selected: chipSeleccionado == 'chatbot',
                    onTap: () => setState(() => chipSeleccionado = 'chatbot'),
                  ),
                  const SizedBox(width: 8),
                  _ChipSug(
                    icon: Icons.verified_user,
                    text: 'registro',
                    selected: chipSeleccionado == 'registro',
                    onTap: () => setState(() => chipSeleccionado = 'registro'),
                  ),
                  const SizedBox(width: 8),
                  _ChipSug(
                    icon: Icons.more_horiz,
                    text: 'otros',
                    selected: chipSeleccionado == 'otros',
                    onTap: () => setState(() => chipSeleccionado = 'otros'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // lista
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Text(
                      'No hay resultados',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, i) {
                      final it = list[i];
                      return InkWell(
                        onTap: () => _showDetalle(it),
                        borderRadius: BorderRadius.circular(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              it.pregunta,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _preview(it.respuesta),
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),

      // bottom nav con navegación real
      bottomNavigationBar: BottomNavigationBar(
        currentIndex:
            0, // ayuda NO está en bottom nav, entonces deja inicio fijo o maneja como quieras
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

  String _preview(String text) {
    final clean = text.replaceAll('\n', ' ');
    return clean.length <= 52 ? clean : '${clean.substring(0, 52)}...';
  }
}

// ====== MODELO ======
class _HelpItem {
  final String pregunta;
  final String respuesta;
  final String categoria;

  const _HelpItem({
    required this.pregunta,
    required this.respuesta,
    required this.categoria,
  });
}

// ====== CHIP ======
class _ChipSug extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _ChipSug({
    required this.icon,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  static const Color primaryBlue = Color(0xFF2C64C4);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? primaryBlue.withAlpha((0.12 * 255).round())
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
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? primaryBlue : Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
