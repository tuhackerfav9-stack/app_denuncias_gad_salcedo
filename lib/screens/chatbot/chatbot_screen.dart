import 'package:flutter/material.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  static const Color primaryBlue = Color(0xFF2C64C4);

  final TextEditingController msgController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  // Solo UI (mensajes dummy)
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
  void dispose() {
    msgController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void _sendText() {
    final text = msgController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      messages.add(_ChatMessage(text: text, isMe: true));
      msgController.clear();
    });

    _scrollToBottom();

    // SOLO UI: simular respuesta del bot
    Future.delayed(const Duration(milliseconds: 400), () {
      setState(() {
        messages.add(
          _ChatMessage(
            text: 'Entendido. ¿Qué deseas denunciar? (solo frontend)',
            isMe: false,
          ),
        );
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

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
                _AttachTile(
                  icon: Icons.mic,
                  title: 'Audio',
                  onTap: () {
                    Navigator.pop(context);
                    _toast('Grabar/Adjuntar audio (solo UI)');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // Top bar como tu imagen
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundImage: AssetImage(
                'assets/profile_dummy.png',
              ), // si no tienes, cambia a Icon
              // child: Icon(Icons.person),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Helena Hills',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Activo hace 11 minutos',
                    style: TextStyle(color: Colors.grey, fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      body: Column(
        children: [
          // Mensajes
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              itemCount: messages.length + 1,
              itemBuilder: (context, i) {
                // Fecha centrada (como la imagen)
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

                if (i == 0) return const SizedBox(height: 8);

                final msg = messages[i - 1];
                return _Bubble(message: msg);
              },
            ),
          ),

          // Input bottom
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Row(
                children: [
                  // Caja de texto
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
                            onPressed: () => _toast('Emoji (solo UI)'),
                            icon: const Icon(Icons.emoji_emotions_outlined),
                            color: Colors.grey.shade700,
                          ),
                          Expanded(
                            child: TextField(
                              controller: msgController,
                              minLines: 1,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                hintText: 'Mensaje...',
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _openAttachmentsSheet,
                            icon: const Icon(Icons.attach_file),
                            color: Colors.grey.shade700,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Mic / Send (si hay texto manda, si no, mic)
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: primaryBlue,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () {
                        if (msgController.text.trim().isNotEmpty) {
                          _sendText();
                        } else {
                          _toast('Grabar audio (solo UI)');
                        }
                      },
                      icon: Icon(
                        msgController.text.trim().isNotEmpty
                            ? Icons.send
                            : Icons.mic,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===== Widgets internos =====

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
