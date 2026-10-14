import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase.dart';
import '../models/scanned_menu_item.dart';

/// Type definition for edge function invocation (allows pure unit test faking without mocks)
typedef FunctionInvoker = Future<FunctionResponse> Function(
  String functionName, {
  Map<String, dynamic>? body,
  Map<String, String>? headers,
});

/// Typed exception for menu scanning errors with user-friendly messages
class ScanException implements Exception {
  final String message;
  final String code;

  const ScanException(this.message, {this.code = 'generic'});

  @override
  String toString() => message;
}

/// Service responsible for invoking the Supabase 'scan-menu' Edge Function
class ScanService {
  final FunctionInvoker _invoker;

  ScanService({FunctionInvoker? invoker})
      : _invoker = invoker ??
            ((String fn, {Map<String, dynamic>? body, Map<String, String>? headers}) =>
                supabase.functions.invoke(fn, body: body, headers: headers));

  /// Extracts menu items from 1-4 base64 images by calling the scan-menu Edge Function.
  /// [images] is a list of maps containing 'mime' and 'data' (base64 string).
  Future<ScanMenuResult> scanMenu({
    required List<Map<String, String>> images,
    String? businessType,
  }) async {
    if (images.isEmpty) {
      throw const ScanException(
        'Please select at least one menu photo.',
        code: 'invalid_payload',
      );
    }
    if (images.length > 4) {
      throw const ScanException(
        'You can scan at most 4 photos at a time.',
        code: 'invalid_payload',
      );
    }

    try {
      final body = <String, dynamic>{
        'images': images,
      };
      if (businessType != null && businessType.isNotEmpty) {
        body['business_type'] = businessType;
      }

      final response = await _invoker('scan-menu', body: body);

      if (response.status == 429) {
        throw const ScanException(
          'Rate limit reached. You can scan up to 10 menus per hour. Please try again later.',
          code: 'rate_limited',
        );
      }

      final data = response.data;
      if (data is Map<String, dynamic>) {
        if (data.containsKey('error')) {
          final errCode = data['code']?.toString() ?? 'generic';
          final errMsg = data['error']?.toString();

          if (errCode == 'rate_limited' || response.status == 429) {
            throw const ScanException(
              'Rate limit reached. You can scan up to 10 menus per hour. Please try again later.',
              code: 'rate_limited',
            );
          } else if (errCode == 'unreadable' || response.status == 422) {
            throw const ScanException(
              "I couldn't read this photo, try a clearer one",
              code: 'unreadable',
            );
          } else if (errCode == 'gemini_error' || response.status == 502) {
            throw const ScanException(
              'The menu scanner is temporarily unavailable. Please try again shortly.',
              code: 'server_error',
            );
          } else {
            throw ScanException(
              errMsg ?? 'The menu scanner is temporarily unavailable. Please try again shortly.',
              code: errCode,
            );
          }
        }

        final rawItems = data['items'];
        final notes = data['notes'] as String?;
        final items = <ScannedMenuItem>[];

        if (rawItems is List) {
          for (final item in rawItems) {
            if (item is Map) {
              items.add(ScannedMenuItem.fromJson(Map<String, dynamic>.from(item)));
            }
          }
        }

        if (items.isEmpty) {
          throw const ScanException(
            "I couldn't read this photo, try a clearer one",
            code: 'unreadable',
          );
        }

        return ScanMenuResult(
          items: items,
          notes: notes,
        );
      }

      throw const ScanException(
        'The menu scanner is temporarily unavailable. Please try again shortly.',
        code: 'server_error',
      );
    } on ScanException {
      rethrow;
    } on FunctionException catch (e) {
      if (e.status == 429) {
        throw const ScanException(
          'Rate limit reached. You can scan up to 10 menus per hour. Please try again later.',
          code: 'rate_limited',
        );
      } else if (e.status == 422) {
        throw const ScanException(
          "I couldn't read this photo, try a clearer one",
          code: 'unreadable',
        );
      } else if (e.status == 500 || e.status == 502) {
        throw const ScanException(
          'The menu scanner is temporarily unavailable. Please try again shortly.',
          code: 'server_error',
        );
      }
      throw const ScanException(
        'The menu scanner is temporarily unavailable. Please try again shortly.',
        code: 'server_error',
      );
    } on SocketException catch (_) {
      throw const ScanException(
        'Unable to connect. Please check your internet connection and try again.',
        code: 'no_internet',
      );
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socket') ||
          errStr.contains('network') ||
          errStr.contains('clientexception') ||
          errStr.contains('failed host lookup')) {
        throw const ScanException(
          'Unable to connect. Please check your internet connection and try again.',
          code: 'no_internet',
        );
      }
      throw ScanException(
        'The menu scanner is temporarily unavailable. Please try again shortly.',
        code: 'server_error',
      );
    }
  }
}
