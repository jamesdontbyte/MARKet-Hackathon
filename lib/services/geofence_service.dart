import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/config.dart';
import 'notification_service.dart';

class GeofenceZone {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final double radiusMeters;
  final String promoTitle;
  final String promoBody;
  final String? promoId;

  const GeofenceZone({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.radiusMeters,
    required this.promoTitle,
    required this.promoBody,
    this.promoId,
  });
}

class GeofenceService {
  GeofenceService({
    List<GeofenceZone>? zones,
    this.onLog,
    this.onPosition,
    this.onZoneEntered,
    this.onError,
    this.cooldown = notificationCooldown,
    this.exitBufferMeters = geofenceExitBufferMeters,
  }) : zones = zones ?? [defaultSanJoseZone];

  final List<GeofenceZone> zones;
  final void Function(String message)? onLog;
  final void Function(Position position, Map<String, bool> inside, String source)? onPosition;
  final void Function(GeofenceZone zone)? onZoneEntered;
  final void Function(String error)? onError;

  /// Minimum time between notifications for the same zone.
  final Duration cooldown;

  /// Extra distance needed to count as "exited" (anti-jitter buffer).
  final double exitBufferMeters;

  final Map<String, bool> _inside = {};
  final Map<String, DateTime> _lastNotified = {};
  final Map<String, DateTime> _lastEntered = {};
  StreamSubscription<Position>? _sub;

  String _activeProvider = 'FusedLocationProvider';
  String get activeProvider => _activeProvider;

  String? _lastError;
  String? get lastError => _lastError;

  Timer? _fallbackTimer;
  Timer? _safetyPollTimer;
  bool _streamFixReceived = false;
  DateTime? _lastStreamFixTime;
  DateTime? _lastAnyFixTime;
  String _lastSource = 'none';
  int _fixCount = 0;

  bool get isRunning => _sub != null;

  DateTime? getLastEntered(String zoneId) => _lastEntered[zoneId];
  DateTime? getLastNotified(String zoneId) => _lastNotified[zoneId];
  DateTime? get lastFixTime => _lastAnyFixTime;
  String get lastSource => _lastSource;

  Duration? getRemainingCooldown(String zoneId) {
    final last = _lastNotified[zoneId];
    if (last == null) return null;
    final elapsed = DateTime.now().difference(last);
    if (elapsed >= cooldown) return Duration.zero;
    return cooldown - elapsed;
  }

  static const defaultSanJoseZone = GeofenceZone(
    id: 'san_jose_zone',
    name: demoZoneName,
    lat: demoZoneLat,
    lng: demoZoneLng,
    radiusMeters: demoZoneRadiusMeters,
    promoTitle: 'Promos near you in San Jose',
    promoBody: 'Buy 1 Take 1 Afternoon Coffee Hour at Kape Tahanan (+2 more)',
    promoId: 'demo-top-promo-kape-tahanan',
  );

