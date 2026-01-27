import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart' show debugPrint;

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

      // ✅ DEBUG ultra clair
      debugPrint('➡️ ${options.method} ${options.uri}');
      debugPrint('➡️ Authorization: ${options.headers['Authorization']}');
      debugPrint('➡️ Headers: ${options.headers}');
      debugPrint('➡️ Data: ${options.data}');

          return handler.next(options);
        },
      ),
    );
  }

  /// Multi-plateforme propre :
  /// - WEB (Chrome/Safari/PWA) : on prend le hostname courant
  ///   Ex: tu ouvres http://192.168.1.148:57317 => API devient http://192.168.1.148:3000
  /// - Android emulator : 10.0.2.2
  /// - iOS simulator + desktop : localhost
  /// - Téléphone en app native iOS/Android (pas web) : il faut une IP (sinon localhost = téléphone)
  String _computeBaseUrl() {
    const port = 3000;

    if (kIsWeb) {
      // Sur le web, Uri.base contient l'URL réelle (host = domaine / IP)
      final host = (Uri.base.host.isEmpty) ? 'localhost' : Uri.base.host;
      // Si tu utilises https en prod, ton API devra aussi être en https (sinon mixed content).
      return 'http://$host:$port';
    }

    // Mobile / Desktop (non-web)
    // ✅ Pas de dart:io (ça casse la compilation web), on se base sur TargetPlatform.
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:$port'; // Android emulator -> host machine
    }

    // iOS simulator + macOS + Windows + Linux -> localhost OK
    return 'http://localhost:$port';
  }
}