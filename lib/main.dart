import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'settings/push_service.dart';
import 'settings/session_guard.dart';

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
import 'screens/denuncias/detalle_denuncia_screen.dart';
import 'screens/denuncias/mapa_denuncias_screen.dart';
import 'screens/perfil/ciudadano_perfil_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  //runApp(const MyApp());
  //PushService.init();

  await PushService.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Denuncias Gad Salcedo',
      initialRoute: '/',
      routes: {
        '/': (context) => const Login(),
        '/register': (context) => const Register(),
        '/register2': (context) => const Register2(),
        '/register3': (context) => const Register3(),
        '/register4': (context) => const Register4(),
        '/register5': (context) => const Register5(),
        '/denuncias': (context) => SessionGuard(child: const DenunciasScreen()),
        '/form/denuncias': (context) =>
            SessionGuard(child: const DenunciasFormScreen()),
        '/chatbot': (context) => SessionGuard(child: const ChatbotScreen()),
        '/mapadenuncias': (context) =>
            SessionGuard(child: const MapaDenunciasScreen()),
        '/perfil': (context) =>
            SessionGuard(child: const CiudadanoPerfilScreen()),
        '/ayuda': (context) => SessionGuard(child: const AyudaScreen()),
        '/recuperar_password': (context) => const RecuperarPassword(),
        '/verificar_codigo': (context) => const VerificarCodigo(),
        '/cambiar_password': (context) => const CambiarPassword(),
        '/detalle_denuncia': (context) =>
            SessionGuard(child: const DetalleDenunciaScreen()),
      },
    );
  }
}
