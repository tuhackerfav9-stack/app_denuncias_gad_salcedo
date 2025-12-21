import 'package:flutter/material.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen>
    with WidgetsBindingObserver {
  static const Color primaryBlue = Color(0xFF2C64C4);

  final TextEditingController msgController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final FocusNode inputFocus = FocusNode();

  // navegación inferior
  int currentIndex = 2;

  // para ocultar el bottom nav cuando aparece teclado
  bool _keyboardVisible = false;

  // mensajes dummy
  final List<_ChatMessage> messages = [
    _ChatMessage(
      text: 'Esta es la plantilla principal de chat',
      isMe: true,
      isPill: true,
    ),
    _ChatMessage(text: 'Ah, sí?', isMe: false),
    _ChatMessage(text: 'Qué chulo', isMe: false),
    _ChatMessage(text: 'Cómo funciona?', isMe: false),
    _ChatMessage(
      text:
          'Solo tienes que editar cualquier\ntexto para escribir la conversación\nque quieres mostrar, y borrar las\nburbujas que no quieras utilizar',
      isMe: true,
    ),
    _ChatMessage(text: 'Zasca', isMe: true),
    _ChatMessage(text: 'Mmm', isMe: false),
    _ChatMessage(text: 'Creo que lo entiendo', isMe: false),
    _ChatMessage(
      text:
          'De todas formas miraré en el\nCentro de ayuda si tengo más\npreguntas',
      isMe: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // detectar focus para ocultar/reaparecer bottom nav (extra)
    inputFocus.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    msgController.dispose();
    scrollController.dispose();
    inputFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // cuando aparece teclado cambia el viewInsets.bottom
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final visible = bottom > 0;
    if (visible != _keyboardVisible) {
      setState(() => _keyboardVisible = visible);
    }
  }

  // ================== enviar texto ==================
  void _sendText() {
    final text = msgController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      messages.add(_ChatMessage(text: text, isMe: true));
      msgController.clear();
    });

    _scrollToBottom();

    // SOLO UI: simular respuesta del bot
    Future.delayed(const Duration(milliseconds: 450), () {
      setState(() {
        messages.add(
          _ChatMessage(
            text: 'Entendido ✅ ¿Qué deseas denunciar? (solo frontend)',
            isMe: false,
          ),
        );
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 60), () {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent + 200,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  // ================== adjuntos (solo UI) ==================
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
                  icon: Icons.photo,
                  title: 'Foto',
                  onTap: () {
                    Navigator.pop(context);
                    _toast('Adjuntar foto (solo UI)');
                  },
                ),
                _AttachTile(
                  icon: Icons.videocam,
                  title: 'Video',
                  onTap: () {
                    Navigator.pop(context);
                    _toast('Adjuntar video (solo UI)');
                  },
                ),
                _AttachTile(
                  icon: Icons.insert_drive_file,
                  title: 'Documento',
                  onTap: () {
                    Navigator.pop(context);
                    _toast('Adjuntar documento (solo UI)');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ================== navegación inferior ==================
  void _onBottomNavTap(int index) {
    setState(() => currentIndex = index);

    if (index == 0) Navigator.pushNamed(context, '/denuncias');
    if (index == 1) Navigator.pushNamed(context, '/form/denuncias');
    if (index == 2) {
      // ya estás en /chatbot
    }
    if (index == 3) Navigator.pushNamed(context, '/mapadenuncias');
  }

  // ================== menú perfil (arriba derecha) ==================
  void _onProfileMenu(String value) {
    switch (value) {
      case 'perfil':
        Navigator.pushNamed(context, '/perfil');
        break;
      case 'ayuda':
        Navigator.pushNamed(context, '/ayuda');
        break;
      case 'cerrar':
        Navigator.pushReplacementNamed(context, '/');
        break;
    }
  }

  // ================== UI ==================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // Drawer (izquierda)
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

      // AppBar superior (manteniendo estética)
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
          PopupMenuButton<String>(
            onSelected: _onProfileMenu,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'perfil', child: Text("Ver perfil")),
              PopupMenuItem(value: 'ayuda', child: Text("Ayuda")),
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

      body: Column(
        children: [
          // mensajes
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              itemCount: messages.length + 2,
              itemBuilder: (context, i) {
                if (i == 0) return const SizedBox(height: 6);

                // fecha centrada
                if (i == 1) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Center(
                      child: Text(
                        '30 de noviembre de 2023, 9:41 AM',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  );
                }

                final msg = messages[i - 2];
                return _Bubble(message: msg);
              },
            ),
          ),

          // input (sin emojis, sin audio)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: _openAttachmentsSheet,
                            icon: const Icon(Icons.attach_file),
                            color: Colors.grey.shade700,
                          ),
                          Expanded(
                            child: TextField(
                              focusNode: inputFocus,
                              controller: msgController,
                              minLines: 1,
                              maxLines: 4,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                hintText: 'Mensaje...',
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // botón enviar SIEMPRE (solo texto)
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: primaryBlue,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _sendText,
                      icon: const Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // bottom nav (se oculta cuando aparece teclado)
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
}

// ===== modelos y widgets internos =====

class _ChatMessage {
  final String text;
  final bool isMe;
  final bool isPill;

  _ChatMessage({required this.text, required this.isMe, this.isPill = false});
}

class _Bubble extends StatelessWidget {
  final _ChatMessage message;
  const _Bubble({required this.message});

  static const Color primaryBlue = Color(0xFF2C64C4);

  @override
  Widget build(BuildContext context) {
    final bg = message.isMe ? primaryBlue : Colors.grey.shade200;
    final fg = message.isMe ? Colors.white : Colors.black87;

    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: EdgeInsets.symmetric(
          horizontal: message.isPill ? 18 : 14,
          vertical: message.isPill ? 10 : 10,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(message.isPill ? 22 : 16),
        ),
        child: Text(
          message.text,
          style: TextStyle(color: fg, fontSize: 13.5, height: 1.25),
        ),
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
