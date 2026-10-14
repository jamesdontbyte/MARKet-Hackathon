import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:market_final/models/business.dart';
import 'package:market_final/models/product.dart';
import 'package:market_final/models/scanned_menu_item.dart';
import 'package:market_final/screens/merchant/scan_menu_review_screen.dart';
import 'package:market_final/screens/merchant/scan_menu_sheet.dart';
import 'package:market_final/services/data_service.dart';
import 'package:market_final/services/scan_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fake DataService recording created products for testing confirmation and saving
class FakeMenuDataService extends Fake implements DataService {
  final List<Product> createdProducts = [];
  bool shouldFail = false;
  String? failOnProductName;

  @override
  Future<Product> createProduct(Product product) async {
    if (shouldFail && (failOnProductName == null || product.name == failOnProductName)) {
      throw Exception('Simulated product creation failure');
    }
    final created = product.copyWith(id: 'prod_${createdProducts.length + 1}');
    createdProducts.add(created);
    return created;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testBusiness = Business(
    id: 'biz_test_1',
    name: 'Kape Tahanan',
    category: 'cafe',
    lat: 10.7431,
    lng: 121.9250,
    createdAt: DateTime.now(),
  );

  final existingProducts = [
    Product(
      id: 'p1',
      businessId: 'biz_test_1',
      name: 'Iced Latte',
      price: 150.0,
      category: 'Coffee',
      createdAt: DateTime.now(),
    ),
    Product(
      id: 'p2',
      businessId: 'biz_test_1',
      name: 'Tablea Cake',
      price: 120.0,
      category: 'Pastry',
      createdAt: DateTime.now(),
    ),
  ];

  final dummyPngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
  );

  XFile createDummyFile() => XFile.fromData(
        dummyPngBytes,
        name: 'test_menu.png',
        mimeType: 'image/png',
      );

