import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../services/geofence_service.dart';
import '../../widgets/app_buttons.dart';

/// InterestSelectionScreen matching market_consumer_interest_selection_mobile.
/// Allows selecting from the 8 canonical categories, saving to profiles.interests,
/// or skipping for now.
class InterestsScreen extends StatefulWidget {
  const InterestsScreen({super.key});

  @override
  State<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends State<InterestsScreen> {
  final AuthService _authService = AuthService();

  // Pre-select popular default categories ('food', 'cafe') matching Stitch frame
  final Set<String> _selectedSlugs = {'food', 'cafe'};
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadExistingInterests();
  }

  Future<void> _loadExistingInterests() async {
    try {
      final profile = await _authService.fetchCurrentProfile();
      if (profile != null && profile.interests.isNotEmpty && mounted) {
        setState(() {
          _selectedSlugs.clear();
          _selectedSlugs.addAll(profile.interests);
        });
      }
    } catch (_) {
      // Keep defaults on fetch error
    }
  }

  void _toggleSlug(String slug) {
    setState(() {
      if (_selectedSlugs.contains(slug)) {
        _selectedSlugs.remove(slug);
      } else {
        _selectedSlugs.add(slug);
      }
    });
  }

  Future<void> _onContinue() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await _authService.updateInterests(_selectedSlugs.toList());
      final locInUse = await Permission.locationWhenInUse.isGranted;
      final locAlways = await Permission.locationAlways.isGranted;
      final notif = await Permission.notification.isGranted;
      if (!mounted) return;
      if (!locInUse || !locAlways || !notif) {
        Navigator.of(context).pushReplacementNamed('/permission-explainer');
      } else {
        await GeofenceService.instance.start();
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/shopper-home');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _onSkip() async {
    final locInUse = await Permission.locationWhenInUse.isGranted;
    final locAlways = await Permission.locationAlways.isGranted;
    final notif = await Permission.notification.isGranted;
    if (!mounted) return;
    if (!locInUse || !locAlways || !notif) {
      Navigator.of(context).pushReplacementNamed('/permission-explainer');
    } else {
      await GeofenceService.instance.start();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/shopper-home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesData = [
      const _CategoryItem(
        slug: 'food',
        title: 'Food & Restaurants',
        subtitle: 'Diners, bistros & native food',
        icon: Icons.restaurant_rounded,
      ),
      const _CategoryItem(
        slug: 'cafe',
        title: 'Cafés',
        subtitle: 'Coffee, tea & bakeries',
        icon: Icons.local_cafe_rounded,
      ),
      const _CategoryItem(
        slug: 'salon',
        title: 'Salons & Barbershops',
        subtitle: 'Hair, nails & styling',
        icon: Icons.content_cut_rounded,
      ),
      const _CategoryItem(
        slug: 'retail',
        title: 'Retail & Shopping',
        subtitle: 'Apparel, crafts & gifts',
        icon: Icons.shopping_bag_outlined,
      ),
      const _CategoryItem(
        slug: 'grocery',
        title: 'Groceries & Marts',
        subtitle: 'Sari-sari, snacks & fresh',
        icon: Icons.local_grocery_store_outlined,
      ),
      const _CategoryItem(
        slug: 'wellness',
        title: 'Health & Wellness',
        subtitle: 'Spas, gyms & pharmacies',
        icon: Icons.spa_outlined,
      ),
      const _CategoryItem(
        slug: 'services',
        title: 'Services',
        subtitle: 'Repair, laundry & print',
        icon: Icons.build_outlined,
      ),
      const _CategoryItem(
        slug: 'travel',
        title: 'Travel & Stays',
        subtitle: 'Inns, resorts & tour stays',
        icon: Icons.hotel_outlined,
      ),
    ];

    return Scaffold(
      backgroundColor: MarketColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Header Section
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MarketSpacing.screenMargin,
                20,
                MarketSpacing.screenMargin,
                12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'What are your interests?',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: MarketColors.onSurface,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: MarketColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(MarketRadii.pill),
                          border: Border.all(
                            color: MarketColors.primaryContainer.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          '${_selectedSlugs.length} selected',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: MarketColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Select categories to get personalized MSME promo notifications and local recommendations in San Jose.',
                    style: TextStyle(
                      fontSize: 13,
                      color: MarketColors.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            if (_errorMessage != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: MarketSpacing.screenMargin),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: MarketColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(fontSize: 12, color: MarketColors.error),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // 2-Column Grid of 8 Canonical Categories
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: MarketSpacing.screenMargin,
                  vertical: 8,
                ),
                itemCount: categoriesData.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.15,
                ),
                itemBuilder: (context, index) {
                  final item = categoriesData[index];
                  final isSelected = _selectedSlugs.contains(item.slug);

                  return _buildCategoryCard(
                    item: item,
                    isSelected: isSelected,
                    onTap: () => _toggleSlug(item.slug),
                  );
                },
              ),
            ),

            // Bottom Actions Container
            Container(
              padding: const EdgeInsets.fromLTRB(
                MarketSpacing.screenMargin,
                14,
                MarketSpacing.screenMargin,
                16,
              ),
              decoration: BoxDecoration(
                color: MarketColors.surface,
                border: Border(
                  top: BorderSide(
                    color: MarketColors.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PrimaryButton(
                    width: double.infinity,
                    height: 50,
                    label: 'Continue to Dashboard',
                    icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                    isLoading: _isSaving,
                    onPressed: _onContinue,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: _isSaving ? null : _onSkip,
                    child: const Text(
                      'Skip for now',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: MarketColors.secondary,
                      ),
                    ),
                  ),
                  const Text(
                    'You can update your interests anytime in Account & Preferences.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: MarketColors.outline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard({
    required _CategoryItem item,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? MarketColors.surfaceContainerLow
              : MarketColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? MarketColors.primaryContainer
                : const Color(0xFFE2E8F0),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected ? MarketElevation.level2 : MarketElevation.level1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row: Icon container + Checkbox indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? MarketColors.primaryContainer
                        : MarketColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item.icon,
                    size: 20,
                    color: isSelected
                        ? MarketColors.onSurface
                        : MarketColors.primary,
                  ),
                ),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? MarketColors.primaryContainer
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? MarketColors.primaryContainer
                          : const Color(0xFFCBD5E1),
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: MarketColors.onSurface,
                        )
                      : null,
                ),
              ],
            ),

            // Bottom texts
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MarketColors.onSurface,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    color: MarketColors.secondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryItem {
  final String slug;
  final String title;
  final String subtitle;
  final IconData icon;

  const _CategoryItem({
    required this.slug,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}
