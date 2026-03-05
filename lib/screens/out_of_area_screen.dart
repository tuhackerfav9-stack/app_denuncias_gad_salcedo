import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class OutOfAreaScreen extends StatelessWidget {
  static const Color primaryBlue = Color(0xFF2C64C4);

  final String message;
  final VoidCallback onRetry;

  const OutOfAreaScreen({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          child: Column(
            children: [
              const SizedBox(height: 18),

              // Logo (igual que login)
              Image.asset(
                'assets/logo_gad_municipal_letras.png',
                height: 90,
                fit: BoxFit.contain,
              ),

              const SizedBox(height: 24),

              Container(
                width: 78,
                height: 78,
                decoration: const BoxDecoration(
                  color: primaryBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_off,
                  color: Colors.white,
                  size: 42,
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                "Fuera del cantón Salcedo",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: Colors.grey.shade700,
                  height: 1.3,
                ),
              ),

              const SizedBox(height: 22),

              // Botón reintentar
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text(
                    "Reintentar",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Botón abrir ajustes
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Geolocator.openAppSettings();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryBlue,
                    side: const BorderSide(color: primaryBlue, width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.settings),
                  label: const Text(
                    "Abrir ajustes",
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),

              const Spacer(),

              Text(
                "Nota: Este control es solo para registrar denuncias.\nPuedes navegar y consultar desde cualquier lugar.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
              ),

              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
