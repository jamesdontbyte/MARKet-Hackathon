import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/business.dart';
import '../../models/product.dart';
import '../../models/promo.dart';
import '../../models/scanned_menu_item.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/promo_photo_view.dart';
import 'account_screen.dart';
import 'analytics_screen.dart';
import 'dashboard_screen.dart';
import 'scan_menu_review_screen.dart';
import 'scan_menu_sheet.dart';
import 'store_qr_screen.dart';

class PromoDraft {
  final String title;
  final String description;
  final String promoType;
  final String? valueLabel;
  final DateTime startsAt;
  final DateTime endsAt;
  final int redeemLimit;

  const PromoDraft({
    required this.title,
    required this.description,
    required this.promoType,
    this.valueLabel,
    required this.startsAt,
    required this.endsAt,
    required this.redeemLimit,
  });
}

class ProductDraft {
  final String name;
  final double price;
  final String category;
  final String description;

  const ProductDraft({
    required this.name,
    required this.price,
    required this.category,
    required this.description,
  });
}

/// MSME Merchant Catalog Screen (Products & Services and Promotions)
/// Conforms to specs 11, 12, 13, 14, 15, 16.
class MerchantCatalogScreen extends StatefulWidget {
  final Business? business;
  final int initialTab;
  final PromoDraft? initialPromoDraft;
  final ProductDraft? initialProductDraft;

  const MerchantCatalogScreen({
    super.key,
    this.business,
    this.initialTab = 0,
    this.initialPromoDraft,
    this.initialProductDraft,
  });

  @override
  State<MerchantCatalogScreen> createState() => _MerchantCatalogScreenState();
}

class _MerchantCatalogScreenState extends State<MerchantCatalogScreen> {
  final AuthService _authService = AuthService();
  final DataService _dataService = DataService();

  Business? _business;
  List<Product> _products = [];
  List<Promo> _promos = [];
  bool _isLoading = false;
  String? _errorMessage;

  late int _selectedSegment; // 0: Products & Services, 1: Promotions
  String _selectedCategoryFilter = 'All';

