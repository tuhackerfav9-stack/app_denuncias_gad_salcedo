import 'package:flutter/material.dart';
import '../settings/geo_gate.dart';
import 'out_of_area_screen.dart';
import 'denuncias/denuncias_from_screen.dart';

class DenunciaGateScreen extends StatefulWidget {
  const DenunciaGateScreen({super.key});

  @override
  State<DenunciaGateScreen> createState() => _DenunciaGateScreenState();
}

class _DenunciaGateScreenState extends State<DenunciaGateScreen> {
  bool loading = true;
  bool allowed = false;
  String? errorMsg;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      loading = true;
      allowed = false;
      errorMsg = null;
    });

    final res = await GeoGate.check();

    if (!mounted) return;

    setState(() {
      loading = false;
      allowed = res.allowed;
      errorMsg = res.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (allowed) {
      return const DenunciasFormScreen();
    }

    return OutOfAreaScreen(
      message: errorMsg ?? "Fuera del perímetro.",
      onRetry: _run,
    );
  }
}