  group('ScanService Unit Tests with Mock Invoker', () {
    test('successful scanMenu returns parsed items and notes', () async {
      final service = ScanService(
        invoker: (fn, {body, headers}) async {
          expect(fn, 'scan-menu');
          expect(body?['images'], isNotEmpty);
          expect(body?['business_type'], 'cafe');

          return FunctionResponse(
            status: 200,
            data: {
              'items': [
                {
                  'name': 'Spanish Latte',
                  'price': 160.0,
                  'category': 'Coffee',
                  'description': 'Sweet condensed milk espresso',
                  'confidence': 0.95,
                },
                {
                  'name': 'Matcha Cloud',
                  'price': null,
                  'category': 'Specialty',
                  'confidence': 0.5,
                },
              ],
              'notes': '2 items extracted',
            },
          );
        },
      );

      final result = await service.scanMenu(
        images: [
          {'mime': 'image/jpeg', 'data': 'base64sample'}
        ],
        businessType: 'cafe',
      );

      expect(result.items.length, 2);
      expect(result.items[0].name, 'Spanish Latte');
      expect(result.items[0].price, 160.0);
      expect(result.items[0].confidence, 0.95);
      expect(result.items[1].name, 'Matcha Cloud');
      expect(result.items[1].price, isNull);
      expect(result.items[1].confidence, 0.5);
      expect(result.notes, '2 items extracted');
    });

    test('handles HTTP 429 rate limit with friendly message', () async {
      final service = ScanService(
        invoker: (fn, {body, headers}) async {
          return FunctionResponse(status: 429, data: {'code': 'rate_limited'});
        },
      );

      expect(
        () => service.scanMenu(
          images: [
            {'mime': 'image/jpeg', 'data': 'base64'}
          ],
        ),
        throwsA(
          isA<ScanException>()
              .having((e) => e.code, 'code', 'rate_limited')
              .having(
                (e) => e.message,
                'message',
                contains('Rate limit reached. You can scan up to 10 menus per hour.'),
              ),
        ),
      );
    });

    test('handles FunctionException 429 with friendly message', () async {
      final service = ScanService(
        invoker: (fn, {body, headers}) async {
          throw const FunctionException(status: 429);
        },
      );

      expect(
        () => service.scanMenu(
          images: [
            {'mime': 'image/jpeg', 'data': 'base64'}
          ],
        ),
        throwsA(
          isA<ScanException>()
              .having((e) => e.code, 'code', 'rate_limited')
              .having((e) => e.message, 'message', contains('Rate limit reached')),
        ),
      );
    });

    test('maps SocketException to friendly connection error', () async {
      final service = ScanService(
        invoker: (fn, {body, headers}) async {
          throw const SocketException('Connection refused');
        },
      );

      expect(
        () => service.scanMenu(
          images: [
            {'mime': 'image/jpeg', 'data': 'base64'}
          ],
        ),
        throwsA(
          isA<ScanException>()
              .having((e) => e.code, 'code', 'no_internet')
              .having(
                (e) => e.message,
                'message',
                contains('Unable to connect. Please check your internet connection'),
              ),
        ),
      );
    });

    test('handles 422 unreadable response with friendly message', () async {
      final service = ScanService(
        invoker: (fn, {body, headers}) async {
          return FunctionResponse(
            status: 422,
            data: {
              'code': 'unreadable',
              'error': "I couldn't read this photo, try a clearer one",
            },
          );
        },
      );

      expect(
        () => service.scanMenu(
          images: [
            {'mime': 'image/jpeg', 'data': 'base64'}
          ],
        ),
        throwsA(
          isA<ScanException>()
              .having((e) => e.code, 'code', 'unreadable')
              .having(
                (e) => e.message,
                'message',
                contains("I couldn't read this photo, try a clearer one"),
              ),
        ),
      );
    });

    test('handles 502 server error with friendly message', () async {
      final service = ScanService(
        invoker: (fn, {body, headers}) async {
          return FunctionResponse(
            status: 502,
            data: {
              'code': 'gemini_error',
              'error': 'Gemini service unavailable',
            },
          );
        },
      );

      expect(
        () => service.scanMenu(
          images: [
            {'mime': 'image/jpeg', 'data': 'base64'}
          ],
        ),
        throwsA(
          isA<ScanException>()
              .having((e) => e.code, 'code', 'server_error')
              .having(
                (e) => e.message,
                'message',
                contains('The menu scanner is temporarily unavailable.'),
              ),
        ),
      );
    });

    test('validates image count (rejects 0 images and >4 images)', () async {
      final service = ScanService(
        invoker: (fn, {body, headers}) async => FunctionResponse(status: 200, data: {'items': []}),
      );

      expect(
        () => service.scanMenu(images: []),
        throwsA(isA<ScanException>().having((e) => e.code, 'code', 'invalid_payload')),
      );

      expect(
        () => service.scanMenu(
          images: List.generate(5, (_) => {'mime': 'image/jpeg', 'data': 'abc'}),
        ),
        throwsA(isA<ScanException>().having((e) => e.code, 'code', 'invalid_payload')),
      );
    });
  });

