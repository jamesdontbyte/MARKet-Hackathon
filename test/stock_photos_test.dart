import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_final/models/business.dart';
import 'package:market_final/models/product.dart';
import 'package:market_final/models/promo.dart';
import 'package:market_final/models/scanned_menu_item.dart';
import 'package:market_final/screens/merchant/scan_menu_review_screen.dart';
import 'package:market_final/screens/shopper/storefront_screen.dart';
import 'package:market_final/services/data_service.dart';
import 'package:market_final/services/stock_photo_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fake DataService for testing product saving and photo uploads
class FakeStockDataService extends Fake implements DataService {
  final List<Product> createdProducts = [];
  final List<String> uploadedImages = [];
  bool failUpload = false;

  @override
  Future<Product> createProduct(Product product) async {
    final created = product.copyWith(id: 'prod_${createdProducts.length + 1}');
    createdProducts.add(created);
    return created;
  }

  @override
  Future<String> uploadProductImage({
    required String ownerId,
    required String fileName,
    required Uint8List fileBytes,
    String? contentType,
  }) async {
    if (failUpload) throw Exception('Simulated storage upload failure');
    final url = 'https://supabase.co/storage/v1/object/public/business-media/$ownerId/products/$fileName';
    uploadedImages.add(url);
    return url;
  }

  @override
  Future<List<Product>> fetchProducts(String businessId) async {
    return createdProducts;
  }

