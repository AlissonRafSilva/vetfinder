import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig._();

  static const _definedApiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (_definedApiBaseUrl.isNotEmpty) {
      return _definedApiBaseUrl;
    }

    if (kIsWeb) {
      return 'http://localhost:3000/v1';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:3000/v1';
      case TargetPlatform.iOS:
        return 'http://localhost:3000/v1';
      default:
        return 'http://localhost:3000/v1';
    }
  }
}
