import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  static const apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    return apiUrl.isNotEmpty
        ? '$apiUrl/api'
        : kDebugMode 
            ? Platform.isAndroid
                ? 'http://10.0.2.2:5050/api'     // Android emulator
                : 'http://localhost:5050/api'     // iOS simulator
            : 'http://localhost:5050/api';       // Production
  }
} 