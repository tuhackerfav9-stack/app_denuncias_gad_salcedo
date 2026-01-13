import 'package:flutter/material.dart';
import 'session.dart';

class SessionGuard extends StatefulWidget {
  final Widget child;
  final String loginRoute;

  const SessionGuard({super.key, required this.child, this.loginRoute = '/'});

  @override
  State<SessionGuard> createState() => _SessionGuardState();
}

class _SessionGuardState extends State<SessionGuard> {
  bool loading = true;
  bool allowed = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final access = await Session.access();

    if (!mounted) return;

    if (access == null || access.isEmpty) {
      //  No hay sesión: manda a login
      Navigator.pushNamedAndRemoveUntil(
        context,
        widget.loginRoute,
        (r) => false,
      );
      return;
    }

    //  Hay sesión
    setState(() {
      allowed = true;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return allowed ? widget.child : const SizedBox.shrink();
  }
}
