import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/promo.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_header.dart';
import '../../widgets/promo_photo_view.dart';
import 'redeem_store_screen.dart';

/// StashScreen displays saved promotions organized by status tabs:
/// All, Active, Expiring Soon, and Expired.
class StashScreen extends StatefulWidget {
  final List<Promo>? initialStash;

  const StashScreen({
    super.key,
    this.initialStash,
  });

  @override
  State<StashScreen> createState() => _StashScreenState();
}

class _StashScreenState extends State<StashScreen> {
  final AuthService _authService = AuthService();
  final DataService _dataService = DataService();

  List<Promo> _allStash = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _activeTab = 'all'; // 'all', 'active', 'expiring', 'expired'

  @override
  void initState() {
    super.initState();
    if (widget.initialStash != null) {
      _allStash = List.from(widget.initialStash!);
      _isLoading = false;
    } else {
      _loadStash();
    }
  }

  Future<void> _loadStash() async {
    final uid = _authService.currentUserId;
    if (uid == null) {
      setState(() {
        _errorMessage = 'Please sign in to view saved promotions.';
        _isLoading = false;
      });
      return;
    }

    try {
      final list = await _dataService.fetchStash(uid);
      if (mounted) {
        setState(() {
          _allStash = list;
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

  Future<void> _removePromo(Promo p) async {
    final uid = _authService.currentUserId;
    if (uid == null) return;

    try {
      await _dataService.removeFromStash(uid, p.id);
      setState(() {
        _allStash.removeWhere((item) => item.id == p.id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed from Stash.')),
        );
      }
    } catch (_) {}
  }

  List<Promo> get _filteredPromos {
    final now = DateTime.now().toUtc();
    switch (_activeTab) {
      case 'active':
        return _allStash.where((p) => p.isCurrentlyValid).toList();
      case 'expiring':
        return _allStash.where((p) {
          if (!p.isCurrentlyValid) return false;
          return p.endsAt.difference(now).inDays <= 2;
        }).toList();
      case 'expired':
        return _allStash.where((p) => !p.isCurrentlyValid).toList();
      default:
        return _allStash;
    }
  }

  @override
  Widget build(BuildContext context) {
    final promos = _filteredPromos;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        Navigator.of(context).pushReplacementNamed('/shopper-home');
      },
      child: Scaffold(
        backgroundColor: MarketColors.surface,
        appBar: const AppHeader(
          showBack: false,
          subtitle: 'Stash',
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Status Filter Tabs
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: MarketSpacing.screenMargin,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    _buildTabChip('all', 'All Saved', _allStash.length),
                    const SizedBox(width: 8),
                    _buildTabChip(
                      'active',
                      'Active',
                      _allStash.where((p) => p.isCurrentlyValid).length,
                    ),
                    const SizedBox(width: 8),
                    _buildTabChip(
                      'expiring',
                      'Expiring Soon',
                      _allStash.where((p) => p.isCurrentlyValid && p.endsAt.difference(DateTime.now().toUtc()).inDays <= 2).length,
                    ),
                    const SizedBox(width: 8),
                    _buildTabChip(
                      'expired',
                      'Expired',
                      _allStash.where((p) => !p.isCurrentlyValid).length,
                    ),
                  ],
                ),
              ),

              // Main Content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                        ? Center(child: Text(_errorMessage!))
                        : promos.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  MarketSpacing.screenMargin,
                                  MarketSpacing.screenMargin,
                                  MarketSpacing.screenMargin,
                                  88,
                                ),
                                itemCount: promos.length,
                                itemBuilder: (context, index) {
                                  return _buildStashCard(promos[index]);
                                },
                              ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: AppBottomNav(
          currentIndex: 2,
          role: AppNavRole.shopper,
          onTap: (idx) {
            if (idx == 0) Navigator.of(context).pushReplacementNamed('/shopper-home');
            if (idx == 1) Navigator.of(context).pushReplacementNamed('/roam');
            if (idx == 3) Navigator.of(context).pushReplacementNamed('/account');
          },
        ),
      ),
    );
  }

  Widget _buildTabChip(String tabId, String label, int count) {
    final isSelected = _activeTab == tabId;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = tabId),
      child: Container(
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
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? MarketColors.onPrimaryContainer : MarketColors.secondary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.8)
                    : MarketColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? MarketColors.primary : MarketColors.secondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MarketSpacing.screenMargin),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: MarketColors.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bookmark_border_rounded,
                size: 36,
                color: MarketColors.outline,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Saved Deals Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: MarketColors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Browse the Dashboard or Roam map to discover and save exclusive MSME promos.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: MarketColors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Explore Dashboard',
              onPressed: () {
                Navigator.of(context).pushReplacementNamed('/shopper-home');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStashCard(Promo p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MarketColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MarketColors.cardBorder),
        boxShadow: MarketElevation.level1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: PromoPhotoView(
                    promoImageUrl: p.imageUrl,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: MarketColors.primaryContainer.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            p.valueLabel ?? p.promoType.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: MarketColors.primary,
                            ),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.bookmark_remove_outlined, size: 20, color: MarketColors.outline),
                          tooltip: 'Remove',
                          onPressed: () => _removePromo(p),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      p.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: MarketColors.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (p.description != null && p.description!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        p.description!,
                        style: const TextStyle(fontSize: 12, color: MarketColors.onSurfaceVariant),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: const Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 12),
          // Validity text on its own line with ellipsis
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 14, color: MarketColors.outline),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Valid until ${_formatDate(p.endsAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: MarketColors.secondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Single full-width Redeem button
          PrimaryButton(
            width: double.infinity,
            height: 44,
            label: 'Redeem at store',
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
            onPressed: () async {
              final res = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => RedeemStoreScreen(promo: p),
                ),
              );
              if (res == true) {
                _loadStash();
              }
            },
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.month}/${local.day}/${local.year}';
  }
}
