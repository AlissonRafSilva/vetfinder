import 'package:geolocator/geolocator.dart';

class CurrentLocation {
  const CurrentLocation({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}

class CurrentLocationResult {
  const CurrentLocationResult({
    this.location,
    required this.message,
    required this.isSuccess,
  });

  final CurrentLocation? location;
  final String message;
  final bool isSuccess;
}

class CurrentLocationService {
  const CurrentLocationService();

  Future<CurrentLocationResult> detect() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const CurrentLocationResult(
        message:
            'Ative a localização do dispositivo para preencher automaticamente.',
        isSuccess: false,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return const CurrentLocationResult(
        message:
            'Permissão de localização bloqueada. Libere nas configurações do aparelho.',
        isSuccess: false,
      );
    }

    if (permission == LocationPermission.denied) {
      return const CurrentLocationResult(
        message:
            'Permissão de localização negada. Você pode preencher manualmente.',
        isSuccess: false,
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    return CurrentLocationResult(
      location: CurrentLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      ),
      message: 'Localização detectada com sucesso.',
      isSuccess: true,
    );
  }
}