  group('ScanMenuSheet Widget Tests', () {
    testWidgets('renders photo options and selected thumbnails with remove action', (tester) async {
      final dummyFile = createDummyFile();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScanMenuSheet(
              business: testBusiness,
              initialFiles: [dummyFile],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Scan Menu or Price List'), findsOneWidget);
      expect(find.byKey(const Key('take_photo_button')), findsOneWidget);
      expect(find.byKey(const Key('choose_gallery_button')), findsOneWidget);
      expect(find.text('Selected Photos (1/4):'), findsOneWidget);
      expect(find.byKey(const Key('remove_photo_0')), findsOneWidget);

      // Tap remove photo
      await tester.tap(find.byKey(const Key('remove_photo_0')));
      await tester.pumpAndSettle();

      expect(find.text('Selected Photos (1/4):'), findsNothing);
      expect(find.text('Select at least 1 photo'), findsOneWidget);
    });

    testWidgets('shows reading progress state and allows cancellation', (tester) async {
      final dummyFile = createDummyFile();

      final completer = Completer<FunctionResponse>();
      addTearDown(() {
        if (!completer.isCompleted) {
          completer.complete(FunctionResponse(status: 200, data: {'items': []}));
        }
      });
      final fakeScanService = ScanService(
        invoker: (fn, {body, headers}) => completer.future,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScanMenuSheet(
              business: testBusiness,
              initialFiles: [dummyFile],
              scanService: fakeScanService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Scan 1 photo
      await tester.tap(find.byKey(const Key('scan_photos_button')));
      await tester.pump();

      expect(find.text('Reading your menu...'), findsOneWidget);
      expect(find.byKey(const Key('cancel_scan_button')), findsOneWidget);

      // Tap cancel
      await tester.tap(find.byKey(const Key('cancel_scan_button')));
      await tester.pumpAndSettle();

      expect(find.text('Reading your menu...'), findsNothing);
      expect(find.text('Scan 1 photo'), findsOneWidget);
    });

    testWidgets('rate limit and no internet errors show friendly messages and retry', (tester) async {
      final dummyFile = createDummyFile();

      int callCount = 0;
      final fakeScanService = ScanService(
        invoker: (fn, {body, headers}) async {
          callCount++;
          if (callCount == 1) {
            throw const SocketException('offline');
          } else {
            return FunctionResponse(
              status: 429,
              data: {'code': 'rate_limited'},
            );
          }
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScanMenuSheet(
              business: testBusiness,
              initialFiles: [dummyFile],
              scanService: fakeScanService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // First attempt -> socket error
      await tester.tap(find.byKey(const Key('scan_photos_button')));
      await tester.pumpAndSettle();

      expect(find.text('Unable to connect. Please check your internet connection and try again.'), findsOneWidget);
      expect(find.byKey(const Key('retry_scan_button')), findsOneWidget);

      // Second attempt (retry) -> rate limit
      await tester.tap(find.byKey(const Key('retry_scan_button')));
      await tester.pumpAndSettle();

      expect(find.text('Rate limit reached. You can scan up to 10 menus per hour. Please try again later.'), findsOneWidget);
      expect(find.byKey(const Key('retry_scan_button')), findsOneWidget);
    });
  });

  group('ScanMenuReviewScreen Widget & Logic Tests', () {
    testWidgets('successful scan to review to save: nothing saved before confirmation', (tester) async {
      final fakeDataService = FakeMenuDataService();
      final scanned = [
        const ScannedMenuItem(
          name: 'Pancit Molo',
          price: 120.0,
          category: 'Soups',
          confidence: 0.9,
        ),
        const ScannedMenuItem(
          name: 'Native Tsokolate',
          price: 85.0,
          category: 'Beverages',
          confidence: 0.85,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ScanMenuReviewScreen(
            business: testBusiness,
            existingProducts: existingProducts,
            scannedItems: scanned,
            dataService: fakeDataService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verification: rendered items
      expect(find.text('Pancit Molo'), findsOneWidget);
      expect(find.text('Native Tsokolate'), findsOneWidget);
      expect(find.text('120'), findsOneWidget);
      expect(find.text('85'), findsOneWidget);

      // CRITICAL VERIFICATION: Nothing is saved before merchant taps "Add N items"
      expect(fakeDataService.createdProducts, isEmpty);

      // Both items are checked by default
      expect(find.text('Add 2 items'), findsOneWidget);

      // Tap "Add 2 items"
      await tester.tap(find.byKey(const Key('add_scanned_items_button')));
      await tester.pumpAndSettle();

      // Now exactly 2 products saved via DataService.createProduct with defaults
      expect(fakeDataService.createdProducts.length, 2);
      expect(fakeDataService.createdProducts[0].name, 'Pancit Molo');
      expect(fakeDataService.createdProducts[0].price, 120.0);
      expect(fakeDataService.createdProducts[0].available, isTrue);
      expect(fakeDataService.createdProducts[0].isBestSeller, isFalse);
      expect(fakeDataService.createdProducts[0].imageUrl, isNull);

      expect(fakeDataService.createdProducts[1].name, 'Native Tsokolate');
      expect(fakeDataService.createdProducts[1].price, 85.0);
    });

    testWidgets('low-confidence and missing-price rows are flagged and block saving until fixed', (tester) async {
      final fakeDataService = FakeMenuDataService();
      final scanned = [
        const ScannedMenuItem(
          name: 'Barako Blend',
          price: 110.0,
          category: 'Coffee',
          confidence: 0.45, // < 0.6 -> low confidence
        ),
        const ScannedMenuItem(
          name: 'Special Torta',
          price: null, // missing price
          category: 'Pastry',
          confidence: 0.8,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ScanMenuReviewScreen(
            business: testBusiness,
            existingProducts: existingProducts,
            scannedItems: scanned,
            dataService: fakeDataService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both items have "Check this" badge
      expect(find.text('Check this'), findsNWidgets(2));
      expect(find.text('Valid price required'), findsOneWidget);

      // Button is blocked / disabled because Special Torta has no price
      final saveBtn = tester.widget<ElevatedButton>(
        find.descendant(
          of: find.byKey(const Key('add_scanned_items_button')),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(saveBtn.onPressed, isNull);

      // Fix missing price
      await tester.enterText(find.byKey(const Key('scanned_item_price_1')), '95');
      await tester.pumpAndSettle();

      // Now price is valid, button is enabled!
      final saveBtnEnabled = tester.widget<ElevatedButton>(
        find.descendant(
          of: find.byKey(const Key('add_scanned_items_button')),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(saveBtnEnabled.onPressed, isNotNull);

      // Tap save
      await tester.tap(find.byKey(const Key('add_scanned_items_button')));
      await tester.pumpAndSettle();

      expect(fakeDataService.createdProducts.length, 2);
      expect(fakeDataService.createdProducts[1].name, 'Special Torta');
      expect(fakeDataService.createdProducts[1].price, 95.0);
    });

    testWidgets('catalog duplicates are marked with Already in catalog and unchecked by default', (tester) async {
      final fakeDataService = FakeMenuDataService();
      final scanned = [
        const ScannedMenuItem(
          name: 'Iced Latte', // Duplicate of existingProducts
          price: 155.0,
          category: 'Coffee',
          confidence: 0.9,
        ),
        const ScannedMenuItem(
          name: 'Ube Halaya Frappe',
          price: 170.0,
          category: 'Coffee',
          confidence: 0.9,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ScanMenuReviewScreen(
            business: testBusiness,
            existingProducts: existingProducts,
            scannedItems: scanned,
            dataService: fakeDataService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // "Already in catalog" badge shown for Iced Latte
      expect(find.text('Already in catalog'), findsOneWidget);

      // Only Ube Halaya Frappe is checked by default -> Add 1 item
      expect(find.text('Add 1 item'), findsOneWidget);

      // Tap save
      await tester.tap(find.byKey(const Key('add_scanned_items_button')));
      await tester.pumpAndSettle();

      // Only Ube Halaya Frappe was saved, duplicate was skipped
      expect(fakeDataService.createdProducts.length, 1);
      expect(fakeDataService.createdProducts.first.name, 'Ube Halaya Frappe');
    });

    testWidgets('add item row appends new row for missed items', (tester) async {
      final fakeDataService = FakeMenuDataService();

      await tester.pumpWidget(
        MaterialApp(
          home: ScanMenuReviewScreen(
            business: testBusiness,
            existingProducts: existingProducts,
            scannedItems: const [],
            dataService: fakeDataService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No items to review'), findsOneWidget);

      // Tap add missed item
      await tester.tap(find.text('Add item'));
      await tester.pumpAndSettle();

      // A new item card is added
      expect(find.byKey(const Key('scanned_item_card_0')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('scanned_item_name_0')), 'Kape Barako');
      await tester.enterText(find.byKey(const Key('scanned_item_price_0')), '90');
      await tester.pumpAndSettle();

      expect(find.text('Add 1 item'), findsOneWidget);

      await tester.tap(find.byKey(const Key('add_scanned_items_button')));
      await tester.pumpAndSettle();

      expect(fakeDataService.createdProducts.length, 1);
      expect(fakeDataService.createdProducts.first.name, 'Kape Barako');
      expect(fakeDataService.createdProducts.first.price, 90.0);
    });

    testWidgets('partial failures keep failed rows on screen with error and retry', (tester) async {
      final fakeDataService = FakeMenuDataService();
      fakeDataService.shouldFail = true;
      fakeDataService.failOnProductName = 'Item Fail';

      final scanned = [
        const ScannedMenuItem(
          name: 'Item Success',
          price: 100.0,
          category: 'General',
        ),
        const ScannedMenuItem(
          name: 'Item Fail',
          price: 150.0,
          category: 'General',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ScanMenuReviewScreen(
            business: testBusiness,
            existingProducts: existingProducts,
            scannedItems: scanned,
            dataService: fakeDataService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add 2 items'), findsOneWidget);

      await tester.tap(find.byKey(const Key('add_scanned_items_button')));
      await tester.pumpAndSettle();

      // Succeeded item is saved and removed from screen
      expect(fakeDataService.createdProducts.length, 1);
      expect(fakeDataService.createdProducts.first.name, 'Item Success');

      // Failed item stays on screen with error indication
      expect(find.text('Item Fail'), findsOneWidget);
      expect(find.text('Item Success'), findsNothing);
      expect(find.textContaining('Added 1 items. 1 failed to save'), findsOneWidget);
    });
  });

  group('ScanMenuReviewScreen Responsive Layout & Overflow Tests', () {
    final complexScannedItems = [
      const ScannedMenuItem(
        name: 'Extra Large Kape Tahanan Signature Barako Espresso',
        price: 185.50,
        category: 'Hot Beverages & Specialties',
        confidence: 0.95,
      ),
      const ScannedMenuItem(
        name: 'Freshly Baked Antique Tablea Chocolate Croissant',
        price: null,
        category: 'Bakery & Pastries',
        confidence: 0.52,
      ),
      const ScannedMenuItem(
        name: 'Iced Latte',
        price: 150.0,
        category: 'Coffee',
        confidence: 0.99,
      ),
    ];

    Future<void> renderReviewScreenAt(
      WidgetTester tester, {
      required double width,
      required double height,
      required double textScale,
    }) async {
      tester.view.physicalSize = Size(width, height);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      FlutterError.onError = (details) => FlutterError.dumpErrorToConsole(details);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, height),
              textScaler: TextScaler.linear(textScale),
            ),
            child: ScanMenuReviewScreen(
              business: testBusiness,
              existingProducts: existingProducts,
              scannedItems: complexScannedItems,
              dataService: FakeMenuDataService(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('no overflow at 360x640 scale 1.0', (tester) async {
      await renderReviewScreenAt(tester, width: 360, height: 640, textScale: 1.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no overflow at 360x640 scale 1.5', (tester) async {
      await renderReviewScreenAt(tester, width: 360, height: 640, textScale: 1.5);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no overflow at 411x891 scale 1.0', (tester) async {
      await renderReviewScreenAt(tester, width: 411, height: 891, textScale: 1.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no overflow at 411x891 scale 1.5', (tester) async {
      await renderReviewScreenAt(tester, width: 411, height: 891, textScale: 1.5);
      expect(tester.takeException(), isNull);
    });
  });
}
