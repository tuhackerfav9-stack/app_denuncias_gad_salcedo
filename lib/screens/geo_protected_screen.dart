import 'package:flutter/material.dart';
import '../settings/geo_gate.dart';
import 'out_of_area_screen.dart';

class GeoProtectedScreen extends StatefulWidget {
  final WidgetBuilder builder; // pantalla destino si pasa
  const GeoProtectedScreen({super.key, required this.builder});

  @override
  State<GeoProtectedScreen> createState() => _GeoProtectedScreenState();
}

class _GeoProtectedScreenState extends State<GeoProtectedScreen> {
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
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: widget.builder));
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
