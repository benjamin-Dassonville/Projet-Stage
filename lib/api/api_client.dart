import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../app_state.dart';

class ApiClient {
  static const String _baseUrl = 'http://localhost:3000';

  final Dio dio;

  ApiClient()
      : dio = Dio(
          BaseOptions(
            baseUrl: _baseUrl,
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 15),
            sendTimeout: const Duration(seconds: 15),
            headers: {
              'Content-Type': 'application/json',
            },
          ),
        ) {
    // ✅ IMPORTANT: ajoute Authorization à CHAQUE requête, en fonction du rôle courant
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Toujours s'assurer qu'on a une map
          options.headers = Map<String, dynamic>.from(options.headers);

          final role = authState.role;

          if (role != null) {
            // format attendu par ton backend: "Dev admin" / "Dev direction" / "Dev chef"
            options.headers['Authorization'] = 'Dev ${role.name}';
          } else {
            // si pas de rôle -> pas de header (sinon backend renvoie 401 de toute façon)
            options.headers.remove('Authorization');
          }

          return handler.next(options);
        },
      ),
    );

    // Logger utile (tu peux le laisser)
    dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: false,
        responseBody: true,
        error: true,
        logPrint: (o) => debugPrint(o.toString()),
      ),
    );
  }
}