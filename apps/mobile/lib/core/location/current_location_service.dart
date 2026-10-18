import 'package:geolocator/geolocator.dart';

import 'package:geocoding/geocoding.dart';

class CurrentAddress {
  const CurrentAddress({
    this.zipCode,
    this.street,
    this.number,
    this.district,
    this.city,
    this.state,
  });

  final String? zipCode;
  final String? street;
  final String? number;
  final String? district;
  final String? city;
  final String? state;
}

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
    this.address,
    required this.message,
    required this.isSuccess,
  });

  final CurrentLocation? location;
  final CurrentAddress? address;
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

    CurrentAddress? address;
    var message = 'Localização detectada.';
    try {
      final placemarks = await Geocoding().placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        address = CurrentAddress(
          zipCode: placemark.postalCode,
          street: placemark.street ?? placemark.thoroughfare,
          number: placemark.subThoroughfare,
          district: placemark.subLocality ?? placemark.subAdministrativeArea,
          city: placemark.locality ?? placemark.subAdministrativeArea,
          state: placemark.administrativeArea,
        );
        message = 'Localização e endereço detectados. Confira os dados.';
      }
    } catch (_) {
      message = 'Localização detectada, mas não foi possível obter o endereço. '
          'Preencha os campos ausentes manualmente.';
    }

    return CurrentLocationResult(
      location: CurrentLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      ),
      address: address,
      message: message,
      isSuccess: true,
    );
  }
}
