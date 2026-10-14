// App configuration constants.

const double defaultBusinessRadiusMeters = 200.0;
const double geofenceExitBufferMeters = 30.0;
const Duration notificationCooldown = Duration(minutes: 3);

const String demoOtp = '123456';
const int demoAutoVerifySeconds = 10;
const bool emergencySimulate = true;
const bool stockPhotosEnabled = true;

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
