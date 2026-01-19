import 'package:dio/dio.dart';
import '../app_state.dart';
import '../auth/app_role.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: 'http://localhost:3000',
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final AppRole? role = authState.role; // <-- IMPORTANT : authState, pas AuthState.instance

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
}