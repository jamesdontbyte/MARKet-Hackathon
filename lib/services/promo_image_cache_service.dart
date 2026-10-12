import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Function signature for image downloader to allow fake/mock injection in tests
typedef ImageDownloader = Future<File?> Function(String url, File targetFile);

/// PromoImageCacheService manages downloading, disk caching, pre-downloading,
/// and stale image pruning for promo photos attached to notifications.
class PromoImageCacheService {
  static final PromoImageCacheService instance = PromoImageCacheService();

  PromoImageCacheService({this.customDownloader, Directory? customCacheDir})
      : _cacheDir = customCacheDir;

  final ImageDownloader? customDownloader;
  Directory? _cacheDir;

  /// Max image size in bytes: 2 MB
  static const int maxFileSizeBytes = 2 * 1024 * 1024;

  /// Download timeout: 5 seconds
  static const Duration downloadTimeout = Duration(seconds: 5);

  Future<Directory> getCacheDirectory() async {
    if (_cacheDir != null) return _cacheDir!;
    final temp = await getTemporaryDirectory();
    final promoCache = Directory('${temp.path}/promo_photos');
    if (!await promoCache.exists()) {
      await promoCache.create(recursive: true);
    }
    _cacheDir = promoCache;
    return promoCache;
  }

  /// Returns the designated file location for a given promoId
  Future<File> getFileForPromo(String promoId) async {
    final dir = await getCacheDirectory();
    final sanitized = promoId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return File('${dir.path}/promo_$sanitized.jpg');
  }

  /// Checks if photo for promoId is already cached on disk
  Future<String?> getCachedImagePath(String promoId) async {
    try {
      final file = await getFileForPromo(promoId);
      if (await file.exists() && await file.length() > 0) {
        return file.path;
      }
    } catch (_) {}
    return null;
  }

  /// Downloads or retrieves cached image file for a promo.
  /// Enforces 5s timeout, 2MB size cap, and never delays or skips an alert.
  Future<String?> getOrDownloadPromoImage({
    required String promoId,
    String? imageUrl,
  }) async {
    if (imageUrl == null || imageUrl.trim().isEmpty) {
      return null;
    }

    try {
      // 1. Check local cache first
      final existingPath = await getCachedImagePath(promoId);
      if (existingPath != null) {
        return existingPath;
      }

      final targetFile = await getFileForPromo(promoId);

      // If custom downloader provided (e.g. for unit tests), use it
      if (customDownloader != null) {
        final res = await customDownloader!(imageUrl, targetFile);
        return res?.path;
      }

      // 2. Download via dart:io HttpClient with 5s timeout & 2MB cap
      final downloaded = await _downloadWithHttpClient(imageUrl, targetFile)
          .timeout(downloadTimeout, onTimeout: () => null);

      return downloaded?.path;
    } catch (e) {
      debugPrint('[PromoImageCache] Download/cache error for promo $promoId: $e');
      return null;
    }
  }

  Future<File?> _downloadWithHttpClient(String url, File targetFile) async {
    final client = HttpClient()..connectionTimeout = downloadTimeout;
    try {
      final uri = Uri.parse(url);
      final request = await client.getUrl(uri);
      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        return null;
      }

      // Check Content-Length header if present
      final contentLength = response.contentLength;
      if (contentLength > maxFileSizeBytes) {
        return null;
      }

      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
        if (bytes.length > maxFileSizeBytes) {
          // Exceeds 2 MB limit: abort download immediately
          return null;
        }
      }

      if (bytes.isEmpty) return null;

      // Write to temp file first, then atomic rename
      final tempFile = File('${targetFile.path}.tmp');
      await tempFile.writeAsBytes(bytes, flush: true);
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      return await tempFile.rename(targetFile.path);
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  /// Pre-downloads promo images for loaded promos and prunes obsolete cache files.
  Future<void> syncLoadedPromos({
    required List<({String promoId, String? imageUrl})> activePromos,
  }) async {
    try {
      final activePromoIds = <String>{};

      for (final item in activePromos) {
        activePromoIds.add(item.promoId);
        if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
          final cached = await getCachedImagePath(item.promoId);
          if (cached == null) {
            unawaited(getOrDownloadPromoImage(
              promoId: item.promoId,
              imageUrl: item.imageUrl,
            ));
          }
        }
      }

      // Prune cached files for promos that are no longer loaded
      final dir = await getCacheDirectory();
      if (!await dir.exists()) return;

      final entities = dir.listSync();
      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.jpg')) {
          final fileName = entity.uri.pathSegments.last;
          if (fileName.startsWith('promo_')) {
            final promoIdPart = fileName
                .replaceFirst('promo_', '')
                .replaceAll('.jpg', '');
            final stillActive = activePromoIds.any(
              (id) => id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_') == promoIdPart,
            );
            if (!stillActive) {
              try {
                await entity.delete();
              } catch (_) {}
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[PromoImageCache] Sync error: $e');
    }
  }
}
