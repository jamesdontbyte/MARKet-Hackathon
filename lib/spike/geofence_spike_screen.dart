import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../services/geofence_service.dart';
import '../services/notification_service.dart';

class GeofenceSpikeScreen extends StatefulWidget {
  const GeofenceSpikeScreen({super.key});

  @override
  State<GeofenceSpikeScreen> createState() => _GeofenceSpikeScreenState();
}

class _GeofenceSpikeScreenState extends State<GeofenceSpikeScreen> {
  late final GeofenceService _service;
  final List<String> _logs = [];
  Position? _position;
  Map<String, bool> _inside = {};
  String? _error;
  bool _locationServiceEnabled = false;
  String _geolocatorPermStatus = 'Unknown';
  String? _lastStreamError;
  String _locationPermStatus = 'Unknown';
  String _notificationPermStatus = 'Unknown';
  String? _lastFixSource;
  DateTime? _lastFixTime;
  int _lockscreenCountdown = 0;
  int _positionUpdateCount = 0;
  DateTime? _lastEnterTime;
  Timer? _countdownTimer;
  Timer? _tickerTimer;

  @override
  void initState() {
    super.initState();
    _checkPermissions();

    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    _service = GeofenceService(
      zones: [GeofenceService.defaultSanJoseZone],
      cooldown: notificationCooldown,
      onLog: (m) {
        if (!mounted) return;
        final timeStr = TimeOfDay.now().format(context);
        setState(() => _logs.insert(0, '[$timeStr] $m'));
      },
      onError: (err) {
        if (!mounted) return;
        setState(() => _lastStreamError = err);
      },
      onPosition: (pos, insideMap, source) {
        if (!mounted) return;
        setState(() {
          _positionUpdateCount++;
          _position = pos;
          _inside = insideMap;
          _lastFixSource = source;
          _lastFixTime = DateTime.now();
          _lastStreamError = null;
        });
      },
      onZoneEntered: (zone) {
        if (!mounted) return;
        setState(() {
          _lastEnterTime = DateTime.now();
          _logs.insert(0, '[ALERT] Enter event triggered for ${zone.name}');
        });
      },
    );
  }

