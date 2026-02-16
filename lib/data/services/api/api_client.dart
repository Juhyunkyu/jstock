import 'package:dio/dio.dart';
import 'api_exception.dart';

/// API 클라이언트 기본 설정
class ApiClient {
  late final Dio _dio;

  ApiClient({
    String? baseUrl,
    Duration connectTimeout = const Duration(seconds: 10),
    Duration receiveTimeout = const Duration(seconds: 15),
  }) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl ?? '',
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ));

    _setupInterceptors();
  }

  Dio get dio => _dio;

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // 요청 로깅 (디버그용)
          // print('🌐 Request: ${options.method} ${options.uri}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          // 응답 로깅 (디버그용)
          // print('✅ Response: ${response.statusCode}');
          handler.next(response);
        },
        onError: (error, handler) {
          // 에러 변환
          final apiException = _convertToApiException(error);
          handler.reject(DioException(
            requestOptions: error.requestOptions,
            error: apiException,
            type: error.type,
            response: error.response,
          ));
        },
      ),
    );
  }

  ApiException _convertToApiException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return TimeoutException(originalError: error);

      case DioExceptionType.connectionError:
        return NetworkException(originalError: error);

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final message = _extractErrorMessage(error.response);

        switch (statusCode) {
          case 401:
            return UnauthorizedException(
              message: message,
              originalError: error,
            );
          case 404:
            return NotFoundException(
              message: message,
              originalError: error,
            );
          case 429:
            final retryAfter = _extractRetryAfter(error.response);
            return RateLimitException(
              message: message,
              retryAfter: retryAfter,
              originalError: error,
            );
          default:
            return ServerException(
              message: message,
              statusCode: statusCode ?? 500,
              originalError: error,
            );
        }

      case DioExceptionType.cancel:
        return const NetworkException(message: '요청이 취소되었습니다');

      case DioExceptionType.unknown:
      case DioExceptionType.badCertificate:
        return NetworkException(
          message: error.message ?? '알 수 없는 오류가 발생했습니다',
          originalError: error,
        );
    }
  }

  String _extractErrorMessage(Response? response) {
    if (response?.data == null) {
      return '서버 오류가 발생했습니다';
    }

    final data = response!.data;
    if (data is Map<String, dynamic>) {
      return data['message'] ??
          data['error'] ??
          data['error_description'] ??
          '서버 오류가 발생했습니다';
    }

    return '서버 오류가 발생했습니다';
  }

  Duration? _extractRetryAfter(Response? response) {
    final retryAfterHeader = response?.headers.value('retry-after');
    if (retryAfterHeader != null) {
      final seconds = int.tryParse(retryAfterHeader);
      if (seconds != null) {
        return Duration(seconds: seconds);
      }
    }
    return null;
  }

  /// GET 요청
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      if (e.error is ApiException) {
        throw e.error as ApiException;
      }
      throw _convertToApiException(e);
    }
  }

  /// POST 요청
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      if (e.error is ApiException) {
        throw e.error as ApiException;
      }
      throw _convertToApiException(e);
    }
  }
}
