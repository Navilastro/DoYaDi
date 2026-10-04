/// Tip-güvenli hata yönetimi için sealed class.
/// Harici paket (dartz, fpdart) bağımlılığı yerine hafif özel implementasyon.
///
/// Kullanım:
/// ```dart
/// final result = await connectWifi(ip);
/// switch (result) {
///   case Success():
///     print('Bağlandı!');
///   case Failure(:final message):
///     print('Hata: $message');
/// }
/// ```
sealed class Result<T> {
  const Result();

  /// Başarılı mı?
  bool get isSuccess => this is Success<T>;

  /// Başarısız mı?
  bool get isFailure => this is Failure<T>;

  /// Başarılı ise değeri döndürür, değilse [orElse] değerini döndürür.
  T? valueOrNull() => switch (this) {
        Success<T>(:final value) => value,
        Failure<T>() => null,
      };

  /// Hata mesajını döndürür, başarılı ise null.
  String? get errorMessage => switch (this) {
        Success<T>() => null,
        Failure<T>(:final message) => message,
      };
}

/// Başarılı sonuç.
class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);

  @override
  String toString() => 'Success($value)';
}

/// Başarısız sonuç.
class Failure<T> extends Result<T> {
  final String message;
  final Object? error;
  const Failure(this.message, [this.error]);

  @override
  String toString() => 'Failure($message${error != null ? ', $error' : ''})';
}
