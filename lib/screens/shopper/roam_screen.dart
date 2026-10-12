import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../models/business.dart';
import '../../services/data_service.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/shopper_bottom_nav.dart';
import 'storefront_screen.dart';

/// RoamScreen provides interactive MSME discovery in San Jose de Buenavista.
/// Features flutter_map + OSM tiles, 1500m zone circle, business markers,
/// bottom quick-view sheet, and Map/List toggle with tile error fallback.
class RoamScreen extends StatefulWidget {
  const RoamScreen({super.key});

  @override
  State<RoamScreen> createState() => _RoamScreenState();
}

class _RoamScreenState extends State<RoamScreen> {
  final DataService _dataService = DataService();
  final MapController _mapController = MapController();

  List<Business> _businesses = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isListView = false;
  String _selectedCategory = 'all';
  Business? _selectedBusiness;

  @override
  void initState() {
    super.initState();
    _loadBusinesses();
  }

  Future<void> _loadBusinesses() async {
    try {
      final list = await _dataService.fetchVerifiedBusinesses(
        category: _selectedCategory == 'all' ? null : _selectedCategory,
      );
      if (mounted) {
        setState(() {
          _businesses = list;
          _isLoading = false;
          if (_businesses.isNotEmpty && _selectedBusiness == null) {
            _selectedBusiness = _businesses.first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _isLoading = false;
        });
      }
    }
  }

  void _onCategorySelected(String cat) {
    setState(() {
      _selectedCategory = cat;
      _isLoading = true;
    });
    _loadBusinesses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarketColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: const [
            Text(
              'MARK',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: MarketColors.primaryContainer,
              ),
            ),
            Text(
              'et',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: MarketColors.onSurface,
              ),
            ),
            SizedBox(width: 8),
            Text(
              'Roam',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: MarketColors.outline,
              ),
            ),
          ],
        ),
        actions: [
          // Map / List Segmented Toggle
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: MarketColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MarketColors.fieldBorder),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _isListView = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: !_isListView ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: !_isListView ? MarketElevation.level1 : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.map_rounded,
                          size: 16,
                          color: !_isListView ? MarketColors.primary : MarketColors.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Map',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: !_isListView ? MarketColors.primary : MarketColors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _isListView = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isListView ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: _isListView ? MarketElevation.level1 : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.list_rounded,
                          size: 16,
                          color: _isListView ? MarketColors.primary : MarketColors.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'List',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _isListView ? MarketColors.primary : MarketColors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Category Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: MarketSpacing.screenMargin,
                vertical: 6,
              ),
              child: Row(
                children: [
                  _buildFilterChip('all', 'All'),
                  const SizedBox(width: 6),
                  _buildFilterChip('cafe', 'Cafés'),
                  const SizedBox(width: 6),
                  _buildFilterChip('food', 'Food'),
                  const SizedBox(width: 6),
                  _buildFilterChip('retail', 'Retail'),
                  const SizedBox(width: 6),
                  _buildFilterChip('services', 'Services'),
                ],
              ),
            ),

            // Content Canvas
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(child: Text(_errorMessage!))
                      : _isListView
                          ? _buildListView()
                          : _buildMapView(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: ShopperBottomNav(
        currentIndex: 1,
        onTap: (idx) {
          if (idx == 0) Navigator.of(context).pushReplacementNamed('/shopper-home');
          if (idx == 2) Navigator.of(context).pushReplacementNamed('/stash');
          if (idx == 3) Navigator.of(context).pushReplacementNamed('/account');
        },
      ),
    );
  }

  Widget _buildFilterChip(String slug, String label) {
    final isSelected = _selectedCategory == slug;
    return GestureDetector(
      onTap: () => _onCategorySelected(slug),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? MarketColors.primaryContainer : MarketColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(MarketRadii.pill),
          border: Border.all(
            color: isSelected ? MarketColors.primaryContainer : MarketColors.fieldBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? MarketColors.onPrimaryContainer : MarketColors.secondary,
          ),
        ),
      ),
    );
  }

  static const _sanJoseCenter = LatLng(10.7674886, 121.9428977);

  Widget _buildMapView() {
    final center = _sanJoseCenter;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 13.5,
            onPositionChanged: (position, hasGesture) {},
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.market.antique.market_final',
              errorTileCallback: (tile, error, stackTrace) {
                // If tiles fail, switch to list view gracefully
                if (!_isListView && mounted) {
                  setState(() => _isListView = true);
                }
              },
            ),

            // 1500m San Jose Zone Circle
            CircleLayer(
              circles: [
                CircleMarker(
                  point: center,
                  radius: 1500,
                  useRadiusInMeter: true,
                  color: MarketColors.primaryContainer.withValues(alpha: 0.15),
                  borderColor: MarketColors.primaryContainer,
                  borderStrokeWidth: 2.0,
                ),
              ],
            ),

            // Business Markers
            MarkerLayer(
              markers: _businesses.map((b) {
                final isSelected = _selectedBusiness?.id == b.id;
                return Marker(
                  point: LatLng(b.lat, b.lng),
                  width: 50,
                  height: 50,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedBusiness = b;
                      });
                    },
                    child: AnimatedScale(
                      scale: isSelected ? 1.15 : 1.0,
                      duration: const Duration(milliseconds: 150),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? MarketColors.primaryContainer : MarketColors.surfaceContainerLowest,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? MarketColors.primary : MarketColors.fieldBorder,
                            width: 2.0,
                          ),
                          boxShadow: MarketElevation.level1,
                        ),
                        child: Icon(
                          Icons.storefront_rounded,
                          size: 24,
                          color: isSelected ? MarketColors.onSurface : MarketColors.primary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),

        // Quick-View Bottom Sheet Card
        if (_selectedBusiness != null)
          Positioned(
            bottom: 12,
            left: MarketSpacing.screenMargin,
            right: MarketSpacing.screenMargin,
            child: _buildQuickViewCard(_selectedBusiness!),
          ),
      ],
    );
  }

  Widget _buildQuickViewCard(Business b) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MarketColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MarketColors.cardBorder),
        boxShadow: MarketElevation.level2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.storefront_rounded, color: MarketColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: MarketColors.onSurface,
                      ),
                    ),
                    Text(
                      '${categoryLabels[b.category] ?? b.category} • San Jose',
                      style: const TextStyle(fontSize: 12, color: MarketColors.secondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(MarketRadii.pill),
                ),
                child: const Text(
                  'Verified',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            width: double.infinity,
            height: 44,
            label: 'View Storefront',
            icon: const Icon(Icons.store_rounded, size: 18),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StorefrontScreen(business: b),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildListView() {
    if (_businesses.isEmpty) {
      return const Center(
        child: Text(
          'No verified businesses in this category.',
          style: TextStyle(color: MarketColors.outline),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(MarketSpacing.screenMargin),
      itemCount: _businesses.length,
      itemBuilder: (context, index) {
        final b = _businesses[index];
        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => StorefrontScreen(business: b)),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: MarketColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MarketColors.cardBorder),
              boxShadow: MarketElevation.level1,
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.storefront_rounded, color: MarketColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: MarketColors.onSurface,
                        ),
                      ),
                      Text(
                        categoryLabels[b.category] ?? b.category,
                        style: const TextStyle(fontSize: 12, color: MarketColors.secondary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: MarketColors.primary),
              ],
            ),
          ),
        );
      },
    );
  }
}
