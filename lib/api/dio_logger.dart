import 'dart:convert';
import 'package:dio/dio.dart';

class DioLogger extends Interceptor {
  const DioLogger();

  String _pretty(dynamic data) {
    try {
      if (data == null) return 'null';
      if (data is String) return data;
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data.toString();
    }
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final headers = Map<String, dynamic>.from(options.headers);
    // si tu as un token un jour, masque-le ici
    if (headers.containsKey('Authorization')) {
      headers['Authorization'] = '***';
    }

    // ignore: avoid_print
    print('┌──────────────────────────────────────────────');
    // ignore: avoid_print
    print('│ ➜ ${options.method} ${options.uri}');
    // ignore: avoid_print
    print('│ Headers: ${_pretty(headers)}');
    if (options.queryParameters.isNotEmpty) {
      // ignore: avoid_print
      print('│ Query: ${_pretty(options.queryParameters)}');
    }
    if (options.data != null) {
      // ignore: avoid_print
      print('│ Body: ${_pretty(options.data)}');
    }
    // ignore: avoid_print
    print('└──────────────────────────────────────────────');

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // ignore: avoid_print
    print('┌──────────────────────────────────────────────');
    // ignore: avoid_print
    print('│ ✅ ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.uri}');
    // ignore: avoid_print
    print('│ Response: ${_pretty(response.data)}');
    // ignore: avoid_print
    print('└──────────────────────────────────────────────');

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final r = err.response;
    // ignore: avoid_print
    print('┌──────────────────────────────────────────────');
    // ignore: avoid_print
    print('│ ❌ DIO ERROR ${err.type}');
    // ignore: avoid_print
    print('│ ➜ ${err.requestOptions.method} ${err.requestOptions.uri}');
    if (r != null) {
      // ignore: avoid_print
      print('│ Status: ${r.statusCode}');
      // ignore: avoid_print
      print('│ Response: ${_pretty(r.data)}');
    } else {
      // ignore: avoid_print
      print('│ No response (network / CORS / timeout)');
    }
    // ignore: avoid_print
    print('│ Message: ${err.message}');
    // ignore: avoid_print
    print('└──────────────────────────────────────────────');

    handler.next(err);
  }
}