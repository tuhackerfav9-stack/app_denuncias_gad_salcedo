import 'package:app_movil_denuncias/screens/chatbot/ChatbotTestScreen.dart';
import 'package:flutter/material.dart';

import 'screens/autch/cambiar_password.dart';
import 'screens/autch/login.dart';
import 'screens/autch/recuperar_password.dart';
import 'screens/autch/register.dart';
import 'screens/autch/register2.dart';
import 'screens/autch/register3.dart';
import 'screens/autch/register4.dart';
import 'screens/autch/register5.dart';
import 'screens/autch/verificar_codigo.dart';
import 'screens/ayuda/ayuda_screen.dart';
import 'screens/chatbot/chatbot_screen.dart';
import 'screens/denuncias/denuncias_from_screen.dart';
import 'screens/denuncias/denuncias_screen.dart';
import 'screens/denuncias/mapa_denuncias_screen.dart';
import 'screens/perfil/ciudadano_perfil_screen.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Denuncias Gad Salcedo',
      initialRoute: '/chatbottest',
      routes: {
        '/': (context) => const Login(),
        '/register': (context) => const Register(),
        '/register2': (context) => const Register2(),
        '/register3': (context) => const Register3(),
        '/register4': (context) => const Register4(),
        '/register5': (context) => const Register5(),
        '/denuncias': (context) => const DenunciasScreen(),
        '/form/denuncias': (context) => const DenunciasFormScreen(),
        '/chatbot': (context) => const ChatbotScreen(),
        '/mapadenuncias': (context) => const MapaDenunciasScreen(),
        '/perfil': (context) => const CiudadanoPerfilScreen(),
        '/ayuda': (context) => const AyudaScreen(),
        '/recuperar_password': (context) => const RecuperarPassword(),
        '/verificar_codigo': (context) => const VerificarCodigo(),
        '/cambiar_password': (context) => const CambiarPassword(),
        '/chatbottest': (context) => const ChatbotTestScreen(),
      },
    );
  }
}
