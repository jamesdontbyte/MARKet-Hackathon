import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase.dart';

/// Type definition for edge function invocation (allows pure unit test faking without mocks)
typedef FunctionInvoker = Future<FunctionResponse> Function(
  String functionName, {
  Map<String, dynamic>? body,
  Map<String, String>? headers,
});

/// A single stock photo candidate returned by Pixabay
class StockPhotoCandidate {
  final String id;
  final String mediumUrl;
  final String thumbnailUrl;
  final String photographer;
  final String url;

  const StockPhotoCandidate({
    required this.id,
    required this.mediumUrl,
    required this.thumbnailUrl,
    required this.photographer,
    required this.url,
  });

  factory StockPhotoCandidate.fromJson(Map<String, dynamic> json) {
    return StockPhotoCandidate(
      id: json['id']?.toString() ?? '',
      mediumUrl: json['medium_url'] as String? ?? '',
      thumbnailUrl: json['thumbnail_url'] as String? ?? '',
      photographer: json['photographer'] as String? ?? 'Pixabay Contributor',
      url: json['url'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'medium_url': mediumUrl,
        'thumbnail_url': thumbnailUrl,
        'photographer': photographer,
        'url': url,
      };
}

/// Results for a single item from the find-product-photos Edge Function
class StockPhotoItemResult {
  final String itemId;
  final List<StockPhotoCandidate> candidates;
  final String? bestId;
  final double confidence;

  const StockPhotoItemResult({
    required this.itemId,
    required this.candidates,
    this.bestId,
    required this.confidence,
  });

  StockPhotoCandidate? get bestMatch {
    if (bestId == null) return null;
    try {
      return candidates.firstWhere((c) => c.id == bestId);
    } catch (_) {
      return null;
    }
  }

  factory StockPhotoItemResult.fromJson(Map<String, dynamic> json) {
    final rawCandidates = json['candidates'] as List<dynamic>? ?? [];
    final candidates = rawCandidates
        .whereType<Map<String, dynamic>>()
        .map((c) => StockPhotoCandidate.fromJson(c))
        .toList();

    return StockPhotoItemResult(
      itemId: json['item_id']?.toString() ?? '',
      candidates: candidates,
      bestId: json['best_id'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Typed exception for stock photo operations with user-friendly messages
class StockPhotoException implements Exception {
  final String message;
  final String code;

  const StockPhotoException(this.message, {this.code = 'generic'});

  @override
  String toString() => message;
}

/// Builds a clean English search query by removing sizes, prices, promo words,
/// and punctuation, keeping the dish/service name and category.
String buildCleanSearchQuery(String name, [String? category]) {
  if (name.trim().isEmpty) return (category ?? '').trim();

  var clean = name.toLowerCase();

  // 1. Remove punctuation (replace with spaces)
  clean = clean.replaceAll(RegExp(r'[(),.!?:;"#&@+*\-_~\[\]{}/\\<>%|]'), ' ');

  // 2. Remove promo words (including phrases with numbers like "buy 1 take 1")
  clean = clean.replaceAll(
    RegExp(r'\b(?:buy\s+1\s+take\s+1|buy\s+one\s+take\s+one|bogo|promo|promos|discount|sale|off|free|special|deal|deals|combo|combos|save|hot|fresh|new|bestseller|best\s+seller)\b', caseSensitive: false),
    ' ',
  );

  // 3. Remove sizes & measurement units (e.g. 12oz, 16 oz, 500ml, 1kg, 2pcs, large, small, etc.)
  clean = clean.replaceAll(
    RegExp(r'\b\d+\s*(?:oz|ml|l|g|kg|pcs|pc|slices|slice|in|inch|inches|cm|mm)\b', caseSensitive: false),
    ' ',
  );
  clean = clean.replaceAll(
    RegExp(r'\b(?:extra\s+large|large|medium|small|regular|solo|sharing|jumbo|mini|grande|venti|tall|xl)\b', caseSensitive: false),
    ' ',
  );

  // 4. Remove prices (e.g. P180, ₱150, 150/-, 150php, or standalone numbers)
  clean = clean.replaceAll(
    RegExp(r'(?:₱|p|php|\$)?\s*\d+(?:\.\d{1,2})?\s*(?:/-|pesos?|php)?\b', caseSensitive: false),
    ' ',
  );
  clean = clean.replaceAll(RegExp(r'\b\d+\b'), ' ');

  // 5. Normalize whitespace
  clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();

  // 6. Clean category
  var catClean = (category ?? '').toLowerCase();
  catClean = catClean.replaceAll(RegExp(r'[(),.!?:;"#&@+*\-_~\[\]{}/\\<>]'), ' ');
  catClean = catClean.replaceAll(RegExp(r'\s+'), ' ').trim();

  if (catClean.isNotEmpty &&
      catClean != 'general' &&
      !clean.contains(catClean)) {
    clean = '$clean $catClean'.trim();
  }

  return clean.isNotEmpty ? clean : ((category ?? '').trim().isNotEmpty ? (category ?? '').trim() : name.trim());
}

/// Service responsible for finding stock photos and downloading them safely
class StockPhotoService {
  final FunctionInvoker _invoker;

  StockPhotoService({FunctionInvoker? invoker})
      : _invoker = invoker ??
            ((String fn, {Map<String, dynamic>? body, Map<String, String>? headers}) =>
                supabase.functions.invoke(fn, body: body, headers: headers));

  /// Finds stock photos for up to 15 items by invoking 'find-product-photos' Edge Function.
  Future<List<StockPhotoItemResult>> findPhotos(
    List<Map<String, dynamic>> items,
  ) async {
    if (items.isEmpty) return [];

    try {
      final res = await _invoker(
        'find-product-photos',
        body: {'items': items},
      );

      final status = res.status;
      final data = res.data;

      if (status != 200) {
        final errMap = data is Map ? data : <String, dynamic>{};
        final code = errMap['code']?.toString() ?? 'server_error';
        final errorMsg = errMap['error']?.toString();

        if (code == 'pixabay_rate_limited') {
          throw const StockPhotoException(
            'Photo service is currently busy. Please try again shortly.',
            code: 'pixabay_rate_limited',
          );
        } else if (code == 'pixabay_not_configured') {
          throw const StockPhotoException(
            'Stock photo search is currently unavailable on this server.',
            code: 'pixabay_not_configured',
          );
        } else if (code == 'missing_api_key' || errMap['missing_key'] == true) {
          throw const StockPhotoException(
            'Stock photo search is currently unavailable on this server.',
            code: 'missing_api_key',
          );
        } else if (code == 'gemini_rate_limited') {
          throw const StockPhotoException(
            'AI matcher is busy. Please try again in a minute.',
            code: 'gemini_rate_limited',
          );
        } else if (code == 'rate_limited' || status == 429) {
          throw const StockPhotoException(
            'Rate limit reached. You can search up to 30 times per hour. Please try again later.',
            code: 'rate_limited',
          );
        }

        throw StockPhotoException(
          errorMsg ?? 'Failed to search stock photos ($status).',
          code: code,
        );
      }

      if (data is Map && data['results'] is List) {
        final list = data['results'] as List<dynamic>;
        return list
            .whereType<Map<String, dynamic>>()
            .map((e) => StockPhotoItemResult.fromJson(e))
            .toList();
      }

      return [];
    } on StockPhotoException {
      rethrow;
    } on SocketException {
      throw const StockPhotoException(
        'No internet connection. Please check your network and retry.',
        code: 'network_error',
      );
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('socket') || msg.contains('failed host lookup') || msg.contains('connection')) {
        throw const StockPhotoException(
          'No internet connection. Please check your network and retry.',
          code: 'network_error',
        );
      }
      throw StockPhotoException(
        'Unable to find photos right now. Please try again.',
        code: 'unknown_error',
      );
    }
  }

  /// Trusted hosts allowed for stock photo downloading
  static const Set<String> allowedStockHosts = {
    'cdn.pixabay.com',
    'pixabay.com',
  };

  /// Downloads medium image strictly from cdn.pixabay.com or pixabay.com (HTTPS only, 5s timeout, max 2 MB).
  /// Never follows redirects to untrusted hosts.
  /// Throws [StockPhotoException] on host mismatch, timeout, error status, or excessive size.
  static Future<Uint8List> downloadMediumImage(
    String mediumUrl, {
    HttpClient? client,
  }) async {
    final uri = Uri.tryParse(mediumUrl);
    if (uri == null || uri.scheme != 'https' || !allowedStockHosts.contains(uri.host.toLowerCase())) {
      throw const StockPhotoException(
        'Security error: Image source must be HTTPS from cdn.pixabay.com or pixabay.com',
        code: 'unauthorized_host',
      );
    }

    final httpClient = client ?? HttpClient()
      ..connectionTimeout = const Duration(seconds: 5);

    try {
      final request = await httpClient
          .getUrl(uri)
          .timeout(const Duration(seconds: 5));
      // Security: never automatically follow redirects to another host
      request.followRedirects = false;
      request.maxRedirects = 0;

      final response = await request.close().timeout(const Duration(seconds: 5));

      // Handle redirect safely
      if (response.isRedirect) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (location == null) {
          throw const StockPhotoException(
            'Security error: Redirect location missing',
            code: 'invalid_redirect',
          );
        }
        final targetUri = Uri.tryParse(location);
        if (targetUri == null ||
            targetUri.scheme != 'https' ||
            !allowedStockHosts.contains(targetUri.host.toLowerCase())) {
          throw const StockPhotoException(
            'Security error: Redirect to unauthorized host is blocked',
            code: 'unauthorized_redirect',
          );
        }
        final redirectReq = await httpClient.getUrl(targetUri).timeout(const Duration(seconds: 5));
        redirectReq.followRedirects = false;
        redirectReq.maxRedirects = 0;
        final redirectRes = await redirectReq.close().timeout(const Duration(seconds: 5));
        return await _readResponseBytes(redirectRes);
      }

      return await _readResponseBytes(response);
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  static Future<Uint8List> _readResponseBytes(HttpClientResponse response) async {
    if (response.statusCode != HttpStatus.ok) {
      throw StockPhotoException(
        'Download failed with HTTP status ${response.statusCode}',
        code: 'http_error',
      );
    }

    // 2 MB limit
    const maxBytes = 2 * 1024 * 1024;
    if (response.contentLength > maxBytes) {
      throw const StockPhotoException(
        'Photo exceeds 2 MB size limit',
        code: 'image_too_large',
      );
    }

    final bytes = BytesBuilder(copy: false);
    int totalBytes = 0;

    await for (final chunk in response.timeout(const Duration(seconds: 5))) {
      totalBytes += chunk.length;
      if (totalBytes > maxBytes) {
        throw const StockPhotoException(
          'Photo exceeds 2 MB size limit',
          code: 'image_too_large',
        );
      }
      bytes.add(chunk);
    }

    return bytes.toBytes();
  }
}
