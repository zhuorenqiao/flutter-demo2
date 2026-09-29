import 'package:dio/dio.dart';

/// 后端返回的业务错误：`code` 是统一响应体里的业务码，`statusCode` 是 HTTP 状态。
class ApiException implements Exception {
  const ApiException(this.message, {this.code, this.statusCode});

  final String message;
  final int? code;
  final int? statusCode;

  bool get unauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// 轻量 REST 客户端：注入 Bearer token，把错误统一成 [ApiException]。
class ApiClient {
  ApiClient({
    required String baseUrl,
    required this.token,
    this.onUnauthorized,
    HttpClientAdapter? adapter,
  }) : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 20),
          headers: {'Accept': 'application/json'},
        ),
      ) {
    if (adapter != null) _dio.httpClientAdapter = adapter;
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final t = token();
          if (t != null && t.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $t';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final String? Function() token;
  final void Function()? onUnauthorized;

  /// baseUrl 变化后重建连接（改服务器地址时用）。
  void updateBaseUrl(String baseUrl) => _dio.options.baseUrl = baseUrl;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get(path, queryParameters: _clean(query)));

  Future<dynamic> post(String path, Object? body) => _send(() => _dio.post(path, data: body));

  Future<dynamic> delete(String path) => _send(() => _dio.delete(path));

  Future<dynamic> _send(Future<Response<dynamic>> Function() request) async {
    try {
      final response = await request();
      return _unwrap(response.data);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401) onUnauthorized?.call();
      throw ApiException(_messageOf(e, status), code: _codeOf(e), statusCode: status);
    }
  }

  /// 后端统一响应体 `{code, message, success, data}`，上层只取 data。
  static dynamic _unwrap(dynamic body) {
    if (body is Map && body.containsKey('data')) return body['data'];
    return body;
  }

  static int? _codeOf(DioException e) {
    final data = e.response?.data;
    final code = data is Map ? data['code'] : null;
    return code is num ? code.toInt() : null;
  }

  static String _messageOf(DioException e, int? status) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return '连不上服务器，请检查后端是否已启动';
    }
    if (status != null) return '请求失败（HTTP $status）';
    return e.message ?? '请求失败';
  }

  static Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    if (query == null) return null;
    query.removeWhere((_, v) => v == null);
    return query;
  }
}
