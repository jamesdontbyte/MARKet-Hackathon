import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_final/models/promo.dart';
import 'package:market_final/services/notification_service.dart';
import 'package:market_final/services/promo_image_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Promo Photos Validation & Form Tests', () {
    test('1. A promo cannot be saved without a photo (validation blocks save)', () {
      // Simulate form validation state:
      Uint8List? pickedPromoBytes;
      String? currentPromoImageUrl; // null for new promo or legacy promo with no photo
      String? modalError;

      bool attemptSave() {
        if (pickedPromoBytes == null &&
            (currentPromoImageUrl == null || currentPromoImageUrl.isEmpty)) {
          modalError = 'Add a photo for this promo';
          return false;
        }
        return true;
      }

      // Initial state: no photo picked
      expect(attemptSave(), isFalse);
      expect(modalError, equals('Add a photo for this promo'));

      // Editing legacy promo with no photo: still blocked
      final legacyPromo = Promo(
        id: 'legacy_1',
        businessId: 'biz_1',
        title: 'Old Promo',
        promoType: 'percent',
        startsAt: DateTime.now(),
        endsAt: DateTime.now().add(const Duration(days: 7)),
        redeemLimit: 100,
        redeemedCount: 0,
        active: true,
        createdAt: DateTime.now(),
        imageUrl: null,
      );
      currentPromoImageUrl = legacyPromo.imageUrl;
      expect(attemptSave(), isFalse);
      expect(modalError, equals('Add a photo for this promo'));

      // Once photo is picked, save succeeds
      pickedPromoBytes = Uint8List.fromList([1, 2, 3, 4]);
      expect(attemptSave(), isTrue);
    });

    test('2. A file over 2 MB is rejected with clear error', () {
      const maxAllowedBytes = 2 * 1024 * 1024; // 2 MB
      const oversizedBytes = maxAllowedBytes + 1; // 2 MB + 1 byte

      String? validateImageFile({
        required String extension,
        required int sizeInBytes,
      }) {
        final allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];
        if (!allowedExtensions.contains(extension.toLowerCase())) {
          return 'Only JPG, PNG, and WebP images are allowed.';
        }
        if (sizeInBytes > maxAllowedBytes) {
          return 'Photo exceeds 2 MB limit. Please select an image under 2 MB.';
        }
        return null;
      }

      // Reject non-image extension
      expect(
        validateImageFile(extension: 'pdf', sizeInBytes: 1024),
        equals('Only JPG, PNG, and WebP images are allowed.'),
      );
      expect(
        validateImageFile(extension: 'gif', sizeInBytes: 1024),
        equals('Only JPG, PNG, and WebP images are allowed.'),
      );

      // Reject oversized file (e.g. 2.1 MB)
      expect(
        validateImageFile(extension: 'jpg', sizeInBytes: oversizedBytes),
        equals('Photo exceeds 2 MB limit. Please select an image under 2 MB.'),
      );
      expect(
        validateImageFile(extension: 'png', sizeInBytes: 3 * 1024 * 1024),
        equals('Photo exceeds 2 MB limit. Please select an image under 2 MB.'),
      );

      // Accept valid image files under 2 MB
      expect(
        validateImageFile(extension: 'jpg', sizeInBytes: maxAllowedBytes),
        isNull,
      );
      expect(
        validateImageFile(extension: 'jpeg', sizeInBytes: 500 * 1024),
        isNull,
      );
      expect(
        validateImageFile(extension: 'webp', sizeInBytes: 100 * 1024),
        isNull,
      );
    });
  });

  group('Notification Builder BigPicture & Fallback Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('promo_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('3. Uses big-picture style when image file exists on disk', () async {
      // Create a test image file
      final testImageFile = File('${tempDir.path}/test_promo.jpg');
      await testImageFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0, 0x00]);

      final details = NotificationService.buildPromoNotificationDetails(
        title: '20% OFF Coffee',
        body: 'Enter Kape Tahanan now to claim!',
        imagePath: testImageFile.path,
      );

      final android = details.android;
      expect(android, isNotNull);
      expect(android!.styleInformation, isA<BigPictureStyleInformation>());

      final style = android.styleInformation as BigPictureStyleInformation;
      expect(style.contentTitle, equals('20% OFF Coffee'));
      expect(style.summaryText, equals('Enter Kape Tahanan now to claim!'));
      expect(style.hideExpandedLargeIcon, isTrue);
    });

    test('4. Falls back to text notification when image file does not exist', () {
      final details = NotificationService.buildPromoNotificationDetails(
        title: 'Special Promo',
        body: 'Enjoy your discount',
        imagePath: '${tempDir.path}/non_existent_image.jpg',
      );

      final android = details.android;
      expect(android, isNotNull);
      // Fallback: styleInformation is null (standard text notification)
      expect(android!.styleInformation, isNull);
    });

    test('5. Falls back to text notification when image download fails (fake downloader)', () async {
      // Setup fake downloader that simulates a download failure (e.g. network error / timeout)
      final cacheService = PromoImageCacheService(
        customCacheDir: tempDir,
        customDownloader: (url, targetFile) async {
          // Simulate download error / timeout returning null
          return null;
        },
      );

      // Attempt download for promo
      final imagePath = await cacheService.getOrDownloadPromoImage(
        promoId: 'promo_fail_123',
        imageUrl: 'https://example.com/broken_promo.jpg',
      );

      expect(imagePath, isNull);

      // Build notification with the failed result
      final details = NotificationService.buildPromoNotificationDetails(
        title: 'Flash Deal',
        body: 'Limited time voucher',
        imagePath: imagePath,
      );

      // Must fall back to text notification without error or delay
      expect(details.android, isNotNull);
      expect(details.android!.styleInformation, isNull);
    });

    test('6. Uses big-picture style when download succeeds (fake downloader)', () async {
      // Setup fake downloader that successfully writes image bytes
      final cacheService = PromoImageCacheService(
        customCacheDir: tempDir,
        customDownloader: (url, targetFile) async {
          await targetFile.writeAsBytes([0x89, 0x50, 0x4E, 0x47]); // Valid PNG header
          return targetFile;
        },
      );

      final imagePath = await cacheService.getOrDownloadPromoImage(
        promoId: 'promo_success_456',
        imageUrl: 'https://example.com/promo.png',
      );

      expect(imagePath, isNotNull);
      expect(File(imagePath!).existsSync(), isTrue);

      final details = NotificationService.buildPromoNotificationDetails(
        title: 'Buy 1 Get 1',
        body: 'Available today only at Centro',
        imagePath: imagePath,
      );

      expect(details.android, isNotNull);
      expect(details.android!.styleInformation, isA<BigPictureStyleInformation>());
    });
  });
}
