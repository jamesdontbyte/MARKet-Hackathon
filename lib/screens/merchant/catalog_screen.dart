import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/business.dart';
import '../../models/product.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/merchant_bottom_nav.dart';
import 'account_screen.dart';
import 'analytics_screen.dart';
import 'dashboard_screen.dart';
import 'promotions_screen.dart';

/// MSME Merchant Catalog Screen (Products & Services CRUD)
/// Matches Stitch frame: market_tab_2_catalog
class MerchantCatalogScreen extends StatefulWidget {
  final Business? business;

  const MerchantCatalogScreen({
    super.key,
    this.business,
  });

  @override
  State<MerchantCatalogScreen> createState() => _MerchantCatalogScreenState();
}

class _MerchantCatalogScreenState extends State<MerchantCatalogScreen> {
  final AuthService _authService = AuthService();
  final DataService _dataService = DataService();

  Business? _business;
  List<Product> _products = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedCategoryFilter = 'All';

  @override
  void initState() {
    super.initState();
    _business = widget.business;
    _loadProducts();
  }

  Future<void> _loadProducts() async {
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
        _products = await _dataService.fetchProducts(_business!.id);
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

  List<Product> get _filteredProducts {
    if (_selectedCategoryFilter == 'All') return _products;
    return _products.where((p) => (p.category ?? '').toLowerCase() == _selectedCategoryFilter.toLowerCase()).toList();
  }

  void _onBottomNavTapped(int index) {
    if (index == 1) return; // Already here
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


  void _openAddOrEditItemModal([Product? existingProduct]) {
    final isEditing = existingProduct != null;
    final nameCtrl = TextEditingController(text: existingProduct?.name ?? '');
    final priceCtrl = TextEditingController(text: existingProduct != null ? existingProduct.price.toStringAsFixed(0) : '');
    final catCtrl = TextEditingController(text: existingProduct?.category ?? 'Beverages');
    final descCtrl = TextEditingController(text: existingProduct?.description ?? '');
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
                      Text(
                        isEditing ? 'Edit Item' : 'Add Catalog Item',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: MarketColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Name
                      AppTextField(
                        controller: nameCtrl,
                        label: 'Item Name *',
                        hintText: 'e.g. Sea Salt Caramel Latte',
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Item name required' : null,
                      ),
                      const SizedBox(height: 12),

                      // Price (₱) & Category
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: priceCtrl,
                              label: 'Price (₱) *',
                              hintText: '180',
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Price required';
                                if (double.tryParse(v) == null) return 'Invalid price';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppTextField(
                              controller: catCtrl,
                              label: 'Category',
                              hintText: 'Beverages, Pastries...',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Description
                      AppTextField(
                        controller: descCtrl,
                        label: 'Description',
                        hintText: 'Fresh artisan coffee with velvety caramel...',
                      ),
                      const SizedBox(height: 20),

                      // Save Button
                      PrimaryButton(
                        width: double.infinity,
                        height: 50,
                        label: isSaving ? 'Saving Item...' : (isEditing ? 'Update Item' : 'Save to Catalog'),
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
                                  final priceVal = double.tryParse(priceCtrl.text.trim()) ?? 0.0;

                                  if (isEditing) {
                                    final updated = existingProduct.copyWith(
                                      name: nameCtrl.text.trim(),
                                      price: priceVal,
                                      category: catCtrl.text.trim(),
                                      description: descCtrl.text.trim(),
                                    );
                                    await _dataService.updateProduct(updated);
                                  } else {
                                    final newProd = Product(
                                      id: '',
                                      businessId: bizId,
                                      name: nameCtrl.text.trim(),
                                      price: priceVal,
                                      category: catCtrl.text.trim(),
                                      description: descCtrl.text.trim(),
                                      createdAt: DateTime.now(),
                                    );
                                    await _dataService.createProduct(newProd);
                                  }

                                  if (modalContext.mounted) {
                                    Navigator.of(modalContext).pop();
                                  }
                                  await _loadProducts();
                                } catch (e) {
                                  setModalState(() => isSaving = false);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error saving: $e')),
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

  Future<void> _deleteProduct(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item?'),
        content: Text('Are you sure you want to remove "${product.name}" from your catalog?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: MarketColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _dataService.deleteProduct(product.id);
        await _loadProducts();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting product: $e')),
          );
        }
      }
    }
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
                          'Products & Services (${_products.length})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: MarketColors.onSurface,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => MerchantPromotionsScreen(business: _business),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          child: const Text(
                            'Promotions',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: MarketColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Category Filter Chips
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: MarketSpacing.screenMargin),
                children: ['All', 'Beverages', 'Pastries', 'Beans & Merch'].map((cat) {
                  final isSelected = _selectedCategoryFilter == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (val) {
                        setState(() {
                          _selectedCategoryFilter = cat;
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

            // Products List
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
                                onPressed: _loadProducts,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _filteredProducts.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.inventory_2_outlined,
                                        size: 48, color: MarketColors.outline),
                                    const SizedBox(height: 12),
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
                                      'Add your signature items so nearby customers can explore your menu.',
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
                                      label: const Text('Add Item'),
                                      onPressed: () => _openAddOrEditItemModal(),
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
                              itemCount: _filteredProducts.length,
                              itemBuilder: (context, index) {
                                final product = _filteredProducts[index];
                                return _buildProductCard(product);
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
          'Add Item',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        onPressed: () => _openAddOrEditItemModal(),
      ),
      bottomNavigationBar: MerchantBottomNav(
        currentIndex: 1,
        onTap: _onBottomNavTapped,
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
              // Product placeholder thumbnail
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: MarketColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_cafe_rounded,
                    color: MarketColors.primary, size: 28),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: MarketColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '₱${product.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: MarketColors.onSurface,
                          ),
                        ),
                        if (product.category != null && product.category!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: MarketColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              product.category!,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: MarketColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (product.description != null && product.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        product.description!,
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
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 6),

          // Actions Row (Edit, Delete)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                onPressed: () => _openAddOrEditItemModal(product),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: MarketColors.error),
                onPressed: () => _deleteProduct(product),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
