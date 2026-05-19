import 'package:flutter/foundation.dart';

class DebugLogger {
  static void log(String message, {String? tag}) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag] ' : '';
      print('$prefix$message');
    }
  }

  static void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag] ERROR: ' : 'ERROR: ';
      print('$prefix$message');
      if (error != null) {
        print('Error details: $error');
      }
      if (stackTrace != null) {
        print('Stack trace: $stackTrace');
      }
    }
  }

  static void warning(String message, {String? tag}) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag] WARNING: ' : 'WARNING: ';
      print('$prefix$message');
    }
  }

  static void success(String message, {String? tag}) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag] ✅ ' : '✅ ';
      print('$prefix$message');
    }
  }

  
  static void api(String message, {Object? error}) {
    if (kDebugMode) {
      final prefix = error != null ? '[API] ERROR: ' : '[API] ';
      print('$prefix$message');
      if (error != null) {
        print('Error details: $error');
      }
    }
  }

  static void ui(String message) {
    log(message, tag: 'UI');
  }
}