  Future<void> _checkPermissions() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    final geoPerm = await Geolocator.checkPermission();
    final locStatus = await Permission.locationAlways.status;
    final notifStatus = await Permission.notification.status;
    if (!mounted) return;
    setState(() {
      _locationServiceEnabled = enabled;
      _geolocatorPermStatus = geoPerm.name;
      _locationPermStatus = locStatus.toString().split('.').last;
      _notificationPermStatus = notifStatus.toString().split('.').last;
    });
  }

  Future<void> _toggleService() async {
    if (_service.isRunning) {
      await _service.stop();
      setState(() {});
      return;
    }
    _lastStreamError = null;
    final err = await _service.start();
    await _checkPermissions();
    if (!mounted) return;
    setState(() => _error = err);
  }

  Future<void> _getCurrentPositionNow() async {
    final startStr = TimeOfDay.now().format(context);
    setState(() => _logs.insert(0, '[$startStr] Requesting one-shot getCurrentPosition()...'));
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (!mounted) return;
      _service.feedManualPosition(pos);
      setState(() {
        _position = pos;
        _positionUpdateCount++;
        _lastFixSource = 'manual';
        _lastFixTime = DateTime.now();
        _lastStreamError = null;
      });
      final timeStr = TimeOfDay.now().format(context);
      final logMsg =
          'ONE-SHOT FIX: (${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}) | acc: ${pos.accuracy.toStringAsFixed(1)}m | mocked: ${pos.isMocked}';
      setState(() => _logs.insert(0, '[$timeStr] $logMsg'));
    } catch (e) {
      if (!mounted) return;
      final timeStr = TimeOfDay.now().format(context);
      setState(() {
        _lastStreamError = e.toString();
        _logs.insert(0, '[$timeStr] ONE-SHOT ERROR: $e');
      });
    }
  }

  void _testLockscreenIn5Seconds() {
    setState(() => _lockscreenCountdown = 5);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_lockscreenCountdown <= 1) {
        timer.cancel();
        setState(() => _lockscreenCountdown = 0);
        _service.simulateEnter();
      } else {
        setState(() => _lockscreenCountdown--);
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _tickerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = _service.isRunning;
    final lastEnter =
        _lastEnterTime ?? _service.getLastEntered('san_jose_zone');
    final remainingCooldown = _service.getRemainingCooldown('san_jose_zone');

    final fixAgeSeconds = _lastFixTime != null
        ? DateTime.now().difference(_lastFixTime!).inSeconds
        : null;
    final fixAgeStr =
        fixAgeSeconds != null ? '${fixAgeSeconds}s ago' : 'No fix yet';

    double? distToCenter;
    if (_position != null) {
      distToCenter = Geolocator.distanceBetween(
        demoZoneLat,
        demoZoneLng,
        _position!.latitude,
        _position!.longitude,
      );
    }
    final isInsideSanJose = _inside['san_jose_zone'] ??
        (distToCenter != null && distToCenter <= demoZoneRadiusMeters);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phase 0.5: Geofence Spike'),
        actions: [
          IconButton(
            tooltip: 'App Settings',
            icon: const Icon(Icons.settings),
            onPressed: () => openAppSettings(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(MarketSpacing.md),
        children: [
          // Service toggle card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(MarketRadii.card),
              border: Border.all(color: MarketColors.cardBorder),
              boxShadow: MarketElevation.level1,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Foreground Service',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isRunning
                            ? MarketColors.success.withValues(alpha: 0.15)
                            : MarketColors.outlineVariant.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(MarketRadii.pill),
                      ),
                      child: Text(
                        isRunning ? 'ACTIVE' : 'STOPPED',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isRunning
                              ? MarketColors.success
                              : MarketColors.outline,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRunning
                        ? MarketColors.error
                        : MarketColors.primaryContainer,
                    foregroundColor: isRunning
                        ? Colors.white
                        : MarketColors.onSurface,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MarketRadii.button),
                    ),
                  ),
                  onPressed: _toggleService,
                  icon: Icon(isRunning ? Icons.stop : Icons.play_arrow),
                  label: Text(
                    isRunning
                        ? 'Stop Promo Tracking'
                        : 'Start Promo Tracking (Foreground)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: const TextStyle(color: MarketColors.error),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Permissions card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(MarketRadii.card),
              border: Border.all(color: MarketColors.cardBorder),
              boxShadow: MarketElevation.level1,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hardware Permissions',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                _permRow(
                  'Location Services (GPS)',
                  _locationServiceEnabled ? 'ENABLED' : 'DISABLED',
                ),
                _permRow('Geolocator Permission', _geolocatorPermStatus),
                _permRow('Background Location (Always)', _locationPermStatus),
                _permRow('Notifications', _notificationPermStatus),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MarketRadii.button),
                    ),
                  ),
                  onPressed: () async {
                    await Permission.locationAlways.request();
                    await NotificationService.instance.requestPermission();
                    await _checkPermissions();
                  },
                  icon: const Icon(Icons.security),
                  label: const Text('Request "Allow all the time"'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Lockscreen & Simulation test card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(MarketRadii.card),
              border: Border.all(color: MarketColors.cardBorder),
              boxShadow: MarketElevation.level1,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Lockscreen Notification Test',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Test receiving promo notification while device is screen-locked, and tapping it to launch.',
                  style: TextStyle(fontSize: 13, color: MarketColors.outline),
                ),
                const SizedBox(height: 12),
                if (_lockscreenCountdown > 0)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: MarketColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: MarketColors.warning),
                    ),
                    child: Text(
                      'Lock phone now! Notification in $_lockscreenCountdown s...',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: MarketColors.warning,
                      ),
                    ),
                  ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: MarketColors.primary,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MarketRadii.button),
                    ),
                  ),
                  onPressed: _testLockscreenIn5Seconds,
                  icon: const Icon(Icons.timer),
                  label: const Text('Test on Lockscreen (5s countdown)'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MarketRadii.button),
                    ),
                  ),
                  onPressed: () => _service.simulateEnter(),
                  icon: const Icon(Icons.notifications_active),
                  label: const Text('Fire Notification Immediately'),
                ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MarketRadii.button),
                    ),
                  ),
                  onPressed: _getCurrentPositionNow,
                  icon: const Icon(Icons.my_location),
                  label: const Text('Get current position now'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // GPS Telemetry card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(MarketRadii.card),
              border: Border.all(color: MarketColors.cardBorder),
              boxShadow: MarketElevation.level1,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'GPS Telemetry',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isInsideSanJose
                            ? MarketColors.success.withValues(alpha: 0.15)
                            : MarketColors.outlineVariant.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(MarketRadii.pill),
                      ),
                      child: Text(
                        isInsideSanJose ? 'INSIDE' : 'OUTSIDE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isInsideSanJose
                              ? MarketColors.success
                              : MarketColors.outline,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _telemetryRow(
                  'Zone Status',
                  isInsideSanJose ? 'INSIDE' : 'OUTSIDE',
                  highlight: isInsideSanJose,
                ),
                _telemetryRow(
                  'Distance to Center',
                  distToCenter != null
                      ? '${distToCenter.toStringAsFixed(1)} m'
                      : 'Waiting for fix...',
                ),
                 _telemetryRow(
                  'Position Updates',
                  '$_positionUpdateCount fixes',
                ),
                _telemetryRow(
                  'Update Source',
                  _lastFixSource?.toUpperCase() ?? 'NONE',
                  highlight: _lastFixSource == 'stream',
                ),
                _telemetryRow(
                  'Update Age',
                  fixAgeStr,
                ),
                _telemetryRow(
                  'Active Provider',
                  _service.activeProvider,
                ),
                _telemetryRow(
                  'Last Stream Error',
                  _service.lastError ?? _lastStreamError ?? 'None',
                  isError: (_service.lastError ?? _lastStreamError) != null,
                ),
                _telemetryRow(
                  'Last Enter Event',
                  lastEnter != null
                      ? '${lastEnter.hour.toString().padLeft(2, '0')}:${lastEnter.minute.toString().padLeft(2, '0')}:${lastEnter.second.toString().padLeft(2, '0')}'
                      : 'None yet',
                ),
                _telemetryRow(
                  'Cooldown Remaining',
                  (remainingCooldown == null || remainingCooldown == Duration.zero)
                      ? 'Ready (0s)'
                      : '${remainingCooldown.inSeconds}s (${remainingCooldown.inMinutes}m ${(remainingCooldown.inSeconds % 60).toString().padLeft(2, '0')}s)',
                ),
                if (_position != null) ...[
                  const Divider(height: 20),
                  Text(
                    'Lat: ${_position!.latitude.toStringAsFixed(6)}, Lng: ${_position!.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Accuracy: ${_position!.accuracy.toStringAsFixed(1)} m (Zone radius: ${demoZoneRadiusMeters.toStringAsFixed(0)} m)',
                    style: const TextStyle(fontSize: 12, color: MarketColors.outline),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Event log
          Text(
            'Live Spike Logs',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Container(
            height: 220,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _logs.isEmpty
                ? const Text(
                    'No logs yet. Start service or fire test notification.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  )
                : ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (ctx, idx) => Text(
                      _logs[idx],
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _permRow(String title, String status) {
    final isGood = status == 'granted' ||
        status == 'ENABLED' ||
        status == 'always' ||
        status == 'whileInUse';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 13)),
          Text(
            status,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isGood ? MarketColors.success : MarketColors.warning,
            ),
          ),
        ],
      ),
    );
  }

  Widget _telemetryRow(
    String title,
    String value, {
    bool highlight = false,
    bool isError = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              title,
              style: const TextStyle(fontSize: 13, color: MarketColors.outline),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isError
                    ? MarketColors.error
                    : (highlight ? MarketColors.success : MarketColors.onSurface),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SpikePromoDetailScreen extends StatelessWidget {
  final String? payload;
  const SpikePromoDetailScreen({super.key, this.payload});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Target')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 80,
              color: MarketColors.success,
            ),
            const SizedBox(height: 16),
            const Text(
              'Notification Tap Successful!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'The notification opened this screen properly even from a locked screen state.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MarketColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: MarketColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payload Received:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    payload ?? '(No payload provided)',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      color: MarketColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back to Spike Console'),
            ),
          ],
        ),
      ),
    );
  }
}
