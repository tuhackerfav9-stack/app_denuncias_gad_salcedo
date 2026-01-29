import 'package:flutter/material.dart';
import '../settings/api_exception.dart';

class ErrorView extends StatelessWidget {
  final ApiException error;
  final VoidCallback? onRetry;

  const ErrorView({super.key, required this.error, this.onRetry});

  String _assetFor(ApiErrorType t) {
    switch (t) {
      case ApiErrorType.network:
        return "assets/errors/error_0.png";
      case ApiErrorType.timeout:
        return "assets/errors/error_408.png";
      case ApiErrorType.forbidden:
        return "assets/errors/error_403.png";
      case ApiErrorType.unauthorized:
        return "assets/errors/error_401.png";
      case ApiErrorType.server:
        return "assets/errors/error_500.png";
      default:
        return "assets/errors/error_desconocido.png";
    }
  }

  String _titleFor(ApiErrorType t) {
    switch (t) {
      case ApiErrorType.network:
        return "Sin conexión";
      case ApiErrorType.timeout:
        return "Tiempo de espera";
      case ApiErrorType.forbidden:
        return "No autorizado";
      case ApiErrorType.unauthorized:
        return "Sesión expirada";
      case ApiErrorType.server:
        return "Error del servidor";
      default:
        return "Ocurrió un error";
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _titleFor(error.type);
    final asset = _assetFor(error.type);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(asset, height: 180),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error.message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 18),
            if (onRetry != null)
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text("Reintentar"),
              ),
          ],
        ),
      ),
    );
  }
}
