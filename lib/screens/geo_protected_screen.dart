import 'package:flutter/material.dart';
import '../settings/geo_gate.dart';
import 'out_of_area_screen.dart';

class GeoProtectedScreen extends StatefulWidget {
  final WidgetBuilder builder;

  const GeoProtectedScreen({super.key, required this.builder});

  @override
  State<GeoProtectedScreen> createState() => _GeoProtectedScreenState();
}

class _GeoProtectedScreenState extends State<GeoProtectedScreen> {
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
      // IMPORTANTE:
      // No navegamos a otra ruta.
      // Renderizamos la pantalla destino dentro de la MISMA ruta,
      // así se conservan los arguments del Navigator.pushNamed(...)
      return Builder(builder: widget.builder);
    }

    return OutOfAreaScreen(
      message: errorMsg ?? "Fuera del perímetro.",
      onRetry: _run,
    );
  }
}
