import 'package:flutter/material.dart';
import '../settings/geo_gate.dart';
import 'out_of_area_screen.dart';

// tu form real
import 'denuncias/denuncias_from_screen.dart';

class DenunciaGateScreen extends StatefulWidget {
  const DenunciaGateScreen({super.key});

  @override
  State<DenunciaGateScreen> createState() => _DenunciaGateScreenState();
}

class _DenunciaGateScreenState extends State<DenunciaGateScreen> {
  bool loading = true;
  String? errorMsg;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      loading = true;
      errorMsg = null;
    });

    final res = await GeoGate.check();

    if (!mounted) return;

    if (res.allowed) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DenunciasFormScreen()),
      );
    } else {
      setState(() {
        loading = false;
        errorMsg = res.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return OutOfAreaScreen(
      message: errorMsg ?? "Fuera del perímetro.",
      onRetry: _run,
    );
  }
}