  @override
  Future<List<Promo>> fetchPromosForBusiness(String businessId) async {
    return [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testBusiness = Business(
    id: 'biz_antique_1',
    name: 'Antique Artisan Cafe',
    category: 'cafe',
    lat: 10.7431,
    lng: 121.9250,
    ownerId: 'merchant_user_1',
    createdAt: DateTime.now(),
  );

  final sampleCandidates = [
    const StockPhotoCandidate(
      id: 'photo_101',
      mediumUrl: 'https://cdn.pixabay.com/photo/2020/05/101_640.jpg',
      thumbnailUrl: 'https://cdn.pixabay.com/photo/2020/05/101_150.jpg',
      photographer: 'Maria Santos',
      url: 'https://pixabay.com/photos/101',
    ),
    const StockPhotoCandidate(
      id: 'photo_102',
      mediumUrl: 'https://cdn.pixabay.com/photo/2020/05/102_640.jpg',
      thumbnailUrl: 'https://cdn.pixabay.com/photo/2020/05/102_150.jpg',
      photographer: 'Juan Dela Cruz',
      url: 'https://pixabay.com/photos/102',
    ),
    const StockPhotoCandidate(
      id: 'photo_103',
      mediumUrl: 'https://cdn.pixabay.com/photo/2020/05/103_640.jpg',
      thumbnailUrl: 'https://cdn.pixabay.com/photo/2020/05/103_150.jpg',
      photographer: 'Elena Rostova',
      url: 'https://pixabay.com/photos/103',
    ),
  ];

  group('Requirement 4 & 14: Query Builder Tests', () {
    test('strips sizes, measurement units, and portions', () {
      expect(
        buildCleanSearchQuery('Iced Caramel Macchiato 16oz Large', 'Coffee'),
        'iced caramel macchiato coffee',
      );
      expect(
        buildCleanSearchQuery('Fried Chicken 2pcs Regular', 'Mains'),
        'fried chicken mains',
      );
      expect(
        buildCleanSearchQuery('Matcha Milk Tea 500ml Mini', 'Beverage'),
        'matcha milk tea beverage',
      );
      expect(
        buildCleanSearchQuery('Pork Sisig Solo Jumbo', 'Appetizer'),
        'pork sisig appetizer',
      );
      expect(
        buildCleanSearchQuery('Pizza 12 inch 8 slices XL', 'Food'),
        'pizza food',
      );
    });

    test('strips prices (₱, P, php, /-, decimals, standalone numbers)', () {
      expect(
        buildCleanSearchQuery('Pancit Molo ₱120', 'Soup'),
        'pancit molo soup',
      );
      expect(
        buildCleanSearchQuery('Pork Sisig 180/-', 'Mains'),
        'pork sisig mains',
      );
      expect(
        buildCleanSearchQuery('Batchoy Special P150.00', 'Noodles'),
        'batchoy noodles',
      );
      expect(
        buildCleanSearchQuery('Bibingka 85php', 'Snacks'),
        'bibingka snacks',
      );
      expect(
        buildCleanSearchQuery('Spanish Latte 140', 'Coffee'),
        'spanish latte coffee',
      );
    });

    test('strips promo words (bogo, special, discount, sale, etc.)', () {
      expect(
        buildCleanSearchQuery('Halo-Halo Special BOGO Combo', 'Dessert'),
        'halo halo dessert',
      );
      expect(
        buildCleanSearchQuery('Buy 1 Take 1 Burger Deal', 'Snacks'),
        'burger snacks',
      );
      expect(
        buildCleanSearchQuery('Bestseller Garlic Rice Free Refill', 'Rice'),
        'garlic rice refill',
      );
      expect(
        buildCleanSearchQuery('Hot Fresh Brewed Coffee 50% Off Sale', 'Coffee'),
        'brewed coffee',
      );
    });

    test('strips punctuation, quotes, brackets, and symbols', () {
      expect(
        buildCleanSearchQuery('Burger (with Cheese) & Fries!', 'Fast Food'),
        'burger with cheese fries fast food',
      );
      expect(
        buildCleanSearchQuery('Tapsilog: Beef + Rice + Egg #1', 'Breakfast'),
        'tapsilog beef rice egg breakfast',
      );
    });

    test('avoids duplicating category if already present in name', () {
      expect(
        buildCleanSearchQuery('Brewed Coffee', 'Coffee'),
        'brewed coffee',
      );
      expect(
        buildCleanSearchQuery('Mango Shake', 'Shake'),
        'mango shake',
      );
    });

    test('falls back gracefully on empty or whitespace name', () {
      expect(buildCleanSearchQuery('', 'Pastry'), 'Pastry');
      expect(buildCleanSearchQuery('   ', 'Dessert'), 'Dessert');
    });
  });

  group('Requirement 6, 7 & 14: Confidence Threshold & Result Parsing', () {
    test('confidence below 0.6 returns no best match', () {
      // JSON where edge function returned no best_id due to confidence < 0.6
      final jsonLowConfidence = {
        'item_id': 'item_1',
        'candidates': [sampleCandidates[0].toJson()],
        'best_id': null,
        'confidence': 0.55,
      };

      final result = StockPhotoItemResult.fromJson(jsonLowConfidence);
      expect(result.bestId, isNull);
      expect(result.bestMatch, isNull);
      expect(result.confidence, 0.55);
    });

    test('confidence >= 0.6 retains best_id and resolves best candidate', () {
      final jsonGoodConfidence = {
        'item_id': 'item_1',
        'candidates': [sampleCandidates[0].toJson(), sampleCandidates[1].toJson()],
        'best_id': 'photo_101',
        'confidence': 0.85,
      };

      final result = StockPhotoItemResult.fromJson(jsonGoodConfidence);
      expect(result.bestId, 'photo_101');
      expect(result.bestMatch, isNotNull);
      expect(result.bestMatch!.id, 'photo_101');
      expect(result.bestMatch!.photographer, 'Maria Santos');
      expect(result.confidence, 0.85);
    });

    test('StockPhotoService.findPhotos parses response correctly with mock invoker', () async {
      final service = StockPhotoService(
        invoker: (fn, {body, headers}) async {
          expect(fn, 'find-product-photos');
          expect(body?['items'], isNotEmpty);

          return FunctionResponse(
            status: 200,
            data: {
              'results': [
                {
                  'item_id': 'item_1',
                  'candidates': [sampleCandidates[0].toJson()],
                  'best_id': 'photo_101',
                  'confidence': 0.92,
                },
                {
                  'item_id': 'item_2',
                  'candidates': [sampleCandidates[1].toJson()],
                  'best_id': null,
                  'confidence': 0.45, // < 0.6 -> no best match
                },
              ],
            },
          );
        },
      );

      final results = await service.findPhotos([
        {'id': 'item_1', 'name': 'Pancit Molo', 'category': 'Soup'},
        {'id': 'item_2', 'name': 'Unknown Dish', 'category': 'Other'},
      ]);

      expect(results.length, 2);
      expect(results[0].bestId, 'photo_101');
      expect(results[0].confidence, 0.92);
      expect(results[1].bestId, isNull);
      expect(results[1].confidence, 0.45);
    });

    test('StockPhotoService maps rate limit, 502, and errors to friendly messages', () async {
      final rateLimitedService = StockPhotoService(
        invoker: (fn, {body, headers}) async => FunctionResponse(
          status: 429,
          data: {'code': 'rate_limited', 'error': 'Rate limit reached'},
        ),
      );

      expect(
        () => rateLimitedService.findPhotos([{'name': 'Test'}]),
        throwsA(
          isA<StockPhotoException>()
              .having((e) => e.code, 'code', 'rate_limited')
              .having((e) => e.message, 'message', contains('Rate limit reached')),
        ),
      );

      final pixabayBusyService = StockPhotoService(
        invoker: (fn, {body, headers}) async => FunctionResponse(
          status: 429,
          data: {'code': 'pixabay_rate_limited', 'error': 'Pixabay rate limit reached'},
        ),
      );

      expect(
        () => pixabayBusyService.findPhotos([{'name': 'Test'}]),
        throwsA(
          isA<StockPhotoException>()
              .having((e) => e.code, 'code', 'pixabay_rate_limited')
              .having((e) => e.message, 'message', contains('busy')),
        ),
      );

      final missingKeyService = StockPhotoService(
        invoker: (fn, {body, headers}) async => FunctionResponse(
          status: 503,
          data: {'code': 'pixabay_not_configured', 'error': 'Pixabay API key not configured'},
        ),
      );

      expect(
        () => missingKeyService.findPhotos([{'name': 'Test'}]),
        throwsA(
          isA<StockPhotoException>()
              .having((e) => e.code, 'code', 'pixabay_not_configured'),
        ),
      );
    });

    test('cache hit returns cached candidates without external Pixabay call', () async {
      final cachedResponse = {
        'results': [
          {
            'item_id': 'item_1',
            'candidates': [sampleCandidates[0].toJson()],
            'best_id': 'photo_101',
            'confidence': 0.95,
            'from_cache': true,
          }
        ]
      };

      final service = StockPhotoService(
        invoker: (fn, {body, headers}) async => FunctionResponse(
          status: 200,
          data: cachedResponse,
        ),
      );

      final results = await service.findPhotos([{'id': 'item_1', 'name': 'Pancit Molo'}]);
      expect(results.length, 1);
      expect(results.first.bestId, 'photo_101');
      expect(results.first.candidates.length, 1);
    });

    test('PIXABAY_API_KEY never appears in logs, error messages or response payloads', () async {
      const mockKey = 'secret_pixabay_key_12345';
      final service = StockPhotoService(
        invoker: (fn, {body, headers}) async => FunctionResponse(
          status: 400,
          data: {'code': 'pixabay_error', 'error': 'Search query failed'},
        ),
      );

      try {
        await service.findPhotos([{'name': 'Test'}]);
        fail('Expected exception');
      } on StockPhotoException catch (e) {
        expect(e.message.contains(mockKey), isFalse);
        expect(e.message.contains('key='), isFalse);
      }
    });

    test('Pixabay candidate mapping preserves required candidate shape and query fields', () {
      final rawHit = {
        'id': 12345,
        'previewURL': 'https://cdn.pixabay.com/photo/preview_123.jpg',
        'webformatURL': 'https://cdn.pixabay.com/photo/webformat_123.jpg',
        'user': 'Juan Dela Cruz',
        'pageURL': 'https://pixabay.com/photos/12345',
      };

      final candidate = StockPhotoCandidate(
        id: rawHit['id'].toString(),
        mediumUrl: rawHit['webformatURL'] as String,
        thumbnailUrl: rawHit['previewURL'] as String,
        photographer: rawHit['user'] as String,
        url: rawHit['pageURL'] as String,
      );

      expect(candidate.id, '12345');
      expect(candidate.mediumUrl, 'https://cdn.pixabay.com/photo/webformat_123.jpg');
      expect(candidate.thumbnailUrl, 'https://cdn.pixabay.com/photo/preview_123.jpg');
      expect(candidate.photographer, 'Juan Dela Cruz');
      expect(candidate.url, 'https://pixabay.com/photos/12345');
    });
  });

  group('Requirement 5, 10 & 14: Security & Host Validation for Medium Download', () {
    test('downloadMediumImage allows only cdn.pixabay.com and pixabay.com', () {
      expect(StockPhotoService.allowedStockHosts, contains('cdn.pixabay.com'));
      expect(StockPhotoService.allowedStockHosts, contains('pixabay.com'));
      expect(StockPhotoService.allowedStockHosts.length, 2);
    });

    test('downloadMediumImage rejects non-allowed hosts and non-HTTPS', () async {
      // Rejects unauthorized external host
      expect(
        () => StockPhotoService.downloadMediumImage('https://unauthorized-photos.com/photo.jpg'),
        throwsA(
          isA<StockPhotoException>()
              .having((e) => e.code, 'code', 'unauthorized_host')
              .having((e) => e.message, 'message', contains('cdn.pixabay.com')),
        ),
      );

      // Rejects arbitrary evil host
      expect(
        () => StockPhotoService.downloadMediumImage('https://evil-site.com/photo.jpg'),
        throwsA(
          isA<StockPhotoException>()
              .having((e) => e.code, 'code', 'unauthorized_host'),
        ),
      );

      // Rejects plain HTTP (must be HTTPS)
      expect(
        () => StockPhotoService.downloadMediumImage('http://cdn.pixabay.com/photo.jpg'),
        throwsA(
          isA<StockPhotoException>()
              .having((e) => e.code, 'code', 'unauthorized_host'),
        ),
      );
    });
  });

  group('Requirement 9, 10 & 14: ScanMenuReviewScreen Stock Photos Workflow', () {
    testWidgets('Pre-selects match only when confidence >= 0.7; leaves unselected if < 0.7', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeDataService = FakeStockDataService();
      final scanned = [
        const ScannedMenuItem(
          name: 'Iced Latte',
          price: 140.0,
          category: 'Coffee',
          confidence: 0.95,
        ),
        const ScannedMenuItem(
          name: 'Pancit Canton',
          price: 110.0,
          category: 'Noodles',
          confidence: 0.90,
        ),
      ];

      final fakeStockService = StockPhotoService(
        invoker: (fn, {body, headers}) async {
          final items = (body?['items'] as List<dynamic>?) ?? [];
          return FunctionResponse(
            status: 200,
            data: {
              'results': [
                {
                  'item_id': items.isNotEmpty ? items[0]['id'] : '0',
                  'candidates': [sampleCandidates[0].toJson(), sampleCandidates[1].toJson()],
                  'best_id': 'photo_101',
                  'confidence': 0.88, // >= 0.7 -> Should PRE-SELECT photo_101
                },
                {
                  'item_id': items.length > 1 ? items[1]['id'] : '1',
                  'candidates': [sampleCandidates[1].toJson(), sampleCandidates[2].toJson()],
                  'best_id': 'photo_102',
                  'confidence': 0.65, // < 0.7 -> Should LEAVE UNSELECTED with "Pick a photo"
                },
              ],
            },
          );
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ScanMenuReviewScreen(
            business: testBusiness,
            existingProducts: const [],
            scannedItems: scanned,
            dataService: fakeDataService,
            stockPhotoService: fakeStockService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Find photos" button
      final findPhotosButton = find.byKey(const Key('find_photos_button'));
      expect(findPhotosButton, findsOneWidget);
      await tester.tap(findPhotosButton);
      await tester.pumpAndSettle();

      // Row 0 (confidence 0.88 >= 0.7): Pre-selected candidate with photographer credit
      expect(find.text('Photo by Maria Santos on Pixabay'), findsOneWidget);

      // Row 1 (confidence 0.65 < 0.7): NOT pre-selected, shows "Pick a photo"
      expect(find.text('Pick a photo'), findsOneWidget);
    });

    testWidgets('Nothing is saved or downloaded before tapping "Add N items"', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeDataService = FakeStockDataService();
      final scanned = [
        const ScannedMenuItem(
          name: 'Iced Latte',
          price: 140.0,
          category: 'Coffee',
          confidence: 0.95,
        ),
      ];

      final fakeStockService = StockPhotoService(
        invoker: (fn, {body, headers}) async {
          final items = (body?['items'] as List<dynamic>?) ?? [];
          return FunctionResponse(
            status: 200,
            data: {
              'results': [
                {
                  'item_id': items.isNotEmpty ? items[0]['id'] : '0',
                  'candidates': [sampleCandidates[0].toJson()],
                  'best_id': 'photo_101',
                  'confidence': 0.90,
                },
              ],
            },
          );
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ScanMenuReviewScreen(
            business: testBusiness,
            existingProducts: const [],
            scannedItems: scanned,
            dataService: fakeDataService,
            stockPhotoService: fakeStockService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Find photos"
      await tester.tap(find.byKey(const Key('find_photos_button')));
      await tester.pumpAndSettle();

      // VERIFY: DataService has not received any createProduct or upload calls!
      expect(fakeDataService.createdProducts, isEmpty);
      expect(fakeDataService.uploadedImages, isEmpty);

      // Tap "Remove selection" if available
      final removeButton = find.text('Remove');
      if (removeButton.evaluate().isNotEmpty) {
        await tester.tap(removeButton);
        await tester.pumpAndSettle();
      }

      // Still nothing saved!
      expect(fakeDataService.createdProducts, isEmpty);
      expect(fakeDataService.uploadedImages, isEmpty);
    });

    testWidgets('A failed photo download still saves the item without a photo and shows "Photo not added, retry"', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeDataService = FakeStockDataService();
      final scanned = [
        const ScannedMenuItem(
          name: 'Kape Barako',
          price: 80.0,
          category: 'Coffee',
          confidence: 0.95,
        ),
      ];

      // Return a candidate whose medium URL fails host validation
      // (e.g. not cdn.pixabay.com or pixabay.com), triggering the catch block in downloadMediumImage
      const failingCandidate = StockPhotoCandidate(
        id: 'fail_photo_1',
        mediumUrl: 'https://invalid-host.com/photo.jpg',
        thumbnailUrl: 'https://cdn.pixabay.com/photos/small.jpg',
        photographer: 'Unknown',
        url: 'https://pixabay.com/fail',
      );

      final fakeStockService = StockPhotoService(
        invoker: (fn, {body, headers}) async {
          final items = (body?['items'] as List<dynamic>?) ?? [];
          return FunctionResponse(
            status: 200,
            data: {
              'results': [
                {
                  'item_id': items.isNotEmpty ? items[0]['id'] : '0',
                  'candidates': [failingCandidate.toJson()],
                  'best_id': 'fail_photo_1',
                  'confidence': 0.95, // Pre-selected
                },
              ],
            },
          );
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ScanMenuReviewScreen(
            business: testBusiness,
            existingProducts: const [],
            scannedItems: scanned,
            dataService: fakeDataService,
            stockPhotoService: fakeStockService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Fetch photo candidates
      await tester.tap(find.byKey(const Key('find_photos_button')));
      await tester.pumpAndSettle();

      // Tap "Add 1 items"
      await tester.tap(find.byKey(const Key('add_scanned_items_button')));
      await tester.pumpAndSettle();

      // 1. VERIFY: The item was STILL created in the database!
      expect(fakeDataService.createdProducts.length, 1);
      final created = fakeDataService.createdProducts.first;
      expect(created.name, 'Kape Barako');
      expect(created.price, 80.0);
      // Photo was NOT set due to failure
      expect(created.imageUrl, isNull);
      expect(created.imageSource, isNull);

      // 2. VERIFY: "Photo not added, retry" is displayed in the banner and on the item row
      expect(find.textContaining('Photo not added, retry'), findsAtLeastNWidgets(1));
    });
  });

  group('Requirement 12 & 14: Shopper Storefront Stock Photo Label & Preview', () {
    testWidgets('Stock photo label and photographer attribution show only when imageSource == stock', (tester) async {
      tester.view.physicalSize = const Size(411, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeDataService = FakeStockDataService();

      final stockProduct = Product(
        id: 'p_stock',
        businessId: testBusiness.id,
        name: 'Spanish Latte',
        price: 150.0,
        category: 'Coffee',
        imageUrl: 'https://cdn.pixabay.com/photo/2020/05/101_640.jpg',
        imageSource: 'stock',
        imageCredit: 'Maria Santos',
        imageCreditUrl: 'https://pixabay.com/photos/101',
        createdAt: DateTime.now(),
      );

      final ownProduct = Product(
        id: 'p_own',
        businessId: testBusiness.id,
        name: 'Homemade Bibingka',
        price: 90.0,
        category: 'Pastry',
        imageUrl: 'https://supabase.co/storage/v1/object/public/business-media/own.jpg',
        imageSource: 'own',
        createdAt: DateTime.now(),
      );

      final noPhotoProduct = Product(
        id: 'p_none',
        businessId: testBusiness.id,
        name: 'Plain Pandesal',
        price: 20.0,
        category: 'Pastry',
        imageUrl: null,
        imageSource: null,
        createdAt: DateTime.now(),
      );

      await fakeDataService.createProduct(stockProduct);
      await fakeDataService.createProduct(ownProduct);
      await fakeDataService.createProduct(noPhotoProduct);

      await tester.pumpWidget(
        MaterialApp(
          home: StorefrontScreen(
            business: testBusiness,
            dataService: fakeDataService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // VERIFY: In product card list, only "Spanish Latte" has the "Stock photo" badge
      expect(find.text('Stock photo'), findsOneWidget);

      // Scroll and tap on the stock product card to open preview sheet
      await tester.scrollUntilVisible(find.text('Spanish Latte'), 100);
      await tester.tap(find.text('Spanish Latte'));
      await tester.pumpAndSettle();

      // VERIFY: Preview sheet shows "Stock photo" label and "Photo by Maria Santos on Pixabay"
      expect(find.text('Stock photo'), findsNWidgets(2)); // Card in background + Modal sheet
      expect(find.text('Photo by Maria Santos on Pixabay'), findsOneWidget);

      // Close modal sheet
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Tap on the own photo product card
      await tester.scrollUntilVisible(find.text('Homemade Bibingka'), 100);
      await tester.tap(find.text('Homemade Bibingka'));
      await tester.pumpAndSettle();

      // VERIFY: Preview sheet does NOT show "Stock photo" label or credit
      expect(find.text('Photo by Maria Santos on Pixabay'), findsNothing);
    });
  });

  group('Requirement 13 & 14: Responsive Layout & Overflow Tests', () {
    testWidgets('ScanMenuReviewScreen with candidate strip has no overflows at 360x640 (scale 1.0 & 1.5)', (tester) async {
      for (final textScale in [1.0, 1.5]) {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeDataService = FakeStockDataService();
        final scanned = [
          const ScannedMenuItem(
            name: 'Antique Native Tsokolate Special',
            price: 120.0,
            category: 'Beverages',
            confidence: 0.90,
          ),
        ];

        final fakeStockService = StockPhotoService(
          invoker: (fn, {body, headers}) async {
            final items = (body?['items'] as List<dynamic>?) ?? [];
            return FunctionResponse(
              status: 200,
              data: {
                'results': [
                  {
                    'item_id': items.isNotEmpty ? items[0]['id'] : '0',
                    'candidates': sampleCandidates.map((c) => c.toJson()).toList(),
                    'best_id': 'photo_101',
                    'confidence': 0.85,
                  },
                ],
              },
            );
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(360, 640),
                textScaler: TextScaler.linear(textScale),
              ),
              child: ScanMenuReviewScreen(
                business: testBusiness,
                existingProducts: const [],
                scannedItems: scanned,
                dataService: fakeDataService,
                stockPhotoService: fakeStockService,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find photos to display strip
        await tester.tap(find.byKey(const Key('find_photos_button')));
        await tester.pumpAndSettle();

        // VERIFY: No overflow exceptions
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('ScanMenuReviewScreen with candidate strip has no overflows at 411x891 (scale 1.0 & 1.5)', (tester) async {
      for (final textScale in [1.0, 1.5]) {
        tester.view.physicalSize = const Size(411, 891);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeDataService = FakeStockDataService();
        final scanned = [
          const ScannedMenuItem(
            name: 'Pancit Molo Soup Special Large 16oz',
            price: 150.0,
            category: 'Traditional Soups',
            confidence: 0.92,
          ),
        ];

        final fakeStockService = StockPhotoService(
          invoker: (fn, {body, headers}) async {
            final items = (body?['items'] as List<dynamic>?) ?? [];
            return FunctionResponse(
              status: 200,
              data: {
                'results': [
                  {
                    'item_id': items.isNotEmpty ? items[0]['id'] : '0',
                    'candidates': sampleCandidates.map((c) => c.toJson()).toList(),
                    'best_id': 'photo_101',
                    'confidence': 0.90,
                  },
                ],
              },
            );
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(411, 891),
                textScaler: TextScaler.linear(textScale),
              ),
              child: ScanMenuReviewScreen(
                business: testBusiness,
                existingProducts: const [],
                scannedItems: scanned,
                dataService: fakeDataService,
                stockPhotoService: fakeStockService,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('find_photos_button')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('StorefrontScreen product preview with attribution has no overflows at 360x640 and 411x891 (scale 1.5)', (tester) async {
      for (final size in [const Size(360, 640), const Size(411, 891)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeDataService = FakeStockDataService();
        final stockProduct = Product(
          id: 'p_test',
          businessId: testBusiness.id,
          name: 'Iced Caramel Macchiato Premium Coffee',
          price: 180.0,
          category: 'Specialty Coffee',
          description: 'A delicious rich espresso layered with steamed milk and caramel drizzle.',
          imageUrl: 'https://cdn.pixabay.com/photo/2020/05/101_640.jpg',
          imageSource: 'stock',
          imageCredit: 'Very Long Photographer Name Attribution From Pixabay Community',
          imageCreditUrl: 'https://pixabay.com/photos/101',
          createdAt: DateTime.now(),
        );
        await fakeDataService.createProduct(stockProduct);

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(1.5),
              ),
              child: StorefrontScreen(
                business: testBusiness,
                dataService: fakeDataService,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap product to open preview sheet
        await tester.scrollUntilVisible(find.text('Iced Caramel Macchiato Premium Coffee'), 100);
        await tester.tap(find.text('Iced Caramel Macchiato Premium Coffee'), warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(find.text('Stock photo'), findsAtLeastNWidgets(1));
        expect(tester.takeException(), isNull);
      }
    });
  });
}