  void _startStream({required bool forceLocationManager}) {
    _sub?.cancel();
    _activeProvider = forceLocationManager
        ? 'LocationManager (forceLocationManager)'
        : 'FusedLocationProvider';

    onLog?.call(
      '[STREAM] Subscribing via $_activeProvider (distanceFilter: 0, interval: 2s)...',
    );

    final settings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
      intervalDuration: const Duration(seconds: 2),
      forceLocationManager: forceLocationManager,
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'Promo alerts are on',
        notificationText: 'Looking for deals near you',
        enableWakeLock: true,
      ),
    );

    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) => _handlePosition(pos, source: 'stream'),
      onError: (e) {
        _lastError = e.toString();
        onLog?.call('[STREAM ERROR] on $_activeProvider: $e');
        onError?.call(e.toString());
      },
      onDone: () {
        onLog?.call('[STREAM] getPositionStream stream completed / closed.');
      },
      cancelOnError: false,
    );
  }

  /// Returns null on success, or an error message to display.
  Future<String?> start() async {
    if (isRunning) return null;

    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'GPS is turned off. Please enable location services.';
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return 'Location permission denied. Enable it in App Settings.';
    }

    await NotificationService.instance.requestPermission();

    // Request background location permission ("Allow all the time")
    final always = await Permission.locationAlways.request();
    if (!always.isGranted) {
      onLog?.call('Notice: Background location not set to "Allow all the time".');
    }

    _lastError = null;
    _streamFixReceived = false;
    _startStream(forceLocationManager: false);

    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(const Duration(seconds: 15), () {
      if (isRunning && !_streamFixReceived) {
        onLog?.call(
          '[FALLBACK] No stream event within 15s on FusedLocationProvider. Restarting stream with forceLocationManager: true...',
        );
        _startStream(forceLocationManager: true);
      }
    });

    _safetyPollTimer?.cancel();
    _safetyPollTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!isRunning) return;
      final now = DateTime.now();
      if (_lastStreamFixTime != null &&
          now.difference(_lastStreamFixTime!) < const Duration(seconds: 10)) {
        onLog?.call(
          '[POLL] Skipped: stream fix arrived ${now.difference(_lastStreamFixTime!).inSeconds}s ago.',
        );
        return;
      }
      onLog?.call('[POLL] Safety poll: requesting getCurrentPosition()...');
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
        _handlePosition(pos, source: 'poll');
      } catch (e) {
        onLog?.call('[POLL] Safety poll error: $e');
      }
    });

    onLog?.call('Geofence foreground service started.');
    return null;
  }

  Future<void> stop() async {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    _safetyPollTimer?.cancel();
    _safetyPollTimer = null;
    _streamFixReceived = false;
    await _sub?.cancel();
    _sub = null;
    onLog?.call('Geofence service stopped.');
  }

  void feedManualPosition(Position p) {
    _handlePosition(p, source: 'manual');
  }

  void _handlePosition(Position p, {required String source}) {
    if (source == 'stream') {
      _streamFixReceived = true;
      _lastStreamFixTime = DateTime.now();
      _fallbackTimer?.cancel();
      _fallbackTimer = null;
    }
    _lastAnyFixTime = DateTime.now();
    _lastSource = source;
    _lastError = null;

    onLog?.call(
      'FIX #${++_fixCount} [$source]: (${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)}) | acc: ${p.accuracy.toStringAsFixed(1)}m | mocked: ${p.isMocked} | provider: $_activeProvider',
    );
    for (final zone in zones) {
      final distance = Geolocator.distanceBetween(
        zone.lat,
        zone.lng,
        p.latitude,
        p.longitude,
      );

      final wasInside = _inside[zone.id] ?? false;
      final limit =
          wasInside ? zone.radiusMeters + exitBufferMeters : zone.radiusMeters;
      final isInside = distance <= limit;
      _inside[zone.id] = isInside;

      if (isInside && !wasInside) {
        _lastEntered[zone.id] = DateTime.now();
        onLog?.call('ENTERED ${zone.name} (${distance.toStringAsFixed(0)} m)');
        _notifyIfAllowed(zone);
        onZoneEntered?.call(zone);
      } else if (!isInside && wasInside) {
        onLog?.call('EXITED ${zone.name} (${distance.toStringAsFixed(0)} m)');
      }
    }
    onPosition?.call(p, Map.of(_inside), source);
  }

  void _notifyIfAllowed(GeofenceZone zone) {
    final last = _lastNotified[zone.id];
    if (last != null && DateTime.now().difference(last) < cooldown) {
      onLog?.call('Skipped notification for ${zone.name} (cooldown active).');
      return;
    }
    _lastNotified[zone.id] = DateTime.now();

    NotificationService.instance.showPromo(
      id: zone.id.hashCode & 0x7fffffff,
      title: zone.promoTitle,
      body: zone.promoBody,
      payload: zone.promoId ?? zone.id,
    );
  }

  /// Demo shortcut: simulate entering zone immediately, ignoring cooldown
  void simulateEnter({GeofenceZone? zone}) {
    final target = zone ?? zones.first;
    _inside[target.id] = true;
    _lastEntered[target.id] = DateTime.now();
    _lastNotified[target.id] = DateTime.now();
    onLog?.call('SIMULATED ENTER: ${target.name}');
    NotificationService.instance.showPromo(
      id: target.id.hashCode & 0x7fffffff,
      title: target.promoTitle,
      body: target.promoBody,
      payload: target.promoId ?? target.id,
    );
    onZoneEntered?.call(target);
  }

  /// Demo shortcut: simulate leaving zone
  void simulateExit({GeofenceZone? zone}) {
    final target = zone ?? zones.first;
    _inside[target.id] = false;
    onLog?.call('SIMULATED EXIT: ${target.name}');
  }
}
