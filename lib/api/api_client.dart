import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show debugPrint;
import 'dart:io' show Platform;

import '../app_state.dart';
import '../auth/app_role.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;

  ApiClient._internal() {
    final baseUrl = _computeBaseUrl();

    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ),
    );

    // Debug (utile pour vérifier sur quelle URL il tape)
    debugPrint('[ApiClient] baseUrl=$baseUrl');

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final AppRole? role = authState.role;

          if (role != null) {
            final roleStr = switch (role) {
              AppRole.chef => 'chef',
              AppRole.admin => 'admin',
              AppRole.direction => 'direction',
            };

            options.headers['Authorization'] = 'Dev $roleStr';
          }

          return handler.next(options);
        },
      ),
    );
  }

  /// Multi-plateforme:
  /// - Web: localhost
  /// - Android emulator: 10.0.2.2 (alias vers la machine hôte)
  /// - iOS simulator: localhost
  /// - Desktop: localhost
  ///
  /// ⚠️ Sur Android device réel: il faudra l’IP de ton PC (ex: 192.168.1.20)
  String _computeBaseUrl() {
    const port = 3000;

    // Web
    if (kIsWeb) {
      return 'http://localhost:$port';
    }

    // Mobile / Desktop (non-web)
    try {
      if (Platform.isAndroid) {
        // Android Emulator -> host machine
        return 'http://10.0.2.2:$port';
      }

      // iOS simulator + macOS + Windows + Linux -> localhost ok
      return 'http://localhost:$port';
    } catch (_) {
      // Si Platform n'est pas dispo dans un contexte bizarre, fallback safe
      return 'http://localhost:$port';
    }
  }
}