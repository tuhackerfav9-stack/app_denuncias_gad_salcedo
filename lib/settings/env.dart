class Env {
  // Se inyecta con --dart-define=GEMINI_API_KEY=xxxx
  static const String geminiApiKey = String.fromEnvironment("GEMINI_API_KEY");
}
