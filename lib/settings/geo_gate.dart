import 'package:geolocator/geolocator.dart';

class GeoGateResult {
  final bool allowed;
  final String message;
  final Position? position;

  GeoGateResult({required this.allowed, required this.message, this.position});
}

class GeoGate {
  /// ✅ Bounding box “amplio” para no perder denuncias.
  /// Ajusta luego con datos más exactos si deseas.
  ///
  /// Zona alrededor de Salcedo (aprox) - MÁS grande que el centro urbano.
  /// OJO: Si lo haces demasiado grande, vas a permitir fuera del cantón.
  static const double minLat = -1.1200;
  static const double maxLat = -1.0000;
  static const double minLng = -78.6400;
  static const double maxLng = -78.5000;

  static bool _inBox(double lat, double lng) {
    return lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;
  }

  /// Pide ubicación y valida
  static Future<GeoGateResult> check({
    Duration timeout = const Duration(seconds: 18),
  }) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return GeoGateResult(
        allowed: false,
        message: "Activa el GPS para enviar una denuncia.",
      );
    }

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    if (perm == LocationPermission.denied) {
      return GeoGateResult(
        allowed: false,
        message: "Necesitamos tu ubicación para validar el cantón.",
      );
    }

    if (perm == LocationPermission.deniedForever) {
      return GeoGateResult(
        allowed: false,
        message:
            "Permiso de ubicación bloqueado. Actívalo en Ajustes para continuar.",
      );
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(timeout);

      final ok = _inBox(pos.latitude, pos.longitude);

      return GeoGateResult(
        allowed: ok,
        position: pos,
        message: ok
            ? "Ubicación válida."
            : "Estás fuera del perímetro permitido para registrar denuncias en Salcedo.",
      );
    } catch (_) {
      return GeoGateResult(
        allowed: false,
        message: "No pudimos obtener tu ubicación. Reintenta con GPS activado.",
      );
    }
  }
}