  @override
  void initState() {
    super.initState();
    _business = widget.business;
    _selectedSegment = widget.initialTab;
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    try {
      if (_business == null) {
        final uid = _authService.currentUserId;
        if (uid != null) {
          _business = await _dataService.fetchMerchantBusiness(uid);
        }
      }

      if (_business != null) {
        final prods = await _dataService.fetchProducts(_business!.id);
        final prms = await _dataService.fetchPromosForBusiness(_business!.id);
        if (mounted) {
          setState(() {
            _products = prods;
            _promos = prms;
            _isLoading = false;
          });

          if (widget.initialPromoDraft != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() => _selectedSegment = 1);
                _openAddOrEditPromoModal(null, widget.initialPromoDraft);
              }
            });
          } else if (widget.initialProductDraft != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() => _selectedSegment = 0);
                _openAddOrEditItemModal(null, widget.initialProductDraft);
              }
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<String> get _dynamicCategories {
    final cats = _products
        .map((p) => (p.category ?? '').trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['All', ...cats];
  }

  List<Product> get _filteredProducts {
    if (_selectedCategoryFilter == 'All') return _products;
    return _products
        .where((p) =>
            (p.category ?? '').trim().toLowerCase() ==
            _selectedCategoryFilter.trim().toLowerCase())
        .toList();
  }

  void _onBottomNavTapped(int index) {
    if (index == 1) return; // Already on Catalog
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

  // -------------------------------------------------------------
  // Product Helpers & Actions
  // -------------------------------------------------------------

  Future<void> _toggleBestSeller(Product p) async {
    try {
      final updated = p.copyWith(isBestSeller: !p.isBestSeller);
      await _dataService.updateProduct(updated);
      setState(() {
        final idx = _products.indexWhere((item) => item.id == p.id);
        if (idx != -1) _products[idx] = updated;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    }
  }

  Future<void> _toggleAvailability(Product p) async {
    try {
      final updated = p.copyWith(available: !p.available);
      await _dataService.updateProduct(updated);
      setState(() {
        final idx = _products.indexWhere((item) => item.id == p.id);
        if (idx != -1) _products[idx] = updated;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    }
  }

  Future<void> _deleteProduct(Product p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Remove "${p.name}" from your catalog?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: MarketColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _dataService.deleteProduct(p.id);
        setState(() {
          _products.removeWhere((item) => item.id == p.id);
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }

  Future<void> _openScanMenuSheet() async {
    if (_business == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No registered business found.')),
      );
      return;
    }

    final scanResult = await showModalBottomSheet<ScanMenuResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ScanMenuSheet(business: _business!),
    );

    if (scanResult != null && scanResult.items.isNotEmpty && mounted) {
      final addedCount = await Navigator.of(context).push<int>(
        MaterialPageRoute(
          builder: (_) => ScanMenuReviewScreen(
            business: _business!,
            existingProducts: _products,
            scannedItems: scanResult.items,
            dataService: _dataService,
          ),
        ),
      );

      if (addedCount != null && addedCount > 0 && mounted) {
        await _loadAllData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                addedCount == 1
                    ? 'Added 1 item to catalog'
                    : 'Added $addedCount items to catalog',
              ),
              backgroundColor: MarketColors.primary,
            ),
          );
        }
      }
    }
  }

  void _openAddOrEditItemModal([Product? existingProduct, ProductDraft? productDraft]) {
    final isEditing = existingProduct != null;
    final nameCtrl = TextEditingController(text: existingProduct?.name ?? productDraft?.name ?? '');
    final priceCtrl = TextEditingController(
      text: existingProduct != null
          ? existingProduct.price.toStringAsFixed(0)
          : (productDraft != null ? productDraft.price.toStringAsFixed(0) : ''),
    );
    final catCtrl = TextEditingController(text: existingProduct?.category ?? productDraft?.category ?? '');
    final descCtrl = TextEditingController(text: existingProduct?.description ?? productDraft?.description ?? '');
    final formKey = GlobalKey<FormState>();

    bool isBestSeller = existingProduct?.isBestSeller ?? false;
    bool isAvailable = existingProduct?.available ?? true;
    String? currentImageUrl = existingProduct?.imageUrl;
    Uint8List? pickedFileBytes;
    String? pickedFileName;
    bool isSaving = false;
    String? modalError;

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
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(modalContext).size.height * 0.9,
                ),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                decoration: const BoxDecoration(
                  color: MarketColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
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
                        Text(
                          isEditing ? 'Edit Item' : 'Add Item',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: MarketColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),

                        if (modalError != null) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: MarketColors.errorContainer.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              modalError!,
                              style: const TextStyle(color: MarketColors.error, fontSize: 12),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Photo Picker Tile (max 5 MB)
                        GestureDetector(
                          onTap: () async {
                            final res = await FilePicker.platform.pickFiles(
                              type: FileType.image,
                              withData: true,
                            );
                            if (res != null && res.files.isNotEmpty) {
                              final f = res.files.first;
                              if (f.size > 5 * 1024 * 1024) {
                                setModalState(() {
                                  modalError = 'Photo exceeds 5 MB limit. Please select a smaller image.';
                                });
                                return;
                              }
                              setModalState(() {
                                modalError = null;
                                pickedFileBytes = f.bytes;
                                pickedFileName = f.name;
                              });
                            }
                          },
                          child: Container(
                            height: 100,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: MarketColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: MarketColors.cardBorder),
                            ),
                            child: pickedFileBytes != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.memory(
                                      pickedFileBytes!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : (currentImageUrl != null && currentImageUrl.isNotEmpty)
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: Image.network(
                                          currentImageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => const Center(
                                            child: Icon(Icons.broken_image_rounded, color: MarketColors.outline),
                                          ),
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: const [
                                          Icon(Icons.add_a_photo_outlined, color: MarketColors.primary, size: 24),
                                          SizedBox(width: 8),
                                          Text(
                                            'Select Photo (Max 5 MB)',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: MarketColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Name
                        AppTextField(
                          controller: nameCtrl,
                          label: 'Item Name *',
                          hintText: 'e.g. Garlic Fried Rice',
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Item name required' : null,
                        ),
                        const SizedBox(height: 12),

                        // Price (Pesos) & Category
                        Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: priceCtrl,
                                label: 'Price (₱) *',
                                hintText: '150',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Price required';
                                  final numVal = double.tryParse(v.trim());
                                  if (numVal == null || numVal < 0) return 'Valid price required';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AppTextField(
                                controller: catCtrl,
                                label: 'Category',
                                hintText: 'Food, Beverages...',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Description
                        AppTextField(
                          controller: descCtrl,
                          label: 'Short Description',
                          hintText: 'Freshly prepared daily with local Antique garlic...',
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),

                        // Best Seller Toggle
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Best Seller',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          subtitle: const Text(
                            'Highlight on storefront as top recommendation',
                            style: TextStyle(fontSize: 11, color: MarketColors.secondary),
                          ),
                          value: isBestSeller,
                          activeThumbColor: MarketColors.primary,
                          onChanged: (val) => setModalState(() => isBestSeller = val),
                        ),

                        // Available Toggle
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Available to Shoppers',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          subtitle: const Text(
                            'Hidden items do not display on customer discovery',
                            style: TextStyle(fontSize: 11, color: MarketColors.secondary),
                          ),
                          value: isAvailable,
                          activeThumbColor: MarketColors.primary,
                          onChanged: (val) => setModalState(() => isAvailable = val),
                        ),
                        const SizedBox(height: 16),

                        // Save Button
                        PrimaryButton(
                          width: double.infinity,
                          height: 48,
                          label: isSaving
                              ? 'Saving...'
                              : (isEditing ? 'Update Item' : 'Add Item'),
                          isLoading: isSaving,
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setModalState(() {
                                    isSaving = true;
                                    modalError = null;
                                  });

                                  try {
                                    final bizId = _business?.id;
                                    if (bizId == null) {
                                      throw Exception('No registered business found.');
                                    }

                                    String? finalImageUrl = currentImageUrl;
                                    if (pickedFileBytes != null && pickedFileName != null) {
                                      final uid = _authService.currentUserId ?? _business?.ownerId ?? 'merchant';
                                      finalImageUrl = await _dataService.uploadProductImage(
                                        ownerId: uid,
                                        fileName: '${DateTime.now().millisecondsSinceEpoch}_$pickedFileName',
                                        fileBytes: pickedFileBytes!,
                                      );
                                    }

                                    final priceVal = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                                    final catVal = catCtrl.text.trim().isNotEmpty ? catCtrl.text.trim() : 'General';

                                    if (isEditing) {
                                      final updated = existingProduct.copyWith(
                                        name: nameCtrl.text.trim(),
                                        price: priceVal,
                                        category: catVal,
                                        description: descCtrl.text.trim(),
                                        imageUrl: finalImageUrl,
                                        isBestSeller: isBestSeller,
                                        available: isAvailable,
                                      );
                                      await _dataService.updateProduct(updated);
                                      setState(() {
                                        final idx = _products.indexWhere((item) => item.id == existingProduct.id);
                                        if (idx != -1) _products[idx] = updated;
                                      });
                                    } else {
                                      final newProd = Product(
                                        id: '',
                                        businessId: bizId,
                                        name: nameCtrl.text.trim(),
                                        price: priceVal,
                                        category: catVal,
                                        description: descCtrl.text.trim(),
                                        imageUrl: finalImageUrl,
                                        isBestSeller: isBestSeller,
                                        available: isAvailable,
                                        createdAt: DateTime.now().toUtc(),
                                      );
                                      final created = await _dataService.createProduct(newProd);
                                      setState(() {
                                        _products.insert(0, created);
                                      });
                                    }

                                    if (modalContext.mounted) {
                                      Navigator.of(modalContext).pop();
                                    }
                                  } catch (e) {
                                    setModalState(() {
                                      isSaving = false;
                                      modalError = e.toString().replaceAll('Exception:', '').trim();
                                    });
                                  }
                                },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // -------------------------------------------------------------
  // Promo Helpers & Actions
  // -------------------------------------------------------------

  static String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ][local.month - 1];
    final d = local.day;
    final y = local.year;
    final hour12 = local.hour == 0 ? 12 : (local.hour > 12 ? local.hour - 12 : local.hour);
    final min = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    return '$m $d, $y · $hour12:$min $ampm';
  }

  Future<DateTime?> _pickDateTime(BuildContext context, DateTime initial) async {
    final now = DateTime.now();
    final initialLocal = initial.toLocal();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialLocal,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (pickedDate == null || !context.mounted) return null;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialLocal),
    );
    if (pickedTime == null) return null;

    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  Future<void> _endPromoNow(Promo p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Promotion Now'),
        content: Text('Stop active promotion "${p.title}" immediately?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: MarketColors.error),
            child: const Text('End Now'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        final updated = p.copyWith(
          active: false,
          endsAt: DateTime.now().toUtc(),
        );
        await _dataService.updatePromo(updated);
        setState(() {
          final idx = _promos.indexWhere((item) => item.id == p.id);
          if (idx != -1) _promos[idx] = updated;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to end promo: $e')),
          );
        }
      }
    }
  }

  void _openAddOrEditPromoModal([Promo? existingPromo, PromoDraft? promoDraft]) {
    final isEditing = existingPromo != null;
    final titleCtrl = TextEditingController(text: existingPromo?.title ?? promoDraft?.title ?? '');
    final descCtrl = TextEditingController(text: existingPromo?.description ?? promoDraft?.description ?? '');
    final valueCtrl = TextEditingController(text: existingPromo?.valueLabel ?? promoDraft?.valueLabel ?? '');
    final limitCtrl = TextEditingController(
      text: existingPromo != null
          ? existingPromo.redeemLimit.toString()
          : (promoDraft != null ? promoDraft.redeemLimit.toString() : '100'),
    );
    final formKey = GlobalKey<FormState>();

    String selectedType = existingPromo?.promoType ?? promoDraft?.promoType ?? 'percent';
    String? selectedProductId = existingPromo?.productId;
    final now = DateTime.now();
    DateTime startsAt = existingPromo?.startsAt.toLocal() ?? promoDraft?.startsAt.toLocal() ?? now;
    DateTime endsAt = existingPromo?.endsAt.toLocal() ??
        promoDraft?.endsAt.toLocal() ??
        DateTime(now.year, now.month, now.day, 23, 59, 59).add(const Duration(days: 7));
    bool isSaving = false;
    String? modalError;
    Uint8List? pickedPromoBytes;
    String? pickedPromoFileName;
    String? currentPromoImageUrl = existingPromo?.imageUrl;
    bool isUploading = false;

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
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(modalContext).size.height * 0.9,
                ),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                decoration: const BoxDecoration(
                  color: MarketColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
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
                        Text(
                          isEditing ? 'Edit Promotion' : 'Create Promotion',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: MarketColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),

                        if (modalError != null) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: MarketColors.errorContainer.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              modalError!,
                              style: const TextStyle(color: MarketColors.error, fontSize: 12),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Promo Photo Field (Required)
                        const Text(
                          'Promo Photo *',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        if (pickedPromoBytes != null || (currentPromoImageUrl != null && currentPromoImageUrl!.isNotEmpty))
                          Container(
                            decoration: BoxDecoration(
                              color: MarketColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: MarketColors.cardBorder),
                            ),
                            child: Column(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                                  child: SizedBox(
                                    height: 140,
                                    width: double.infinity,
                                    child: pickedPromoBytes != null
                                        ? Image.memory(
                                            pickedPromoBytes!,
                                            fit: BoxFit.cover,
                                          )
                                        : Image.network(
                                            currentPromoImageUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) => const Center(
                                              child: Icon(Icons.broken_image_rounded, color: MarketColors.outline),
                                            ),
                                          ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  child: Row(
                                    children: [
                                      TextButton.icon(
                                        icon: const Icon(Icons.sync_rounded, size: 16),
                                        label: const Text('Replace', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                        onPressed: () async {
                                          final res = await FilePicker.platform.pickFiles(
                                            type: FileType.custom,
                                            allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
                                            withData: true,
                                          );
                                          if (res != null && res.files.isNotEmpty) {
                                            final f = res.files.first;
                                            final ext = f.extension?.toLowerCase() ?? '';
                                            if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
                                              setModalState(() {
                                                modalError = 'Only JPG, PNG, and WebP images are allowed.';
                                              });
                                              return;
                                            }
                                            if (f.size > 2 * 1024 * 1024) {
                                              setModalState(() {
                                                modalError = 'Photo exceeds 2 MB limit. Please select an image under 2 MB.';
                                              });
                                              return;
                                            }
                                            if (f.bytes == null) {
                                              setModalState(() {
                                                modalError = 'Could not read image file.';
                                              });
                                              return;
                                            }
                                            setModalState(() {
                                              modalError = null;
                                              pickedPromoBytes = f.bytes;
                                              pickedPromoFileName = f.name;
                                            });
                                          }
                                        },
                                      ),
                                      const Spacer(),
                                      TextButton.icon(
                                        icon: const Icon(Icons.delete_outline_rounded, size: 16, color: MarketColors.error),
                                        label: const Text('Remove', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: MarketColors.error)),
                                        onPressed: () {
                                          setModalState(() {
                                            pickedPromoBytes = null;
                                            pickedPromoFileName = null;
                                            currentPromoImageUrl = null;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          GestureDetector(
                            onTap: () async {
                              final res = await FilePicker.platform.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
                                withData: true,
                              );
                              if (res != null && res.files.isNotEmpty) {
                                final f = res.files.first;
                                final ext = f.extension?.toLowerCase() ?? '';
                                if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
                                  setModalState(() {
                                    modalError = 'Only JPG, PNG, and WebP images are allowed.';
                                  });
                                  return;
                                }
                                if (f.size > 2 * 1024 * 1024) {
                                  setModalState(() {
                                    modalError = 'Photo exceeds 2 MB limit. Please select an image under 2 MB.';
                                  });
                                  return;
                                }
                                if (f.bytes == null) {
                                  setModalState(() {
                                    modalError = 'Could not read image file.';
                                  });
                                  return;
                                }
                                setModalState(() {
                                  modalError = null;
                                  pickedPromoBytes = f.bytes;
                                  pickedPromoFileName = f.name;
                                });
                              }
                            },
                            child: Container(
                              height: 100,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: MarketColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: MarketColors.cardBorder),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.add_a_photo_outlined, color: MarketColors.primary, size: 24),
                                  SizedBox(width: 8),
                                  Text(
                                    'Select Promo Photo (JPG, PNG, WebP up to 2 MB) *',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: MarketColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (_business?.coverUrl != null &&
                            _business!.coverUrl!.isNotEmpty &&
                            pickedPromoBytes == null &&
                            (currentPromoImageUrl == null || currentPromoImageUrl!.isEmpty)) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 44),
                              side: const BorderSide(color: MarketColors.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(
                              Icons.storefront_outlined,
                              size: 18,
                              color: MarketColors.primary,
                            ),
                            label: const Text(
                              'Use My Shop Photo',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: MarketColors.primary,
                              ),
                            ),
                            onPressed: () {
                              setModalState(() {
                                currentPromoImageUrl = _business!.coverUrl;
                                pickedPromoBytes = null;
                                pickedPromoFileName = null;
                                modalError = null;
                              });
                            },
                          ),
                        ],
                        const SizedBox(height: 12),

                        // Title
                        AppTextField(
                          controller: titleCtrl,
                          label: 'Promotion Title *',
                          hintText: 'e.g. 20% Off Weekend Lunch',
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Title required' : null,
                        ),
                        const SizedBox(height: 12),

                        // Discount Type Dropdown
                        const Text(
                          'Discount Type *',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: MarketColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: MarketColors.cardBorder),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedType,
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(value: 'percent', child: Text('Percentage Discount (%)')),
                                DropdownMenuItem(value: 'amount_off', child: Text('Peso Amount Off (₱)')),
                                DropdownMenuItem(value: 'bogo', child: Text('Buy-One-Get-One (BOGO)')),
                                DropdownMenuItem(value: 'freebie', child: Text('Freebie / Gift Item')),
                              ],
                              onChanged: (val) {
                                if (val != null) setModalState(() => selectedType = val);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Value Label
                        AppTextField(
                          controller: valueCtrl,
                          label: 'Value / Badge Text *',
                          hintText: selectedType == 'percent'
                              ? 'e.g. 20% OFF'
                              : (selectedType == 'amount_off' ? 'e.g. ₱50 OFF' : 'e.g. Free Drink'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Value required' : null,
                        ),
                        const SizedBox(height: 12),

                        // Optional Linked Product
                        const Text(
                          'Linked Product (Optional)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: MarketColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: MarketColors.cardBorder),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              value: selectedProductId,
                              isExpanded: true,
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('Storewide / No linked product'),
                                ),
                                ..._products.map(
                                  (prod) => DropdownMenuItem(
                                    value: prod.id,
                                    child: Text(
                                      '${prod.name} (₱${prod.price.toStringAsFixed(0)})',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (val) {
                                setModalState(() => selectedProductId = val);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Redeem Limit
                        AppTextField(
                          controller: limitCtrl,
                          label: 'Redeem Limit *',
                          hintText: '100',
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Redeem limit required';
                            final n = int.tryParse(v.trim());
                            if (n == null || n <= 0) return 'Must be greater than 0';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Start & End Date Time Picker Rows
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Start Date-Time', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  InkWell(
                                    onTap: () async {
                                      final picked = await _pickDateTime(modalContext, startsAt);
                                      if (picked != null) {
                                        final now = DateTime.now();
                                        final isToday = picked.year == now.year &&
                                            picked.month == now.month &&
                                            picked.day == now.day;
                                        final effective = (isToday && picked.isBefore(now)) ? now : picked;
                                        setModalState(() => startsAt = effective);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: MarketColors.surfaceContainerLow,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: MarketColors.cardBorder),
                                      ),
                                      child: Text(
                                        _formatDateTime(startsAt),
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('End Date-Time', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  InkWell(
                                    onTap: () async {
                                      final picked = await _pickDateTime(modalContext, endsAt);
                                      if (picked != null) {
                                        setModalState(() => endsAt = picked);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: MarketColors.surfaceContainerLow,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: MarketColors.cardBorder),
                                      ),
                                      child: Text(
                                        _formatDateTime(endsAt),
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Description
                        AppTextField(
                          controller: descCtrl,
                          label: 'Terms & Conditions / Description',
                          hintText: 'Valid for dine-in only. One per customer.',
                          maxLines: 2,
                        ),
                        const SizedBox(height: 20),

                        // Save Button
                        PrimaryButton(
                          width: double.infinity,
                          height: 48,
                          label: isSaving
                              ? (isUploading ? 'Uploading Photo...' : 'Saving Promo...')
                              : (isEditing ? 'Update Promo' : 'Publish Promo'),
                          isLoading: isSaving,
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  if (pickedPromoBytes == null && (currentPromoImageUrl == null || currentPromoImageUrl!.isEmpty)) {
                                    setModalState(() {
                                      modalError = 'Add a photo for this promo';
                                    });
                                    return;
                                  }
                                  final now = DateTime.now();
                                  final localStarts = startsAt.toLocal();
                                  final isToday = localStarts.year == now.year &&
                                      localStarts.month == now.month &&
                                      localStarts.day == now.day;
                                  final effectiveStartsAt = (isToday && localStarts.isBefore(now))
                                      ? now
                                      : localStarts;

                                  if (!endsAt.toLocal().isAfter(effectiveStartsAt)) {
                                    setModalState(() {
                                      modalError = 'End date-time must be after start date-time.';
                                    });
                                    return;
                                  }

                                  setModalState(() {
                                    isSaving = true;
                                    modalError = null;
                                    isUploading = (pickedPromoBytes != null);
                                  });

                                  try {
                                    final bizId = _business?.id;
                                    if (bizId == null) {
                                      throw Exception('No registered business found.');
                                    }

                                    String? finalImageUrl = currentPromoImageUrl;
                                    if (pickedPromoBytes != null && pickedPromoFileName != null) {
                                      final uid = _authService.currentUserId ?? _business?.ownerId ?? 'merchant';
                                      final ext = (pickedPromoFileName!.split('.').lastOrNull ?? 'jpg').toLowerCase();
                                      final mimeType = ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
                                      final safeFileName = '${DateTime.now().millisecondsSinceEpoch}_${pickedPromoFileName!.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')}';

                                      finalImageUrl = await _dataService.uploadPromoImage(
                                        ownerId: uid,
                                        fileName: safeFileName,
                                        fileBytes: pickedPromoBytes!,
                                        contentType: mimeType,
                                      );
                                    }

                                    final limitVal = int.tryParse(limitCtrl.text.trim()) ?? 100;
                                    final startsAtUtc = effectiveStartsAt.toUtc();
                                    final endsAtUtc = endsAt.toLocal().toUtc();

                                    if (isEditing) {
                                      final updated = existingPromo.copyWith(
                                        title: titleCtrl.text.trim(),
                                        description: descCtrl.text.trim(),
                                        imageUrl: finalImageUrl,
                                        promoType: selectedType,
                                        valueLabel: valueCtrl.text.trim(),
                                        productId: selectedProductId,
                                        startsAt: startsAtUtc,
                                        endsAt: endsAtUtc,
                                        redeemLimit: limitVal,
                                      );
                                      final saved = await _dataService.updatePromo(updated);
                                      setState(() {
                                        final idx = _promos.indexWhere((item) => item.id == existingPromo.id);
                                        if (idx != -1) _promos[idx] = saved;
                                      });
                                    } else {
                                      final newPromo = Promo(
                                        id: '',
                                        businessId: bizId,
                                        productId: selectedProductId,
                                        title: titleCtrl.text.trim(),
                                        description: descCtrl.text.trim(),
                                        imageUrl: finalImageUrl,
                                        promoType: selectedType,
                                        valueLabel: valueCtrl.text.trim(),
                                        startsAt: startsAtUtc,
                                        endsAt: endsAtUtc,
                                        redeemLimit: limitVal,
                                        redeemedCount: 0,
                                        active: true,
                                        createdAt: DateTime.now().toUtc(),
                                      );
                                      final created = await _dataService.createPromo(newPromo);
                                      setState(() {
                                        _promos.insert(0, created);
                                      });
                                    }

                                    if (modalContext.mounted) {
                                      Navigator.of(modalContext).pop();
                                    }
                                  } catch (e) {
                                    setModalState(() {
                                      isSaving = false;
                                      isUploading = false;
                                      modalError = 'Upload or save failed: ${e.toString().replaceAll('Exception:', '').trim()}. Tap Save to retry.';
                                    });
                                  }
                                },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // -------------------------------------------------------------
  // UI Building
  // -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        _onBottomNavTapped(0);
      },
      child: Scaffold(
        backgroundColor: MarketColors.surface,
        appBar: const AppHeader(
          showBack: false,
          subtitle: 'Catalog',
        ),
        body: SafeArea(
          child: Column(
            children: [
              // 1. Top Segmented Tabs with Real Counts
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MarketSpacing.screenMargin,
                  8,
                  MarketSpacing.screenMargin,
                  8,
                ),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: MarketColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: MarketColors.fieldBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedSegment = 0),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _selectedSegment == 0
                                  ? MarketColors.surfaceContainerLowest
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _selectedSegment == 0 ? MarketElevation.level1 : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Products & Services (${_products.length})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _selectedSegment == 0 ? FontWeight.w800 : FontWeight.w600,
                                color: _selectedSegment == 0 ? MarketColors.onSurface : MarketColors.secondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedSegment = 1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _selectedSegment == 1
                                  ? MarketColors.surfaceContainerLowest
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _selectedSegment == 1 ? MarketElevation.level1 : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Promotions (${_promos.length})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _selectedSegment == 1 ? FontWeight.w800 : FontWeight.w600,
                                color: _selectedSegment == 1 ? MarketColors.onSurface : MarketColors.secondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Active Tab View
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: MarketColors.primary))
                    : _errorMessage != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_errorMessage!, style: const TextStyle(color: MarketColors.error)),
                                  const SizedBox(height: 12),
                                  PrimaryButton(
                                    label: 'Retry',
                                    height: 38,
                                    onPressed: _loadAllData,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _selectedSegment == 0
                            ? _buildProductsView()
                            : _buildPromotionsView(),
              ),
            ],
          ),
        ),
        bottomNavigationBar: AppBottomNav(
          currentIndex: 1,
          role: AppNavRole.merchant,
          onTap: _onBottomNavTapped,
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // Tab 0: Products & Services View
  // -------------------------------------------------------------

  Widget _buildProductsView() {
    final filtered = _filteredProducts;
    final categories = _dynamicCategories;

    return Column(
      children: [
        // Category Filter Chips
        if (categories.length > 1)
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: MarketSpacing.screenMargin),
              children: categories.map((cat) {
                final isSelected = _selectedCategoryFilter == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (val) => setState(() => _selectedCategoryFilter = cat),
                    selectedColor: MarketColors.primaryContainer,
                    backgroundColor: MarketColors.surfaceContainerLowest,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? MarketColors.onPrimaryContainer : MarketColors.secondary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 6),

        // Product Cards List or Empty State
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyProductsState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    MarketSpacing.screenMargin,
                    6,
                    MarketSpacing.screenMargin,
                    88, // bottom padding so Add Item never covers last card
                  ),
                  itemCount: filtered.length + 1,
                  itemBuilder: (context, index) {
                    if (index == filtered.length) {
                      // Inline Scan Menu and Add Item buttons
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: SecondaryButton(
                                key: const Key('scan_menu_button'),
                                label: 'Scan menu',
                                icon: const Icon(Icons.document_scanner_outlined, size: 18),
                                onPressed: _openScanMenuSheet,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: PrimaryButton(
                                label: 'Add Item',
                                icon: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
                                onPressed: () => _openAddOrEditItemModal(),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return _buildProductCard(filtered[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyProductsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 52, color: MarketColors.outline),
            const SizedBox(height: 14),
            const Text(
              'No items found in catalog',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: MarketColors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Add signature products and services to showcase on your storefront in San Jose.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: MarketColors.secondary),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    key: const Key('empty_scan_menu_button'),
                    label: 'Scan menu',
                    icon: const Icon(Icons.document_scanner_outlined, size: 18),
                    onPressed: _openScanMenuSheet,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryButton(
                    label: 'Add Item',
                    icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                    onPressed: () => _openAddOrEditItemModal(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Product p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MarketColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MarketColors.cardBorder),
        boxShadow: MarketElevation.level1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo or Fallback Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: p.imageUrl != null && p.imageUrl!.isNotEmpty
                      ? Image.network(
                          p.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _buildProductPlaceholder(),
                        )
                      : _buildProductPlaceholder(),
                ),
              ),
              const SizedBox(width: 12),

              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: MarketColors.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (p.isBestSeller) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_rounded, size: 12, color: Color(0xFFD97706)),
                                SizedBox(width: 2),
                                Text(
                                  'BEST',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFD97706),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '₱${p.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: MarketColors.primary,
                          ),
                        ),
                        if (p.category != null && p.category!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: MarketColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              p.category!,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: MarketColors.secondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (p.description != null && p.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        p.description!,
                        style: const TextStyle(fontSize: 11, color: MarketColors.secondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: MarketColors.cardBorder),
          const SizedBox(height: 6),

          // Action Row: Visibility toggle, Best-seller toggle, Edit, Delete
          Row(
            children: [
              // Available Toggle Chip
              InkWell(
                onTap: () => _toggleAvailability(p),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: p.available ? const Color(0xFFE8F5E9) : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        p.available ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                        size: 13,
                        color: p.available ? const Color(0xFF2E7D32) : MarketColors.outline,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        p.available ? 'Available' : 'Hidden',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: p.available ? const Color(0xFF2E7D32) : MarketColors.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Best seller toggle action
              InkWell(
                onTap: () => _toggleBestSeller(p),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        p.isBestSeller ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 16,
                        color: p.isBestSeller ? const Color(0xFFD97706) : MarketColors.outline,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        p.isBestSeller ? 'Best seller' : 'Feature',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: p.isBestSeller ? const Color(0xFFD97706) : MarketColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Edit action
              TextButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 14),
                label: const Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                onPressed: () => _openAddOrEditItemModal(p),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: MarketColors.error),
                onPressed: () => _deleteProduct(p),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductPlaceholder() {
    return Container(
      color: MarketColors.surfaceContainerLow,
      child: const Center(
        child: Icon(Icons.inventory_2_rounded, color: MarketColors.primary, size: 28),
      ),
    );
  }

  // -------------------------------------------------------------
  // Tab 1: Promotions View
  // -------------------------------------------------------------

  Widget _buildPromotionsView() {
    final activeList = _promos.where((p) => p.isActiveNow).toList();
    final scheduledList = _promos.where((p) => p.isScheduled).toList();
    final endedList = _promos.where((p) => p.isEnded).toList();

    if (_promos.isEmpty) {
      return _buildEmptyPromosState();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        MarketSpacing.screenMargin,
        6,
        MarketSpacing.screenMargin,
        88, // bottom padding so Create Promo never covers last card
      ),
      children: [
        if (activeList.isNotEmpty) ...[
          _buildPromoGroupHeader('Live Promotions', activeList.length, MarketColors.success),
          ...activeList.map((p) => _buildPromoCard(p)),
          const SizedBox(height: 16),
        ],
        if (scheduledList.isNotEmpty) ...[
          _buildPromoGroupHeader('Upcoming Promotions', scheduledList.length, Colors.blue),
          ...scheduledList.map((p) => _buildPromoCard(p)),
          const SizedBox(height: 16),
        ],
        if (endedList.isNotEmpty) ...[
          _buildPromoGroupHeader('Ended Promotions', endedList.length, MarketColors.outline),
          ...endedList.map((p) => _buildPromoCard(p)),
          const SizedBox(height: 16),
        ],

        // Create Promo button
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: PrimaryButton(
            label: 'New Promo',
            icon: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
            onPressed: () => _openAddOrEditPromoModal(),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyPromosState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_offer_outlined, size: 52, color: MarketColors.outline),
            const SizedBox(height: 14),
            const Text(
              'No promotions found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: MarketColors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Launch promotional discounts to trigger automatic geofence alerts for shoppers entering San Jose.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: MarketColors.secondary),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'New Promo',
              icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
              onPressed: () => _openAddOrEditPromoModal(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoGroupHeader(String title, int count, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
          ),
          const SizedBox(width: 8),
          Text(
            '$title ($count)',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: MarketColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoStatusBadge(Promo p) {
    final now = DateTime.now();
    final localStarts = p.startsAt.toLocal();
    final localEnds = p.endsAt.toLocal();

    // 1. Upcoming: active is true, but starts_at is in the future
    if (p.active && now.isBefore(localStarts)) {
      final diff = localStarts.difference(now);
      final startsText = diff.inDays > 1
          ? 'in ${diff.inDays}d'
          : (diff.inHours > 0
              ? 'in ${diff.inHours}h'
              : 'in ${diff.inMinutes.clamp(1, 60)}m');
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: const Color(0xFFE0F2FE),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFBAE6FD)),
        ),
        child: Text(
          'UPCOMING • Starts $startsText',
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0369A1),
          ),
        ),
      );
    }

    // 2. Live: active is true, within [startsAt, endsAt], and capacity remains
    if (p.active &&
        (now.isAfter(localStarts) || now.isAtSameMomentAs(localStarts)) &&
        now.isBefore(localEnds) &&
        p.redeemedCount < p.redeemLimit) {
      final diff = localEnds.difference(now);
      final endsText = diff.inDays > 1
          ? 'Ends in ${diff.inDays}d'
          : (diff.inHours > 0 ? 'Ends in ${diff.inHours}h' : 'Ends soon');
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF86EFAC)),
        ),
        child: Text(
          'LIVE • $endsText',
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF15803D),
          ),
        ),
      );
    }

    // 3. Ended: !active, ends_at passed, or limit reached
    String reason = 'Expired';
    if (!p.active) {
      reason = 'Paused';
    } else if (p.redeemedCount >= p.redeemLimit) {
      reason = 'Limit Reached';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: MarketColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: MarketColors.outlineVariant),
      ),
      child: Text(
        'ENDED • $reason',
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: MarketColors.outline,
        ),
      ),
    );
  }

  Widget _buildPromoCard(Promo p) {
    final bool canEnd = p.isActiveNow || p.isScheduled;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MarketColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MarketColors.cardBorder),
        boxShadow: MarketElevation.level1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Photo Thumbnail + Details
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
                    businessCoverUrl: _business?.coverUrl,
                    category: _business?.category,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge & Value Label
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: MarketColors.primaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            p.promoType.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: MarketColors.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _buildPromoStatusBadge(p),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            p.valueLabel ?? p.promoType.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: MarketColors.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      p.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: MarketColors.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (p.description != null && p.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        p.description!,
                        style: const TextStyle(fontSize: 11, color: MarketColors.secondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Validity date
          Row(
            children: [
              const Icon(Icons.event_available_rounded, size: 14, color: MarketColors.outline),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${_formatDateTime(p.startsAt)} — ${_formatDateTime(p.endsAt)}',
                  style: const TextStyle(fontSize: 11, color: MarketColors.secondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Real claim & redemption counts
          Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded, size: 14, color: MarketColors.primary),
              const SizedBox(width: 4),
              Text(
                'Redeemed: ${p.redeemedCount} / ${p.redeemLimit}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: MarketColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: MarketColors.cardBorder),
          const SizedBox(height: 8),

          // Action Buttons: Show QR, Edit, End-now
          Row(
            children: [
              // Show QR action
              PrimaryButton(
                label: 'Show QR',
                height: 34,
                icon: const Icon(Icons.qr_code_rounded, size: 16, color: Colors.white),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StoreQrScreen(
                        business: _business,
                        initialPromo: p,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),

              // Edit action
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(60, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _openAddOrEditPromoModal(p),
                child: const Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),

              const Spacer(),

              // End now action
              if (canEnd)
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: MarketColors.error,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => _endPromoNow(p),
                  child: const Text('End now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
