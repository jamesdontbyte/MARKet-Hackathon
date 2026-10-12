import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase.dart';
import '../models/business.dart';
import '../models/chat.dart';

/// Type definition for edge function invocation (allows pure unit test faking without mocks)
typedef FunctionInvoker = Future<FunctionResponse> Function(
  String functionName, {
  Map<String, dynamic>? body,
  Map<String, String>? headers,
});

/// Service responsible for calling the Supabase Edge Function 'chat'
/// History remains strictly in-memory per session.
class ChatService {
  final FunctionInvoker _invoker;

  ChatService({FunctionInvoker? invoker})
      : _invoker = invoker ??
            ((String fn, {Map<String, dynamic>? body, Map<String, String>? headers}) =>
                supabase.functions.invoke(fn, body: body, headers: headers));

  /// Calculates distances in meters between current device location and verified businesses.
  /// Coordinates are strictly processed on-device and never transmitted to the backend.
  Future<Map<String, double>> computeBusinessDistances(
    List<Business> businesses,
  ) async {
    final distances = <String, double>{};
    try {
      Position? position;
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        position = await Geolocator.getLastKnownPosition() ??
            await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                timeLimit: Duration(seconds: 3),
              ),
            );
      }

      if (position != null) {
        for (final b in businesses) {
          final dist = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            b.lat,
            b.lng,
          );
          distances[b.id] = dist;
        }
      }
    } catch (_) {
      // Graceful fallback: return empty distance map if location is unavailable
    }
    return distances;
  }

  /// Sends the conversation history to the Supabase chat edge function.
  Future<ChatMessage> sendMessage({
    required List<ChatMessage> history,
    Map<String, double>? distances,
  }) async {
    try {
      final messagesPayload = history.map((m) => m.toJson()).toList();

      final body = <String, dynamic>{
        'messages': messagesPayload,
      };
      if (distances != null && distances.isNotEmpty) {
        body['distances'] = distances;
      }

      final response = await _invoker('chat', body: body);

      if (response.status == 429) {
        return ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          role: ChatRole.assistant,
          content:
              'Rate limit reached. You can make up to 20 requests per hour. Please try again in a little while.',
          isError: true,
          timestamp: DateTime.now(),
        );
      }

      final data = response.data;
      if (data is Map<String, dynamic>) {
        if (data.containsKey('error')) {
          final errCode = data['code'];
          final errMsg = data['error'] as String? ??
              'The assistant is temporarily unavailable. Please try again.';
          return ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            role: ChatRole.assistant,
            content: errCode == 'rate_limited'
                ? 'Rate limit reached. You can make up to 20 requests per hour. Please try again in a little while.'
                : errMsg,
            isError: true,
            timestamp: DateTime.now(),
          );
        }

        final reply = data['reply'] as String? ?? 'No response received.';
        AssistantAction? action;
        if (data['action'] != null && data['action'] is Map<String, dynamic>) {
          action = AssistantAction.fromJson(
            Map<String, dynamic>.from(data['action'] as Map),
          );
        }

        final suggestedPromos = <SuggestedPromo>[];
        if (data['suggested_promos'] is List) {
          for (final item in data['suggested_promos'] as List) {
            if (item is Map) {
              suggestedPromos.add(
                SuggestedPromo.fromJson(Map<String, dynamic>.from(item)),
              );
            }
          }
        }
        if (suggestedPromos.isEmpty &&
            action != null &&
            (action.name == 'open_promo' || action.name == 'propose_save_to_stash')) {
          final pid = action.args['promo_id']?.toString() ?? '';
          final title = action.args['title']?.toString() ??
              action.args['promo_title']?.toString() ??
              '';
          if (pid.isNotEmpty && title.isNotEmpty) {
            suggestedPromos.add(
              SuggestedPromo(
                id: pid,
                title: title,
                businessName: action.args['business_name']?.toString() ?? '',
                value: action.args['value_label']?.toString() ?? '',
                distance: action.args['distance']?.toString(),
              ),
            );
          }
        }

        return ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          role: ChatRole.assistant,
          content: reply,
          action: action,
          suggestedPromos: suggestedPromos,
          isError: false,
          timestamp: DateTime.now(),
        );
      }

      return ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: ChatRole.assistant,
        content: 'Received an unexpected response format. Please try again.',
        isError: true,
        timestamp: DateTime.now(),
      );
    } on FunctionException catch (e) {
      if (e.status == 429) {
        return ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          role: ChatRole.assistant,
          content:
              'Rate limit reached. You can make up to 20 requests per hour. Please try again in a little while.',
          isError: true,
          timestamp: DateTime.now(),
        );
      }
      return ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: ChatRole.assistant,
        content:
            'The assistant is temporarily unavailable. Please try again in a moment.',
        isError: true,
        timestamp: DateTime.now(),
      );
    } on SocketException catch (_) {
      return ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: ChatRole.assistant,
        content:
            'Unable to connect. Please check your internet connection and try again.',
        isError: true,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socket') || errStr.contains('network') || errStr.contains('clientexception')) {
        return ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          role: ChatRole.assistant,
          content:
              'Unable to connect. Please check your internet connection and try again.',
          isError: true,
          timestamp: DateTime.now(),
        );
      }
      return ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: ChatRole.assistant,
        content:
            'An unexpected error occurred while communicating with the assistant. Please try again.',
        isError: true,
        timestamp: DateTime.now(),
      );
    }
  }
}
