import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/business.dart';
import '../../models/promo.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/merchant_bottom_nav.dart';
import 'account_screen.dart';
import 'analytics_screen.dart';
import 'catalog_screen.dart';
import 'dashboard_screen.dart';
import 'scan_screen.dart';

/// MSME Merchant Promotions Catalog Screen
/// Matches Stitch frame: market_tab_2_promotions_catalog
class MerchantPromotionsScreen extends StatefulWidget {
  final Business? business;

  const MerchantPromotionsScreen({
    super.key,
    this.business,
  });

  @override
  State<MerchantPromotionsScreen> createState() => _MerchantPromotionsScreenState();
}

class _MerchantPromotionsScreenState extends State<MerchantPromotionsScreen> {
  final AuthService _authService = AuthService();
  final DataService _dataService = DataService();

  Business? _business;
  List<Promo> _promos = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _business = widget.business;
    _loadPromotions();
  }

  Future<void> _loadPromotions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_business == null) {
        final uid = _authService.currentUserId;
        if (uid != null) {
          _business = await _dataService.fetchMerchantBusiness(uid);
        }
      }


      if (_business != null) {
        _promos = await _dataService.fetchPromosForBusiness(_business!.id);
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<Promo> get _filteredPromos {
    final now = DateTime.now().toUtc();
    if (_selectedFilter == 'Active') {
      return _promos.where((p) => p.active && (now.isAfter(p.startsAt) || now.isAtSameMomentAs(p.startsAt)) && now.isBefore(p.endsAt)).toList();
    } else if (_selectedFilter == 'Scheduled') {
      return _promos.where((p) => p.active && now.isBefore(p.startsAt)).toList();
    } else if (_selectedFilter == 'Expired') {
      return _promos.where((p) => !p.active || now.isAfter(p.endsAt) || now.isAtSameMomentAs(p.endsAt)).toList();
    }
    return _promos;
  }

  void _onBottomNavTapped(int index) {
    if (index == 1) return; // Catalog / Promos
    if (index == 0) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MerchantDashboardScreen(business: _business),
        ),
      );
    } else if (index == 2) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MerchantAnalyticsScreen(business: _business),
        ),
      );
    } else if (index == 3) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MerchantAccountScreen(business: _business),
        ),
      );
    }
  }

  void _openScanScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MerchantScanScreen(business: _business),
      ),
    );
  }


  void _openCreatePromoModal() {
    final titleCtrl = TextEditingController();
    final valueCtrl = TextEditingController(text: '20% OFF');
    final descCtrl = TextEditingController();
    final limitCtrl = TextEditingController(text: '100');
    String promoType = 'percent';
    int durationDays = 7;
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: MarketColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: MarketColors.outlineVariant,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Create New Promo',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: MarketColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Title
                      AppTextField(
                        controller: titleCtrl,
                        label: 'Promo Title *',
                        hintText: 'e.g. Morning Coffee Hour',
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                      ),
                      const SizedBox(height: 12),

                      // Promo Type Dropdown & Value Label
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Promo Type',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: MarketColors.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: MarketColors.surfaceContainerLowest,
                                    borderRadius: BorderRadius.circular(MarketRadii.input),
                                    border: Border.all(color: MarketColors.fieldBorder),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: promoType,
                                      isExpanded: true,
                                      items: const [
                                        DropdownMenuItem(value: 'percent', child: Text('Percent Off')),
                                        DropdownMenuItem(value: 'bogo', child: Text('BOGO (Buy 1 Take 1)')),
                                        DropdownMenuItem(value: 'amount_off', child: Text('Amount Off (₱)')),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setModalState(() {
                                            promoType = val;
                                            if (val == 'bogo') valueCtrl.text = 'BOGO';
                                            if (val == 'percent') valueCtrl.text = '20% OFF';
                                            if (val == 'amount_off') valueCtrl.text = '₱50 OFF';
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppTextField(
                              controller: valueCtrl,
                              label: 'Value Tag',
                              hintText: 'e.g. 20% OFF',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Description
                      AppTextField(
                        controller: descCtrl,
                        label: 'Description',
                        hintText: 'Includes any signature coffee & pastry...',
                      ),
                      const SizedBox(height: 12),

                      // Redeem Limit & Duration
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: limitCtrl,
                              label: 'Voucher Limit',
                              hintText: '100',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Duration',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: MarketColors.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: MarketColors.surfaceContainerLowest,
                                    borderRadius: BorderRadius.circular(MarketRadii.input),
                                    border: Border.all(color: MarketColors.fieldBorder),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: durationDays,
                                      isExpanded: true,
                                      items: const [
                                        DropdownMenuItem(value: 3, child: Text('3 Days')),
                                        DropdownMenuItem(value: 7, child: Text('7 Days')),
                                        DropdownMenuItem(value: 14, child: Text('14 Days')),
                                        DropdownMenuItem(value: 30, child: Text('30 Days')),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setModalState(() => durationDays = val);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Submit Button
                      PrimaryButton(
                        width: double.infinity,
                        height: 50,
                        label: isSaving ? 'Publishing Promo...' : 'Publish Promotion',
                        isLoading: isSaving,
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setModalState(() => isSaving = true);

                                try {
                                  final bizId = _business?.id;
                                  if (bizId == null) {
                                    throw Exception('No business found. Please register your business.');
                                  }
                                  final limitVal = int.tryParse(limitCtrl.text.trim()) ?? 100;
                                  final localNow = DateTime.now();
                                  final startsAt = DateTime.now().toUtc();
                                  final localExpiryDate = localNow.add(Duration(days: durationDays));
                                  final localEndsAt = DateTime(
                                    localExpiryDate.year,
                                    localExpiryDate.month,
                                    localExpiryDate.day,
                                    23,
                                    59,
                                    59,
                                  );
                                  final endsAt = localEndsAt.toUtc();

                                  final newPromo = Promo(
                                    id: '',
                                    businessId: bizId,
                                    title: titleCtrl.text.trim(),
                                    description: descCtrl.text.trim(),
                                    promoType: promoType,
                                    valueLabel: valueCtrl.text.trim(),
                                    startsAt: startsAt,
                                    endsAt: endsAt,
                                    redeemLimit: limitVal,
                                    redeemedCount: 0,
                                    active: true,
                                    createdAt: startsAt,
                                  );

                                  await _dataService.createPromo(newPromo);

                                  if (modalContext.mounted) {
                                    Navigator.of(modalContext).pop();
                                  }
                                  await _loadPromotions();
                                } catch (e) {
                                  setModalState(() => isSaving = false);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error creating promo: $e')),
                                    );
                                  }
                                }
                              },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarketColors.surface,
      appBar: AppBar(
        backgroundColor: MarketColors.surface,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: MarketColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text(
                'M',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: MarketColors.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 8),
            RichText(
              text: const TextSpan(
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
                children: [
                  TextSpan(
                    text: 'MARK',
                    style: TextStyle(color: MarketColors.primaryContainer),
                  ),
                  TextSpan(
                    text: 'et',
                    style: TextStyle(color: MarketColors.onSurface),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded,
                color: MarketColors.primary),
            onPressed: _openScanScreen,
            tooltip: 'Scan QR Code',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Toggle Pill (Products & Services vs Promotions)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MarketSpacing.screenMargin,
                vertical: 8,
              ),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: MarketColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: MarketColors.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => MerchantCatalogScreen(business: _business),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          child: const Text(
                            'Products & Services',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: MarketColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: MarketColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0A0F172A),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Promotions (${_promos.length})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: MarketColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Status Filter Chips
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: MarketSpacing.screenMargin),
                children: ['All', 'Active', 'Scheduled', 'Expired'].map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (val) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      },
                      selectedColor: MarketColors.primaryContainer,
                      backgroundColor: MarketColors.surfaceContainerLowest,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? MarketColors.onSurface : MarketColors.onSurfaceVariant,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),

            // Promotions List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_errorMessage!),
                              ElevatedButton(
                                onPressed: _loadPromotions,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _filteredPromos.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.campaign_outlined,
                                        size: 48, color: MarketColors.outline),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'No promotions in this category',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: MarketColors.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Create a flash deal or discount to notify nearby shoppers.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: MarketColors.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: MarketColors.primaryContainer,
                                        foregroundColor: MarketColors.onSurface,
                                      ),
                                      icon: const Icon(Icons.add, size: 18),
                                      label: const Text('New Promo'),
                                      onPressed: _openCreatePromoModal,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: MarketSpacing.screenMargin,
                                vertical: 8,
                              ),
                              itemCount: _filteredPromos.length,
                              itemBuilder: (context, index) {
                                final promo = _filteredPromos[index];
                                return _buildPromoCard(promo);
                              },
                            ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: MarketColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'New Promo',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        onPressed: _openCreatePromoModal,
      ),
      bottomNavigationBar: MerchantBottomNav(
        currentIndex: 1,
        onTap: _onBottomNavTapped,
      ),
    );
  }

  Widget _buildPromoCard(Promo promo) {
    final valueLabel = promo.valueLabel ??
        (promo.promoType == 'bogo' ? 'BOGO' : 'DEAL');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MarketColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: MarketColors.outlineVariant.withValues(alpha: 0.3),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            offset: Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge icon box
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF8FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                alignment: Alignment.center,
                child: Text(
                  valueLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0284C7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      promo.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: MarketColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${promo.redeemedCount} / ${promo.redeemLimit} redeemed • Ends ${_formatDate(promo.endsAt)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: MarketColors.outline,
                      ),
                    ),
                    if (promo.description != null && promo.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        promo.description!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: MarketColors.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Bottom Controls: Active state + "Scan QR" CTA
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: promo.active ? const Color(0xFF16A34A) : MarketColors.outline,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    promo.active ? 'Active' : 'Inactive',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: promo.active ? const Color(0xFF16A34A) : MarketColors.outline,
                    ),
                  ),
                ],
              ),

              // Scan QR button per Phase 5a specs
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: MarketColors.surfaceContainerLow,
                  foregroundColor: MarketColors.primary,
                  elevation: 0,
                  side: BorderSide(
                    color: MarketColors.primaryContainer.withValues(alpha: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                label: const Text(
                  'Scan QR',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                onPressed: _openScanScreen,
              ),
            ],
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
