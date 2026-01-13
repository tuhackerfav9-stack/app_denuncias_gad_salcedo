import 'package:flutter/material.dart';
import '../../settings/api_connection.dart';
import '../../repositories/chatbot_repository.dart';

class ChatbotTestScreen extends StatefulWidget {
  const ChatbotTestScreen({super.key});

  @override
  State<ChatbotTestScreen> createState() => _ChatbotTestScreenState();
}

class _ChatbotTestScreenState extends State<ChatbotTestScreen> {
  final api = ApiConnection();
  final repo = ChatbotRepository();
  String? convId;
  final controller = TextEditingController();
  final List<String> log = [];

  void addLog(String s) => setState(() => log.add(s));

  Future<void> doLogin() async {
    await api.login("juan.demo@mail.com", "NuevaPass123");
    addLog("✅ Login OK");
  }

  Future<void> doStart() async {
    final r = await repo.startChat();
    convId = r["conversacion_id"];
    addLog("✅ Start: $convId");
  }

  Future<void> doSend() async {
    if (convId == null) return;
    final text = controller.text.trim();
    if (text.isEmpty) return;

    addLog("👤 $text");
    controller.clear();

    final r = await repo.sendMessage(conversacionId: convId!, mensaje: text);
    addLog("🤖 ${r["respuesta"]}");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Chatbot Test")),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Wrap(
              spacing: 10,
              children: [
                ElevatedButton(onPressed: doLogin, child: const Text("Login")),
                ElevatedButton(
                  onPressed: doStart,
                  child: const Text("Start Chat"),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: "Escribe mensaje...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(onPressed: doSend, icon: const Icon(Icons.send)),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: log.length,
                itemBuilder: (_, i) => Text(log[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
