import 'package:flutter/material.dart';

import 'screens/autch/login.dart';
import 'screens/autch/register.dart';
import 'screens/autch/register2.dart';
import 'screens/denuncias/denuncias_from_screen.dart';
import 'screens/denuncias/denuncias_screen.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Denuncias Gad Salcedo',
      initialRoute: '/denuncias',
      routes: {
        '/': (context) => const Login(),
        '/register': (context) => const Register(),
        '/register2': (context) => const Register2(),
        '/denuncias': (context) => const DenunciasScreen(),
        '/form/denuncias': (context) => const DenunciasFormScreen(),
      },
    );
  }
}
