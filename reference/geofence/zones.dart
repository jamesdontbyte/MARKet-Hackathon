/// A circular geofence tied to a business promo.
/// Replace/extend with data from your backend later.
class Zone {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final double radiusMeters;
  final String promoTitle;
  final String promoBody;

  const Zone({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.radiusMeters,
    required this.promoTitle,
    required this.promoBody,
  });
}

/// Replaces the ~120-point GeoJSON polygon: same circle, one distance check.
const List<Zone> demoZones = [
  Zone(
    id: 'san_jose_area',
    name: 'San Jose de Buenavista',
    lat: 10.7525111,
    lng: 121.9413404,
    radiusMeters: 1500,
    promoTitle: 'Welcome to San Jose!',
    promoBody: 'Nearby businesses have promos for you. Tap to view.',
  ),
  // Add one Zone per business, e.g. a small 100 m radius around a shop:
  // Zone(id: 'shop_1', name: 'Shop 1', lat: 10.75, lng: 121.94,
  //      radiusMeters: 100, promoTitle: '20% off today', promoBody: '...'),
];
