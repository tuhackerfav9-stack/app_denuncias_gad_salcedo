import 'package:flutter/material.dart';

class DenunciasScreen extends StatefulWidget {
  const DenunciasScreen({super.key});

  @override
  State<DenunciasScreen> createState() => _DenunciasScreenState();
}

class _DenunciasScreenState extends State<DenunciasScreen> {
  static const Color primaryBlue = Color(0xFF2C64C4);

  int currentIndex = 0;

  // Menú del perfil (arriba derecha)
  void _onProfileMenu(String value) {
    switch (value) {
      case 'perfil':
        // Navigator.pushNamed(context, '/perfil');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ir a Perfil (solo frontend)")),
        );
        break;
      case 'cerrar':
        // Navigator.pushReplacementNamed(context, '/login');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cerrar sesión (solo frontend)")),
        );
        break;
    }
  }

  // Navegación inferior
  void _onBottomNavTap(int index) {
    setState(() => currentIndex = index);

    // Aquí luego conectas rutas reales:
    if (index == 0) Navigator.pushNamed(context, '/denuncias');
    if (index == 1) Navigator.pushNamed(context, '/form/denuncias');
    if (index == 2) Navigator.pushNamed(context, '/chatbot');
    if (index == 3) Navigator.pushNamed(context, '/mapadenuncias');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Drawer (menú lateral)
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
                leading: const Icon(Icons.report),
                title: const Text("Mis Denuncias"),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text("Perfil"),
                onTap: () {
                  Navigator.pop(context);
                  // Navigator.pushNamed(context, '/perfil');
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text("Acerca de"),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              const Spacer(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text("Cerrar sesión"),
                onTap: () {
                  Navigator.pop(context);
                  // Navigator.pushReplacementNamed(context, '/login');
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),

      // AppBar superior
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: primaryBlue),
        title: const Text(
          "Mis Denuncias",
          style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w600),
        ),

        // Avatar + menú perfil
        actions: [
          PopupMenuButton<String>(
            onSelected: _onProfileMenu,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'perfil', child: Text("Ver perfil")),
              PopupMenuItem(value: 'cerrar', child: Text("Cerrar sesión")),
            ],
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey.shade300,
                child: const Icon(
                  Icons.person,
                  color: Colors.black54,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),

      // Body vacío (como tu mock)
      body: const SizedBox.expand(),

      // Botón flotante (+)
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryBlue,
        shape: const CircleBorder(),
        onPressed: () {
          Navigator.pushNamed(context, '/form/denuncias');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Nueva denuncia (solo frontend)")),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),

      // Menú inferior
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
