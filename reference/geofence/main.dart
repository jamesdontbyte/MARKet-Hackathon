import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'geofence_service.dart';
import 'notification_service.dart';
import 'zones.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: GeofenceScreen(),
  ));
}

class GeofenceScreen extends StatefulWidget {
  const GeofenceScreen({super.key});

  @override
  State<GeofenceScreen> createState() => _GeofenceScreenState();
}

class _GeofenceScreenState extends State<GeofenceScreen> {
  late final GeofenceService _service;
  final List<String> _log = [];
  Position? _position;
  Map<String, bool> _inside = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = GeofenceService(
      zones: demoZones,
      // Set to Duration.zero while testing so every entry notifies.
      cooldown: const Duration(minutes: 1),
      onLog: (m) {
        if (!mounted) return;
        setState(() => _log.insert(0, '${TimeOfDay.now().format(context)}  $m'));
      },
      onPosition: (p, inside) {
        if (!mounted) return;
        setState(() {
          _position = p;
          _inside = inside;
        });
      },
    );
  }

  Future<void> _toggle() async {
    if (_service.isRunning) {
      await _service.stop();
      setState(() {});
      return;
    }
    final error = await _service.start();
    setState(() => _error = error);
  }

  @override
  void dispose() {
    // Don't stop the service here if you want it to keep running in background.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final running = _service.isRunning;
    return Scaffold(
      appBar: AppBar(title: const Text('Geofence Test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: _toggle,
              icon: Icon(running ? Icons.stop : Icons.play_arrow),
              label: Text(running ? 'Stop promo alerts' : 'Start promo alerts'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 16),
            if (_position != null)
              Text('Lat ${_position!.latitude.toStringAsFixed(6)}, '
                  'Lng ${_position!.longitude.toStringAsFixed(6)}'),
            const SizedBox(height: 8),
            for (final z in demoZones)
              ListTile(
                dense: true,
                leading: Icon(
                  (_inside[z.id] ?? false) ? Icons.check_circle : Icons.circle_outlined,
                  color: (_inside[z.id] ?? false) ? Colors.green : Colors.grey,
                ),
                title: Text(z.name),
                subtitle: Text('${z.radiusMeters.toStringAsFixed(0)} m radius'),
              ),
            const Divider(),
            const Text('Event log', style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: ListView.builder(
                itemCount: _log.length,
                itemBuilder: (_, i) => Text(_log[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
