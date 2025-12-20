import 'package:flutter/material.dart';

class AyudaScreen extends StatefulWidget {
  const AyudaScreen({super.key});

  @override
  State<AyudaScreen> createState() => _AyudaScreenState();
}

class _AyudaScreenState extends State<AyudaScreen> {
  static const Color primaryBlue = Color(0xFF2C64C4);

  final TextEditingController searchController = TextEditingController();

  // chips (como tu mock)
  String chipSeleccionado = 'todos';

  // datos dummy (solo frontend)
  final List<_HelpItem> items = const [
    _HelpItem(
      pregunta: 'porque subir mi cedula ?',
      respuesta:
          'Se solicita la cédula para identificar al ciudadano y evitar denuncias falsas. '
          'Tus datos se usan únicamente para gestión de la denuncia y seguimiento.',
      categoria: 'registro',
    ),
    _HelpItem(
      pregunta: 'que hace el chat bot ?',
      respuesta:
          'El chatbot te guía para redactar correctamente tu denuncia: te pregunta el tipo, descripción, '
          'ubicación y evidencia. Luego te ayuda a enviarla.',
      categoria: 'chatbot',
    ),
    _HelpItem(
      pregunta: 'como ayuda el chat bot ?',
      respuesta:
          'Te hace preguntas paso a paso, te sugiere qué información incluir y te ayuda a adjuntar evidencias '
          '(foto, video, audio o documentos) para que tu denuncia sea más clara.',
      categoria: 'chatbot',
    ),
    _HelpItem(
      pregunta: 'que es una denuncia ?',
      respuesta:
          'Una denuncia es un reporte formal de un problema o incidente (basura, vías, alumbrado, etc.) '
          'para que el municipio pueda revisarlo y gestionarlo.',
      categoria: 'general',
    ),
    _HelpItem(
      pregunta: 'como denunciar ?',
      respuesta:
          '1) Elige tipo de denuncia\n'
          '2) Describe el problema\n'
          '3) Selecciona ubicación en el mapa\n'
          '4) Adjunta evidencia\n'
          '5) Firma y envía',
      categoria: 'como denunciar',
    ),
    _HelpItem(
      pregunta: 'hay cosas que no puedo denunciar ?',
      respuesta:
          'Sí. No se aceptan denuncias falsas, amenazas, contenido ofensivo o fuera de competencia municipal. '
          'Para emergencias, contacta a los servicios correspondientes.',
      categoria: 'restricciones',
    ),
  ];

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<_HelpItem> get _filtrados {
    final q = searchController.text.trim().toLowerCase();

    return items.where((it) {
      final matchChip = (chipSeleccionado == 'todos')
          ? true
          : it.categoria.toLowerCase() == chipSeleccionado;
      final matchSearch = q.isEmpty
          ? true
          : (it.pregunta.toLowerCase().contains(q) ||
                it.respuesta.toLowerCase().contains(q));
      return matchChip && matchSearch;
    }).toList();
  }

  void _showDetalle(_HelpItem item) {
    showDialog(
      context: context,
      barrierDismissible: true, // puede cerrar tocando fuera
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

              // ✅ Botón X flotante
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

  @override
  Widget build(BuildContext context) {
    final list = _filtrados;

    return Scaffold(
      backgroundColor: Colors.white,

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
                leading: const Icon(Icons.help_outline),
                title: const Text("Ayuda"),
                onTap: () => Navigator.pop(context),
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
          // Buscador
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

          // Chips de sugerencias (como tu mock)
          // Chips de sugerencias (arreglado: NO overflow)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ChipSug(
                    icon: Icons.favorite_border,
                    text: 'como denunciar',
                    selected: chipSeleccionado == 'como denunciar',
                    onTap: () =>
                        setState(() => chipSeleccionado = 'como denunciar'),
                  ),
                  const SizedBox(width: 8),
                  _ChipSug(
                    icon: Icons.access_time,
                    text: 'que puedo denunciar',
                    selected: chipSeleccionado == 'restricciones',
                    onTap: () =>
                        setState(() => chipSeleccionado = 'restricciones'),
                  ),
                  const SizedBox(width: 8),

                  // ✅ NUEVO CHIP: otros
                  _ChipSug(
                    icon: Icons.more_horiz,
                    text: 'otros',
                    selected: chipSeleccionado == 'otros',
                    onTap: () => setState(() => chipSeleccionado = 'otros'),
                  ),
                  const SizedBox(width: 8),

                  // ✅ CHIP "todos" (en vez de texto a la derecha)
                  _ChipSug(
                    icon: Icons.apps,
                    text: 'todos',
                    selected: chipSeleccionado == 'todos',
                    onTap: () => setState(() => chipSeleccionado = 'todos'),
                  ),

                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Lista de preguntas
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

      // bottom bar igual a tus pantallas (solo UI)
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (i) {},
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        selectedItemColor: primaryBlue,
        unselectedItemColor: Colors.grey.shade600,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Inicio"),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "Buscar"),
          BottomNavigationBarItem(icon: Icon(Icons.swap_horiz), label: "Mov"),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: "Wallet",
          ),
        ],
      ),
    );
  }

  String _preview(String text) {
    final clean = text.replaceAll('\n', ' ');
    return clean.length <= 38 ? clean : '${clean.substring(0, 38)}...';
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
