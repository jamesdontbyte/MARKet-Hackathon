import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'notification_service.dart';
import 'zones.dart';

class GeofenceService {
  GeofenceService({
    required this.zones,
    this.onLog,
    this.onPosition,
    this.cooldown = const Duration(hours: 3),
    this.exitBufferMeters = 30,
  });

  final List<Zone> zones;
  final void Function(String message)? onLog;
  final void Function(Position position, Map<String, bool> inside)? onPosition;

  /// Minimum time between notifications for the same zone.
  final Duration cooldown;

  /// Extra distance needed to count as "exited" (stops GPS jitter flapping).
  final double exitBufferMeters;

  final Map<String, bool> _inside = {};
  final Map<String, DateTime> _lastNotified = {};
  StreamSubscription<Position>? _sub;

  bool get isRunning => _sub != null;

  /// Returns null on success, or an error message to show the user.
  Future<String?> start() async {
    if (isRunning) return null;

    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'GPS is off. Please turn on location services.';
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return 'Location permission denied. Enable it in app settings.';
    }

    await NotificationService.instance.requestPermission();

    // Background ("Allow all the time") location, needed when app is closed.
    final always = await Permission.locationAlways.request();
    if (!always.isGranted) {
      return 'Please choose "Allow all the time" for location so promos '
          'can reach you when the app is closed.';
    }

    final settings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // meters moved before a new update
      intervalDuration: const Duration(seconds: 5),
      // This foreground notification keeps tracking alive in the background.
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'Promo alerts are on',
        notificationText: 'Looking for deals near you',
        enableWakeLock: true,
      ),
    );

    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      _handlePosition,
      onError: (e) => onLog?.call('Location error: $e'),
    );
    onLog?.call('Geofence service started.');
    return null;
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    onLog?.call('Geofence service stopped.');
  }

  void _handlePosition(Position p) {
    for (final zone in zones) {
      final distance = Geolocator.distanceBetween(
        zone.lat, zone.lng, p.latitude, p.longitude,
      );
      final wasInside = _inside[zone.id] ?? false;
      final limit =
          wasInside ? zone.radiusMeters + exitBufferMeters : zone.radiusMeters;
      final isInside = distance <= limit;
      _inside[zone.id] = isInside;

      if (isInside && !wasInside) {
        onLog?.call('ENTERED ${zone.name} (${distance.toStringAsFixed(0)} m)');
        _notifyIfAllowed(zone);
      } else if (!isInside && wasInside) {
        onLog?.call('EXITED ${zone.name}');
      }
    }
    onPosition?.call(p, Map.of(_inside));
  }

  void _notifyIfAllowed(Zone zone) {
    final last = _lastNotified[zone.id];
    if (last != null && DateTime.now().difference(last) < cooldown) {
      onLog?.call('Skipped notification for ${zone.name} (cooldown).');
      return;
    }
    _lastNotified[zone.id] = DateTime.now();
    NotificationService.instance.showPromo(
      id: zone.id.hashCode & 0x7fffffff,
      title: zone.promoTitle,
      body: zone.promoBody,
      payload: zone.id,
    );
  }
}
