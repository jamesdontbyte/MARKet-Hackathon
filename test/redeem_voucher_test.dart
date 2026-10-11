import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_final/services/data_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Hand-written fake for PostgrestFilterBuilder completing with custom RPC response
class FakePostgrestFilterBuilder<T> extends Fake
    implements PostgrestFilterBuilder<T> {
  final T _value;

  FakePostgrestFilterBuilder(this._value);

  @override
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) {
    return Future<T>.value(_value).then(onValue, onError: onError);
  }
}

/// Hand-written fake SupabaseClient capturing RPC calls without external mocking packages
class FakeSupabaseClient extends Fake implements SupabaseClient {
  String? capturedFunction;
  Map<String, dynamic>? capturedParams;
  dynamic rpcResult = 'ok';

  @override
  PostgrestFilterBuilder<T> rpc<T>(
    String fn, {
    Map<String, dynamic>? params,
    dynamic get,
  }) {
    capturedFunction = fn;
    capturedParams = params;
    return FakePostgrestFilterBuilder<T>(rpcResult as T);
  }
}

void main() {
  group('DataService.redeemVoucher RPC Unit Tests', () {
    late FakeSupabaseClient fakeClient;
    late DataService dataService;

    setUp(() {
      fakeClient = FakeSupabaseClient();
      dataService = DataService(client: fakeClient);
    });

    test('invokes rpc("redeem_voucher") with uppercase trimmed p_code',
        () async {
      fakeClient.rpcResult = 'ok';

      final res = await dataService.redeemVoucher('  kt8x29q1  ');

      expect(fakeClient.capturedFunction, 'redeem_voucher');
      expect(fakeClient.capturedParams, {'p_code': 'KT8X29Q1'});
      expect(res, 'ok');
    });

    test('handles all specified RPC status codes', () async {
      const statusCodes = [
        'ok',
        'invalid',
        'not_your_promo',
        'already_redeemed',
        'expired',
        'limit_reached',
      ];

      for (final code in statusCodes) {
        fakeClient.rpcResult = code;
        final res = await dataService.redeemVoucher('DEMOCODE');
        expect(res, code);
      }
    });

    test('falls back to "invalid" if RPC result is null', () async {
      fakeClient.rpcResult = null;
      final res = await dataService.redeemVoucher('TEST1234');
      expect(res, 'invalid');
    });
  });
}
