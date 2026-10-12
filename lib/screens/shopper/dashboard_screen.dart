import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../models/business.dart';
import '../../models/profile.dart';
import '../../models/promo.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../services/geofence_service.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/shopper_bottom_nav.dart';
import '../shared/permission_explainer_screen.dart';
import 'promo_detail_screen.dart';
import 'storefront_screen.dart';
import 'voucher_screen.dart';

/// DashboardScreen is the primary shopper landing screen.
/// Features:
/// - Brand header with hidden geofence simulation sheet on long-press of "MARK"
/// - Non-functional/clean notification bell (no inbox per spec)
/// - Missing permissions banner with link to 3-step PermissionExplainerScreen
/// - Instant search and category filter carousel
/// - "Businesses for You" strictly filtered by profiles.interests (verified businesses only)
/// - "Popular Establishments" around San Jose de Buenavista
/// - "Featured Promotions" carousel with direct voucher generation and stash bookmarking
/// - Full loading, empty, and error states
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  final DataService _dataService = DataService();
  final TextEditingController _searchController = TextEditingController();

  Profile? _profile;
  List<Business> _verifiedBusinesses = [];
  List<Promo> _activePromos = [];
  Set<String> _savedPromoIds = {};

  bool _isLoading = true;
  String? _errorMessage;
  String _selectedCategory = 'all';
  String _searchQuery = '';

  double _userLat = demoZoneLat;
  double _userLng = demoZoneLng;
  bool _hasPermissions = true;

  final List<Map<String, String>> _categories = const [
    {'slug': 'all', 'label': 'All Categories', 'icon': 'apps'},
    {'slug': 'food', 'label': 'Food', 'icon': 'restaurant'},
    {'slug': 'cafe', 'label': 'Cafés', 'icon': 'local_cafe'},
    {'slug': 'salon', 'label': 'Salons & Barbershops', 'icon': 'content_cut'},
    {'slug': 'retail', 'label': 'Retail', 'icon': 'shopping_bag'},
    {'slug': 'services', 'label': 'Services', 'icon': 'handyman'},
    {'slug': 'grocery', 'label': 'Groceries', 'icon': 'local_grocery_store'},
    {'slug': 'wellness', 'label': 'Wellness', 'icon': 'spa'},
    {'slug': 'travel', 'label': 'Travel', 'icon': 'hotel'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
    _loadDashboardData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    try {
      final locInUse = await Permission.locationWhenInUse.isGranted;
      final locAlways = await Permission.locationAlways.isGranted;
      final notif = await Permission.notification.isGranted;
      if (mounted) {
        setState(() {
          _hasPermissions = locInUse && locAlways && notif;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Fetch user profile
      _profile = await _authService.fetchCurrentProfile();

      // 2. Fetch verified businesses only
      final businesses = await _dataService.fetchVerifiedBusinesses();

      // 3. Fetch active promos from verified businesses
      final promos = await _dataService.fetchActivePromos();

      // 4. Fetch saved stash items
      if (_profile != null) {
        final stashed = await _dataService.fetchStash(_profile!.id);
        _savedPromoIds = stashed.map((p) => p.id).toSet();
      }

      // 5. Try getting user location for distances (non-blocking)
      try {
        final pos = await Geolocator.getLastKnownPosition();
        if (pos != null) {
          _userLat = pos.latitude;
          _userLng = pos.longitude;
        }
      } catch (_) {
        _userLat = demoZoneLat;
        _userLng = demoZoneLng;
      }

      if (mounted) {
        setState(() {
          _verifiedBusinesses = businesses;
          _activePromos = promos;
          _isLoading = false;
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

  Future<void> _toggleStash(Promo promo) async {
    final uid = _profile?.id ?? _authService.currentUserId;
    if (uid == null) return;

    final isSaved = _savedPromoIds.contains(promo.id);
    setState(() {
      if (isSaved) {
        _savedPromoIds.remove(promo.id);
      } else {
        _savedPromoIds.add(promo.id);
      }
    });

    try {
      if (isSaved) {
        await _dataService.removeFromStash(uid, promo.id);
      } else {
        await _dataService.saveToStash(uid, promo.id);
      }
    } catch (_) {
      // Revert on error
      if (mounted) {
        setState(() {
          if (isSaved) {
            _savedPromoIds.add(promo.id);
          } else {
            _savedPromoIds.remove(promo.id);
          }
        });
      }
    }
  }

  void _showSimulationSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: MarketColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: MarketColors.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Demo Geofence Simulation',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: MarketColors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Trigger hyperlocal geofence events for testing in San Jose.',
                  style: TextStyle(
                    fontSize: 13,
                    color: MarketColors.secondary,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: MarketColors.primaryContainer.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.login_rounded, color: MarketColors.primary),
                  ),
                  title: const Text('Simulate entering zone', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Fires promo notification in San Jose'),
                  onTap: () {
                    Navigator.pop(ctx);
                    GeofenceService().simulateEnter();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Simulated entering San Jose geofence! Promo notification triggered.'),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: MarketColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.logout_rounded, color: MarketColors.secondary),
                  ),
                  title: const Text('Simulate leaving zone', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Resets inside state to outside'),
                  onTap: () {
                    Navigator.pop(ctx);
                    GeofenceService().simulateExit();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Simulated leaving San Jose geofence.'),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.bug_report_rounded, color: Color(0xFF2563EB)),
                  ),
                  title: const Text('Open Geofence Spike Screen', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Live GPS logs, coordinates & diagnostics'),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).pushNamed('/spike');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _getDistanceToBusiness(Business b) {
    return Geolocator.distanceBetween(_userLat, _userLng, b.latitude, b.longitude);
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toInt()}m away';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}km away';
    }
  }

  List<Business> _filterBusinessesForYou() {
    return _verifiedBusinesses.where((b) {
      // 1. Filter by shopper interests
      if (_profile != null && _profile!.interests.isNotEmpty) {
        if (!_profile!.interests.contains(b.category)) {
          return false;
        }
      }
      // 2. Filter by category chip
      if (_selectedCategory != 'all' && b.category != _selectedCategory) {
        return false;
      }
      // 3. Filter by search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchName = b.name.toLowerCase().contains(query);
        final matchBio = b.bio?.toLowerCase().contains(query) ?? false;
        final matchCat = b.category.toLowerCase().contains(query);
        if (!matchName && !matchBio && !matchCat) return false;
      }
      return true;
    }).toList();
  }

  List<Business> _filterPopularBusinesses() {
    return _verifiedBusinesses.where((b) {
      if (_selectedCategory != 'all' && b.category != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchName = b.name.toLowerCase().contains(query);
        final matchBio = b.bio?.toLowerCase().contains(query) ?? false;
        if (!matchName && !matchBio) return false;
      }
      return true;
    }).toList();
  }

  List<Promo> _filterFeaturedPromos() {
    return _activePromos.where((p) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchTitle = p.title.toLowerCase().contains(query);
        final matchDesc = p.description?.toLowerCase().contains(query) ?? false;
        if (!matchTitle && !matchDesc) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarketColors.surface,
      appBar: AppBar(
        backgroundColor: MarketColors.surfaceContainerLowest,
        elevation: 0.5,
        titleSpacing: MarketSpacing.screenMargin,
        title: GestureDetector(
          onLongPress: _showSimulationSheet,
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: MarketColors.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(Icons.storefront_rounded, size: 20, color: MarketColors.onPrimaryContainer),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'MARK',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  letterSpacing: -0.5,
                  color: MarketColors.primaryContainer,
                ),
              ),
              const Text(
                'et',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  letterSpacing: -0.5,
                  color: MarketColors.onSurface,
                ),
              ),
            ],
          ),
        ),
        actions: [
          // Non-functional bell icon per spec (no notifications inbox)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.notifications_none_rounded, color: MarketColors.onSurfaceVariant),
              tooltip: 'Notifications',
              onPressed: () {
                // Non-functional per spec: show subtle info
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Hyperlocal promo notifications are delivered directly to your device.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: MarketColors.primary,
          onRefresh: _loadDashboardData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Missing Permissions Banner
                _buildPermissionBanner(),

                // 2. Search Input Bar
                _buildSearchBar(),

                // 3. Category Filter Chips
                _buildCategoryChips(),

                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(child: CircularProgressIndicator(color: MarketColors.primary)),
                  )
                else if (_errorMessage != null)
                  _buildErrorState()
                else ...[
                  // 4. "Businesses for You" Section
                  _buildBusinessesForYouSection(),

                  const SizedBox(height: 24),

                  // 5. "Popular Establishments" Section
                  _buildPopularSection(),

                  const SizedBox(height: 24),

                  // 6. "Featured Promotions" Section
                  _buildFeaturedPromosSection(),

                  const SizedBox(height: 32),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: ShopperBottomNav(
        currentIndex: 0,
        onTap: (idx) {
          if (idx == 1) Navigator.of(context).pushReplacementNamed('/roam');
          if (idx == 2) Navigator.of(context).pushReplacementNamed('/stash');
          if (idx == 3) Navigator.of(context).pushReplacementNamed('/account');
        },
      ),
    );
  }

  Widget _buildPermissionBanner() {
    if (_hasPermissions) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(MarketSpacing.screenMargin, 12, MarketSpacing.screenMargin, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_off_rounded, color: Color(0xFFDC2626), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Background Location & Alerts',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF991B1B),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Required for automatic promo alerts when entering San Jose.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF7F1D1D)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PrimaryButton(
            label: 'Enable',
            height: 36,
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PermissionExplainerScreen()),
              );
              _checkPermissions();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MarketSpacing.screenMargin,
        14,
        MarketSpacing.screenMargin,
        10,
      ),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: MarketColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(MarketRadii.button),
          border: Border.all(color: MarketColors.fieldBorder),
          boxShadow: MarketElevation.level1,
        ),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.search_rounded, color: MarketColors.outline, size: 20),
            ),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                decoration: const InputDecoration(
                  hintText: 'Search businesses, products, or services',
                  hintStyle: TextStyle(fontSize: 13, color: MarketColors.outline),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18, color: MarketColors.outline),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            else
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.tune_rounded, color: MarketColors.outline, size: 20),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: MarketSpacing.screenMargin, vertical: 6),
      child: Row(
        children: _categories.map((c) {
          final isSelected = _selectedCategory == c['slug'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategory = c['slug']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? MarketColors.primaryContainer
                      : MarketColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(MarketRadii.pill),
                  border: Border.all(
                    color: isSelected ? MarketColors.primaryContainer : MarketColors.fieldBorder,
                  ),
                  boxShadow: isSelected ? MarketElevation.level1 : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _getCategoryIcon(c['icon']!, isSelected),
                    const SizedBox(width: 6),
                    Text(
                      c['label']!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected
                            ? MarketColors.onPrimaryContainer
                            : MarketColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _getCategoryIcon(String iconName, bool isSelected) {
    IconData iconData;
    switch (iconName) {
      case 'restaurant':
        iconData = Icons.restaurant_rounded;
        break;
      case 'local_cafe':
        iconData = Icons.local_cafe_rounded;
        break;
      case 'content_cut':
        iconData = Icons.content_cut_rounded;
        break;
      case 'shopping_bag':
        iconData = Icons.shopping_bag_rounded;
        break;
      case 'handyman':
        iconData = Icons.handyman_rounded;
        break;
      case 'local_grocery_store':
        iconData = Icons.local_grocery_store_rounded;
        break;
      case 'spa':
        iconData = Icons.spa_rounded;
        break;
      case 'hotel':
        iconData = Icons.hotel_rounded;
        break;
      default:
        iconData = Icons.apps_rounded;
    }
    return Icon(
      iconData,
      size: 16,
      color: isSelected ? MarketColors.onPrimaryContainer : MarketColors.secondary,
    );
  }

  Widget _buildBusinessesForYouSection() {
    final businesses = _filterBusinessesForYou();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MarketSpacing.screenMargin,
        18,
        MarketSpacing.screenMargin,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Businesses for You',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: MarketColors.onSurface,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Handpicked local Antique MSMEs',
                    style: TextStyle(fontSize: 12, color: MarketColors.secondary),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pushReplacementNamed('/roam'),
                child: const Text(
                  'See All',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: MarketColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (businesses.isEmpty)
            _buildEmptySection(
              icon: Icons.storefront_outlined,
              title: 'No matching businesses',
              subtitle: 'Try selecting another category or adjusting your interests.',
            )
          else
            Column(
              children: businesses.map((b) => _buildBusinessCard(b)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildBusinessCard(Business b) {
    final dist = _getDistanceToBusiness(b);
    final placeholderAsset = 'assets/categories/${b.category}.png';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: MarketColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MarketColors.cardBorder),
        boxShadow: MarketElevation.level1,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => StorefrontScreen(business: b)),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover preview
                SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (b.coverUrl != null && b.coverUrl!.isNotEmpty)
                        Image.network(
                          b.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Image.asset(placeholderAsset, fit: BoxFit.cover),
                        )
                      else
                        Image.asset(placeholderAsset, fit: BoxFit.cover),

                      // Verified MSME Pill
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(MarketRadii.pill),
                            boxShadow: MarketElevation.level1,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.verified_rounded, size: 14, color: MarketColors.primaryContainer),
                              SizedBox(width: 4),
                              Text(
                                'Verified MSME',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: MarketColors.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Distance Badge
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: MarketColors.inverseSurface.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.near_me_rounded, size: 11, color: MarketColors.inverseOnSurface),
                              const SizedBox(width: 3),
                              Text(
                                _formatDistance(dist),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: MarketColors.inverseOnSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Details
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              b.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: MarketColors.onSurface,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: MarketColors.surfaceContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              categoryLabels[b.category] ?? b.category,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: MarketColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (b.bio != null && b.bio!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          b.bio!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: MarketColors.secondary, height: 1.3),
                        ),
                      ],
                      const SizedBox(height: 10),
                      const Divider(height: 1, color: MarketColors.fieldBorder),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.star_rounded, size: 16, color: MarketColors.warning),
                              SizedBox(width: 3),
                              Text(
                                '4.9',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: MarketColors.onSurface),
                              ),
                              SizedBox(width: 3),
                              Text(
                                '(84 reviews)',
                                style: TextStyle(fontSize: 11, color: MarketColors.secondary),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => StorefrontScreen(business: b)),
                              );
                            },
                            icon: const Text(
                              'Explore Menu',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: MarketColors.primary),
                            ),
                            label: const Icon(Icons.arrow_forward_rounded, size: 14, color: MarketColors.primary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPopularSection() {
    final businesses = _filterPopularBusinesses();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MarketSpacing.screenMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Popular Establishments',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: MarketColors.onSurface,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Frequently visited around the municipality',
                    style: TextStyle(fontSize: 12, color: MarketColors.secondary),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pushReplacementNamed('/roam'),
                child: const Text(
                  'View Map',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: MarketColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (businesses.isEmpty)
            _buildEmptySection(
              icon: Icons.place_outlined,
              title: 'No establishments found',
              subtitle: 'Explore other categories in San Jose.',
            )
          else
            Column(
              children: businesses.take(4).map((b) => _buildPopularCard(b)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildPopularCard(Business b) {
    final placeholderAsset = 'assets/categories/${b.category}.png';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: MarketColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MarketColors.cardBorder),
        boxShadow: MarketElevation.level1,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 64,
              height: 64,
              child: b.coverUrl != null && b.coverUrl!.isNotEmpty
                  ? Image.network(
                      b.coverUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Image.asset(placeholderAsset, fit: BoxFit.cover),
                    )
                  : Image.asset(placeholderAsset, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  categoryLabels[b.category] ?? b.category,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: MarketColors.primary,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  b.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MarketColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, size: 12, color: MarketColors.outline),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        b.address ?? 'San Jose, Antique',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: MarketColors.secondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SecondaryButton(
            height: 36,
            label: 'View',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => StorefrontScreen(business: b)),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedPromosSection() {
    final promos = _filterFeaturedPromos();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: MarketSpacing.screenMargin),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Featured Promotions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: MarketColors.onSurface,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Exclusive deals from participating MSMEs',
                    style: TextStyle(fontSize: 12, color: MarketColors.secondary),
                  ),
                ],
              ),
              const Icon(Icons.local_offer_rounded, color: MarketColors.primaryContainer, size: 22),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (promos.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MarketSpacing.screenMargin),
            child: _buildEmptySection(
              icon: Icons.local_offer_outlined,
              title: 'No active promotions',
              subtitle: 'Check back soon for new discounts and BOGO offers.',
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: MarketSpacing.screenMargin),
            child: Row(
              children: promos.map((p) => _buildPromoCarouselCard(p)).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildPromoCarouselCard(Promo p) {
    final isSaved = _savedPromoIds.contains(p.id);

    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 14),
      decoration: BoxDecoration(
        color: MarketColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MarketColors.cardBorder),
        boxShadow: MarketElevation.level1,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PromoDetailScreen(promo: p, fromNotification: false),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Promo badge header
                Container(
                  height: 100,
                  width: double.infinity,
                  color: const Color(0xFFE0F2FE),
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(Icons.local_offer_rounded, size: 40, color: MarketColors.primary.withValues(alpha: 0.3)),
                      ),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: MarketColors.primaryContainer,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: MarketElevation.level1,
                          ),
                          child: Text(
                            p.promoType.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: MarketColors.onPrimaryContainer,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: MarketColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        p.valueLabel ?? p.promoType.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: MarketColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.event_rounded, size: 12, color: MarketColors.outline),
                          const SizedBox(width: 4),
                          Text(
                            'Valid until ${p.endsAt.month}/${p.endsAt.day}',
                            style: const TextStyle(fontSize: 11, color: MarketColors.secondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: PrimaryButton(
                              height: 38,
                              label: 'Get Voucher',
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => VoucherScreen(promo: p)),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: isSaved
                                  ? MarketColors.primaryContainer.withValues(alpha: 0.2)
                                  : MarketColors.surfaceContainerLowest,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: isSaved ? MarketColors.primaryContainer : MarketColors.fieldBorder,
                                ),
                              ),
                            ),
                            icon: Icon(
                              isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                              size: 18,
                              color: isSaved ? MarketColors.primary : MarketColors.secondary,
                            ),
                            tooltip: isSaved ? 'Remove from Stash' : 'Save to Stash',
                            onPressed: () => _toggleStash(p),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySection({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: MarketColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MarketColors.cardBorder),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: MarketColors.outline),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: MarketColors.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: MarketColors.secondary),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(MarketSpacing.screenMargin),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: MarketColors.errorContainer.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MarketColors.error.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded, size: 36, color: MarketColors.error),
            const SizedBox(height: 10),
            Text(
              _errorMessage ?? 'Unable to load dashboard',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: MarketColors.error, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            PrimaryButton(
              label: 'Retry',
              height: 40,
              onPressed: _loadDashboardData,
            ),
          ],
        ),
      ),
    );
  }
}
