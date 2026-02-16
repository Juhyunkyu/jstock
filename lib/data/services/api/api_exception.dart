/// API 관련 예외 기본 클래스
abstract class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic originalError;

  const ApiException({
    required this.message,
    this.statusCode,
    this.originalError,
  });

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}

/// 네트워크 연결 실패 예외
class NetworkException extends ApiException {
  const NetworkException({
    super.message = '네트워크 연결에 실패했습니다',
    super.originalError,
  }) : super(statusCode: null);

  @override
  String toString() => 'NetworkException: $message';
}

/// 서버 응답 오류 예외
class ServerException extends ApiException {
  const ServerException({
    required super.message,
    required super.statusCode,
    super.originalError,
  });

  @override
  String toString() => 'ServerException: $message (status: $statusCode)';
}

/// JSON 파싱 오류 예외
class ParseException extends ApiException {
  const ParseException({
    super.message = '데이터 파싱에 실패했습니다',
    super.originalError,
  }) : super(statusCode: null);

  @override
  String toString() => 'ParseException: $message';
}

/// 요청 제한 초과 예외
class RateLimitException extends ApiException {
  final Duration? retryAfter;

  const RateLimitException({
    super.message = 'API 요청 제한을 초과했습니다',
    this.retryAfter,
    super.originalError,
  }) : super(statusCode: 429);

  @override
  String toString() =>
      'RateLimitException: $message (retry after: ${retryAfter?.inSeconds}s)';
}

/// 인증 오류 예외
class UnauthorizedException extends ApiException {
  const UnauthorizedException({
    super.message = '인증에 실패했습니다',
    super.originalError,
  }) : super(statusCode: 401);

  @override
  String toString() => 'UnauthorizedException: $message';
}

/// 데이터 없음 예외
class NotFoundException extends ApiException {
  const NotFoundException({
    super.message = '요청한 데이터를 찾을 수 없습니다',
    super.originalError,
  }) : super(statusCode: 404);

  @override
  String toString() => 'NotFoundException: $message';
}

/// 요청 타임아웃 예외
class TimeoutException extends ApiException {
  const TimeoutException({
    super.message = '요청 시간이 초과되었습니다',
    super.originalError,
  }) : super(statusCode: null);

  @override
  String toString() => 'TimeoutException: $message';
}
