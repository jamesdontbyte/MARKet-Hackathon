// App configuration constants & demo shortcuts.

const String demoZoneName = 'San Jose de Buenavista';
const double demoZoneLat = 10.7674886;
const double demoZoneLng = 121.9428977;
const double demoZoneRadiusMeters = 4400.0;
const double geofenceExitBufferMeters = 30.0;
const Duration notificationCooldown = Duration(minutes: 3);

const String demoOtp = '123456';
const int demoAutoVerifySeconds = 10;

// Geofence & simulation flags
const bool perBusinessGeofence = false;
const bool emergencySimulate = true;

/// 8 Canonical category slugs
const List<String> canonicalCategories = [
  'food',
  'cafe',
  'salon',
  'retail',
  'grocery',
  'wellness',
  'services',
  'travel',
];

const Map<String, String> categoryLabels = {
  'food': 'Food & Restaurants',
  'cafe': 'Cafés',
  'salon': 'Salons & Barbershops',
  'retail': 'Retail & Shopping',
  'grocery': 'Groceries & Marts',
  'wellness': 'Health & Wellness',
  'services': 'Services',
  'travel': 'Travel & Stays',
};
