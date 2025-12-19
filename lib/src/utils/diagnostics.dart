import 'package:flutter/foundation.dart';

/// Log levels for scroll_spy internal diagnostics.
enum ScrollSpyLogLevel {
  /// Verbose diagnostics intended for development/debug sessions.
  debug,

  /// High-level informational events.
  info,

  /// Recoverable issues or unexpected states that may affect behavior.
  warning,

  /// Errors that indicate misconfiguration or internal failures.
  error,
}

/// Signature for a log sink.
///
/// If you set [ScrollSpyDiagnostics.sink], the library will call it.
/// If null, diagnostics are no-op.
typedef ScrollSpyLogSink = void Function(
  ScrollSpyLogLevel level,
  String message, {
  Object? error,
  StackTrace? stackTrace,
  Map<String, Object?>? data,
});

/// Centralized diagnostics hook for the library.
///
/// By default, diagnostics are disabled (no-op).
/// Apps or tests may enable logging by setting [sink].
///
/// Performance:
/// Diagnostics calls may occur during scrolling/animation frames. Keep your
/// sink fast and avoid throwing exceptions from it.
final class ScrollSpyDiagnostics {
  ScrollSpyDiagnostics._();

  /// When set, diagnostics will call this sink. When null, diagnostics are disabled.
  static ScrollSpyLogSink? sink;

  /// Whether diagnostics are currently enabled.
  static bool get enabled => sink != null;

  /// Emits a debug-level message (no-op when [sink] is `null`).
  static void debug(String message, {Map<String, Object?>? data}) {
    _log(ScrollSpyLogLevel.debug, message, data: data);
  }

  /// Emits an info-level message (no-op when [sink] is `null`).
  static void info(String message, {Map<String, Object?>? data}) {
    _log(ScrollSpyLogLevel.info, message, data: data);
  }

  /// Emits a warning-level message (no-op when [sink] is `null`).
  static void warning(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
  }) {
    _log(
      ScrollSpyLogLevel.warning,
      message,
      error: error,
      stackTrace: stackTrace,
      data: data,
    );
  }

  /// Emits an error-level message (no-op when [sink] is `null`).
  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
  }) {
    _log(
      ScrollSpyLogLevel.error,
      message,
      error: error,
      stackTrace: stackTrace,
      data: data,
    );
  }

  static void _log(
    ScrollSpyLogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
  }) {
    final s = sink;
    if (s == null) return;

    s(level, message, error: error, stackTrace: stackTrace, data: data);
  }

  /// Convenience sink for quick debugging (prints via [debugPrint]).
  ///
  /// You can enable it like:
  /// `ScrollSpyDiagnostics.sink = ScrollSpyDiagnostics.debugPrintSink();`
  static ScrollSpyLogSink debugPrintSink({String tag = 'scroll_spy'}) {
    return (
      ScrollSpyLogLevel level,
      String message, {
      Object? error,
      StackTrace? stackTrace,
      Map<String, Object?>? data,
    }) {
      final buffer = StringBuffer()
        ..write('[$tag][${level.name}] ')
        ..write(message);

      if (data != null && data.isNotEmpty) {
        buffer.write(' | data=');
        buffer.write(data);
      }

      if (error != null) {
        buffer.write(' | error=');
        buffer.write(error);
      }

      if (stackTrace != null) {
        buffer.write('\n');
        buffer.write(stackTrace);
      }

      debugPrint(buffer.toString());
    };
  }
}
