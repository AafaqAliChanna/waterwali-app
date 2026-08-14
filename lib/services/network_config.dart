import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' as io;

class NetworkConfig {
  static String apiBaseUrl({required bool isWeb, required bool isAndroid}) {
    if (isWeb) {
      return 'http://localhost:8080/api';
    }
    if (isAndroid) {
      return 'http://10.0.2.2:8080/api';
    }
    return 'http://localhost:8080/api';
  }

  static String wsUrl({required bool isWeb, required bool isAndroid}) {
    if (isWeb) {
      return 'ws://localhost:8080/ws';
    }
    if (isAndroid) {
      return 'ws://10.0.2.2:8080/ws';
    }
    return 'ws://localhost:8080/ws';
  }

  // CHANGED: check kIsWeb FIRST and return immediately -- io.Platform.isAndroid
  // is now only ever touched when we already know we're NOT on web, so it
  // never gets the chance to crash.
  static String get apiBaseUrlForRuntime {
    if (kIsWeb) return apiBaseUrl(isWeb: true, isAndroid: false);
    return apiBaseUrl(isWeb: false, isAndroid: io.Platform.isAndroid);
  }

  static String get wsUrlForRuntime {
    if (kIsWeb) return wsUrl(isWeb: true, isAndroid: false);
    return wsUrl(isWeb: false, isAndroid: io.Platform.isAndroid);
  }
}