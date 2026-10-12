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

  group('DataService Phase 7C Store QR & In-Store Redemption RPC Tests', () {
    late FakeSupabaseClient fakeClient;
    late DataService dataService;

    setUp(() {
      fakeClient = FakeSupabaseClient();
      dataService = DataService(client: fakeClient);
    });

    test('getStoreCode invokes rpc("get_store_code") with promo id', () async {
      fakeClient.rpcResult = {
        'code': 'KT8924B1',
        'qr_payload': '{"app":"market","code":"KT8924B1"}',
        'promo_id': 'promo-123',
      };

      final res = await dataService.getStoreCode('promo-123');

      expect(fakeClient.capturedFunction, 'get_store_code');
      expect(fakeClient.capturedParams, {'p_promo_id': 'promo-123'});
      expect(res['code'], 'KT8924B1');
    });

    test('resetStoreCode invokes rpc("reset_store_code") with promo id', () async {
      fakeClient.rpcResult = {
        'code': 'NEWCODE1',
        'qr_payload': '{"app":"market","code":"NEWCODE1"}',
        'promo_id': 'promo-123',
      };

      final res = await dataService.resetStoreCode('promo-123');

      expect(fakeClient.capturedFunction, 'reset_store_code');
      expect(fakeClient.capturedParams, {'p_promo_id': 'promo-123'});
      expect(res['code'], 'NEWCODE1');
    });

    test('redeemAtStore invokes rpc("redeem_at_store") with trimmed p_code', () async {
      fakeClient.rpcResult = 'ok';

      final res = await dataService.redeemAtStore('  KT8924B1  ');

      expect(fakeClient.capturedFunction, 'redeem_at_store');
      expect(fakeClient.capturedParams, {'p_code': 'KT8924B1'});
      expect(res, 'ok');
    });

    test('redeemAtStore handles all specified static reverse flow status codes', () async {
      const statusCodes = [
        'ok',
        'invalid',
        'already_redeemed',
        'expired',
        'limit_reached',
      ];

      for (final code in statusCodes) {
        fakeClient.rpcResult = code;
        final res = await dataService.redeemAtStore('KT8924B1');
        expect(res, code);
      }
    });
  });
}
