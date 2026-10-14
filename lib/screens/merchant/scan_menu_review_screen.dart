import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../models/business.dart';
import '../../models/product.dart';
import '../../models/scanned_menu_item.dart';
import '../../services/data_service.dart';
import '../../services/stock_photo_service.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text_field.dart';
import 'account_screen.dart';
import 'analytics_screen.dart';
import 'dashboard_screen.dart';

/// Item state holder for editable row in the review screen
class ReviewItemEntry {
  final String id;
  final TextEditingController nameCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController categoryCtrl;
  final String? description;
  final double confidence;
  bool isChecked;
  final bool isDuplicate;
  bool hasSaveFailed;
  String? saveError;

  // Stock photos & own photo support
  List<StockPhotoCandidate> candidates;
  StockPhotoCandidate? selectedCandidate;
  Uint8List? ownPhotoBytes;
  String? ownPhotoName;
  String? photoSaveError;

  ReviewItemEntry({
    required this.id,
    required this.nameCtrl,
    required this.priceCtrl,
    required this.categoryCtrl,
    this.description,
    required this.confidence,
    required this.isChecked,
    required this.isDuplicate,
    this.hasSaveFailed = false,
    this.saveError,
    List<StockPhotoCandidate>? candidates,
    this.selectedCandidate,
    this.ownPhotoBytes,
    this.ownPhotoName,
    this.photoSaveError,
  }) : candidates = candidates ?? [];

  void dispose() {
    nameCtrl.dispose();
    priceCtrl.dispose();
    categoryCtrl.dispose();
  }

  bool get isConfidenceLow => confidence < 0.6;

  bool get isPriceMissingOrInvalid {
    final text = priceCtrl.text.trim();
    if (text.isEmpty) return true;
    final val = double.tryParse(text);
    return val == null || val < 0;
  }

  bool get isNameEmpty => nameCtrl.text.trim().isEmpty;

  bool get needsAttention => isConfidenceLow || isPriceMissingOrInvalid;
}

class ScanMenuReviewScreen extends StatefulWidget {
  final Business business;
  final List<Product> existingProducts;
  final List<ScannedMenuItem> scannedItems;
  final DataService? dataService;
  final StockPhotoService? stockPhotoService;

  const ScanMenuReviewScreen({
    super.key,
    required this.business,
    required this.existingProducts,
    required this.scannedItems,
    this.dataService,
    this.stockPhotoService,
  });

  @override
  State<ScanMenuReviewScreen> createState() => _ScanMenuReviewScreenState();
}

class _ScanMenuReviewScreenState extends State<ScanMenuReviewScreen> {
  late final DataService _dataService;
  late final StockPhotoService _stockPhotoService;
  final List<ReviewItemEntry> _items = [];
  bool _isSaving = false;
  bool _isFindingPhotos = false;
  bool _hideFindPhotosButton = false;
  String? _statusMessage;
  bool _statusIsError = false;

  @override
  void initState() {
    super.initState();
    _dataService = widget.dataService ?? DataService();
    _stockPhotoService = widget.stockPhotoService ?? StockPhotoService();

    int idCounter = 0;
    for (final item in widget.scannedItems) {
      final isDup = _checkDuplicate(item.name);
      final priceStr = item.price != null
          ? (item.price! % 1 == 0
              ? item.price!.toInt().toString()
              : item.price!.toStringAsFixed(2))
          : '';

      final nameCtrl = TextEditingController(text: item.name);
      final priceCtrl = TextEditingController(text: priceStr);
      final catCtrl = TextEditingController(text: item.category);

      nameCtrl.addListener(_onFieldChanged);
      priceCtrl.addListener(_onFieldChanged);
      catCtrl.addListener(_onFieldChanged);

      _items.add(
        ReviewItemEntry(
          id: 'item_${idCounter++}',
          nameCtrl: nameCtrl,
          priceCtrl: priceCtrl,
          categoryCtrl: catCtrl,
          description: item.description,
          confidence: item.confidence,
          isChecked: !isDup, // Uncheck duplicates by default; others checked
          isDuplicate: isDup,
        ),
      );
    }
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _onFieldChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool _checkDuplicate(String name) {
    final lower = name.trim().toLowerCase();
    if (lower.isEmpty) return false;
    return widget.existingProducts.any(
      (p) => p.name.trim().toLowerCase() == lower,
    );
  }

  void _addNewEmptyItem() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final catCtrl = TextEditingController(text: 'General');

    nameCtrl.addListener(_onFieldChanged);
    priceCtrl.addListener(_onFieldChanged);
    catCtrl.addListener(_onFieldChanged);

    setState(() {
      _items.add(
        ReviewItemEntry(
          id: 'item_${DateTime.now().microsecondsSinceEpoch}',
          nameCtrl: nameCtrl,
          priceCtrl: priceCtrl,
          categoryCtrl: catCtrl,
          confidence: 1.0,
          isChecked: true,
          isDuplicate: false,
        ),
      );
    });
  }

  void _removeItem(int index) {
    setState(() {
      final removed = _items.removeAt(index);
      removed.dispose();
    });
  }

  void _toggleSelectAll(bool? selectAll) {
    setState(() {
      final target = selectAll ?? true;
      for (final item in _items) {
        item.isChecked = target;
      }
    });
  }

  Future<void> _pickOwnPhoto(ReviewItemEntry entry, ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          entry.ownPhotoBytes = bytes;
          entry.ownPhotoName = picked.name;
          entry.selectedCandidate = null;
          entry.photoSaveError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick photo: $e')),
        );
      }
    }
  }

  Future<void> _findPhotosForCheckedItems() async {
    if (!stockPhotosEnabled || _isFindingPhotos) return;

    final checked = _items.where((e) => e.isChecked).toList();
    if (checked.isEmpty) {
      setState(() {
        _statusMessage = 'Select items to find photos';
        _statusIsError = false;
      });
      return;
    }

    setState(() {
      _isFindingPhotos = true;
      _statusMessage = null;
      _statusIsError = false;
    });

    try {
      // Limit to 15 items per batch
      final batch = checked.take(15).toList();
      final payload = batch.map((e) {
        return {
          'id': e.id,
          'name': e.nameCtrl.text.trim().isEmpty ? 'Item' : e.nameCtrl.text.trim(),
          'category': e.categoryCtrl.text.trim(),
        };
      }).toList();

      final results = await _stockPhotoService.findPhotos(payload);

      setState(() {
        for (final res in results) {
          final match = _items.where((it) => it.id == res.itemId).toList();
          if (match.isNotEmpty) {
            final entry = match.first;
            entry.candidates = res.candidates;
            entry.photoSaveError = null;

            // Pre-select best match only when confidence is at least 0.7.
            // Otherwise leave it unselected with a "Pick a photo" prompt.
            if (res.confidence >= 0.7 && res.bestId != null) {
              entry.selectedCandidate = res.bestMatch;
            } else {
              entry.selectedCandidate = null;
            }
          }
        }
      });
    } on StockPhotoException catch (e) {
      setState(() {
        if (e.code == 'missing_api_key') {
          _hideFindPhotosButton = true;
          _statusMessage = 'Stock photo service is unavailable.';
        } else {
          _statusMessage = e.message;
        }
        _statusIsError = true;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Unable to find photos right now. Please try again.';
        _statusIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isFindingPhotos = false;
        });
      }
    }
  }

  Future<void> _saveCheckedItems() async {
    final checked = _items.where((e) => e.isChecked).toList();
    if (checked.isEmpty || _isSaving) return;

    // Guard: Block if any checked row has no name or invalid price
    final hasInvalid = checked.any((e) => e.isNameEmpty || e.isPriceMissingOrInvalid);
    if (hasInvalid) {
      setState(() {
        _statusMessage = 'Please fix or uncheck items with missing names or prices before saving.';
        _statusIsError = true;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _statusMessage = null;
      _statusIsError = false;
    });

    int addedCount = 0;
    int failedCount = 0;
    int photoFailedCount = 0;
    final successfulEntries = <ReviewItemEntry>[];

    for (final entry in checked) {
      try {
        final priceVal = double.parse(entry.priceCtrl.text.trim());
        final catVal = entry.categoryCtrl.text.trim().isNotEmpty
            ? entry.categoryCtrl.text.trim()
            : 'General';

        String? finalImageUrl;
        String? finalImageSource;
        String? finalImageCredit;
        String? finalImageCreditUrl;

        // Requirement 10: Download medium image from cdn.pixabay.com or pixabay.com only,
        // 5s timeout, max 2 MB. Upload to business-media/<uid>/products/
        if (entry.selectedCandidate != null) {
          try {
            final fileBytes = await StockPhotoService.downloadMediumImage(
              entry.selectedCandidate!.mediumUrl,
            );
            final uid = widget.business.ownerId ?? 'merchant';
            final safeName = 'stock_${entry.selectedCandidate!.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
            finalImageUrl = await _dataService.uploadProductImage(
              ownerId: uid,
              fileName: safeName,
              fileBytes: fileBytes,
            );
            finalImageSource = 'stock';
            finalImageCredit = entry.selectedCandidate!.photographer;
            finalImageCreditUrl = entry.selectedCandidate!.url;
            entry.photoSaveError = null;
          } catch (photoErr) {
            photoFailedCount++;
            entry.photoSaveError = 'Photo not added, retry';
            finalImageUrl = null;
            finalImageSource = null;
            finalImageCredit = null;
            finalImageCreditUrl = null;
          }
        } else if (entry.ownPhotoBytes != null) {
          try {
            final uid = widget.business.ownerId ?? 'merchant';
            final safeName = 'own_${DateTime.now().millisecondsSinceEpoch}_${entry.ownPhotoName ?? 'photo.jpg'}';
            finalImageUrl = await _dataService.uploadProductImage(
              ownerId: uid,
              fileName: safeName,
              fileBytes: entry.ownPhotoBytes!,
            );
            finalImageSource = 'own';
            entry.photoSaveError = null;
          } catch (photoErr) {
            photoFailedCount++;
            entry.photoSaveError = 'Photo not added, retry';
            finalImageUrl = null;
            finalImageSource = null;
          }
        }

        final newProd = Product(
          id: '',
          businessId: widget.business.id,
          name: entry.nameCtrl.text.trim(),
          price: priceVal,
          category: catVal,
          description: entry.description?.trim(),
          imageUrl: finalImageUrl,
          imageSource: finalImageSource,
          imageCredit: finalImageCredit,
          imageCreditUrl: finalImageCreditUrl,
          isBestSeller: false,
          available: true,
          createdAt: DateTime.now().toUtc(),
        );

        await _dataService.createProduct(newProd);
        addedCount++;
        entry.hasSaveFailed = false;
        entry.saveError = null;

        // If photo failed, keep entry to display "Photo not added, retry"
        if (entry.photoSaveError == null) {
          successfulEntries.add(entry);
        }
      } catch (e) {
        failedCount++;
        entry.hasSaveFailed = true;
        entry.saveError = e.toString().replaceAll('Exception:', '').trim();
      }
    }

    // Remove succeeded items from screen
    setState(() {
      for (final s in successfulEntries) {
        _items.remove(s);
        s.dispose();
      }
      _isSaving = false;
    });

    if (failedCount == 0 && photoFailedCount == 0 && addedCount > 0) {
      if (mounted) {
        Navigator.of(context).pop(addedCount);
      }
    } else {
      setState(() {
        if (photoFailedCount > 0 && failedCount == 0) {
          _statusMessage = 'Added $addedCount items. Photo not added, retry.';
        } else {
          _statusMessage = 'Added $addedCount items. $failedCount failed to save. Please review and retry.';
        }
        _statusIsError = true;
      });
    }
  }

  void _onBottomNavTapped(int index) {
    if (index == 1) {
      Navigator.of(context).pop();
      return;
    }
    if (index == 0) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MerchantDashboardScreen(business: widget.business),
        ),
      );
    } else if (index == 2) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MerchantAnalyticsScreen(business: widget.business),
        ),
      );
    } else if (index == 3) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MerchantAccountScreen(business: widget.business),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final checkedCount = _items.where((e) => e.isChecked).length;
    final anyCheckedInvalid = _items
        .where((e) => e.isChecked)
        .any((e) => e.isNameEmpty || e.isPriceMissingOrInvalid);
    final canSave = checkedCount > 0 && !anyCheckedInvalid && !_isSaving;
    final allChecked = _items.isNotEmpty && _items.every((e) => e.isChecked);

    return Scaffold(
      backgroundColor: MarketColors.surface,
      appBar: const AppHeader(
        showBack: true,
        subtitle: 'Review Scanned Items',
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status/Error Banner
            if (_statusMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: _statusIsError
                    ? MarketColors.errorContainer.withValues(alpha: 0.4)
                    : MarketColors.primaryContainer.withValues(alpha: 0.4),
                child: Row(
                  children: [
                    Icon(
                      _statusIsError ? Icons.error_outline_rounded : Icons.check_circle_outline,
                      size: 20,
                      color: _statusIsError ? MarketColors.error : MarketColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _statusIsError ? MarketColors.error : MarketColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Top Select-All Row, Find Photos & Count
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  InkWell(
                    onTap: () => _toggleSelectAll(!allChecked),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: allChecked,
                              activeColor: MarketColors.primary,
                              onChanged: _toggleSelectAll,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            allChecked ? 'Deselect All' : 'Select All',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: MarketColors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // "Find photos" button (Requirement 9, 13)
                      if (stockPhotosEnabled && !_hideFindPhotosButton)
                        OutlinedButton.icon(
                          key: const Key('find_photos_button'),
                          onPressed: _isFindingPhotos ? null : _findPhotosForCheckedItems,
                          icon: _isFindingPhotos
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.photo_library_outlined, size: 16),
                          label: Text(
                            _isFindingPhotos ? 'Finding...' : 'Find photos',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: MarketColors.primary,
                            side: const BorderSide(color: MarketColors.primary),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: const Size(0, 36),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),

                      Text(
                        '${_items.length} detected',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: MarketColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Detected Items List
            Expanded(
              child: _items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.checklist_rounded,
                              size: 48,
                              color: MarketColors.outline,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No items to review',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: MarketColors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'All scanned items were saved or removed.',
                              style: TextStyle(
                                fontSize: 12,
                                color: MarketColors.secondary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: _addNewEmptyItem,
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Add item'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: _items.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _items.length) {
                          // "Add item" row for anything missed
                          return Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 16),
                            child: OutlinedButton.icon(
                              key: const Key('add_missed_item_button'),
                              onPressed: _addNewEmptyItem,
                              icon: const Icon(Icons.add_rounded, size: 20),
                              label: const Text(
                                'Add item',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: MarketColors.primary,
                                side: const BorderSide(color: MarketColors.primary, width: 1.5),
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          );
                        }

                        return _buildItemRowCard(index, _items[index]);
                      },
                    ),
            ),

            // Sticky Bottom Save Action Bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: MarketColors.surfaceContainerLowest,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (anyCheckedInvalid && checkedCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: const [
                          Icon(Icons.info_outline, size: 16, color: MarketColors.error),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Fix highlighted names and prices to enable saving.',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: MarketColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  PrimaryButton(
                    key: const Key('add_scanned_items_button'),
                    width: double.infinity,
                    height: 48,
                    label: _isSaving
                        ? 'Saving items...'
                        : 'Add $checkedCount ${checkedCount == 1 ? 'item' : 'items'}',
                    isLoading: _isSaving,
                    onPressed: canSave ? _saveCheckedItems : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: 1,
        role: AppNavRole.merchant,
        onTap: _onBottomNavTapped,
      ),
    );
  }

  Widget _buildItemRowCard(int index, ReviewItemEntry entry) {
    final needsCheck = entry.needsAttention;
    final hasErrorBorder = entry.isPriceMissingOrInvalid || entry.isNameEmpty;

    return Container(
      key: Key('scanned_item_card_$index'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MarketColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: needsCheck
              ? const Color(0xFFF59E0B) // Amber warning outline
              : (hasErrorBorder
                  ? MarketColors.error
                  : MarketColors.cardBorder),
          width: needsCheck ? 1.5 : 1.0,
        ),
        boxShadow: MarketElevation.level1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Checkbox, Badges, Delete action
          Row(
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: Checkbox(
                  key: Key('scanned_item_checkbox_$index'),
                  value: entry.isChecked,
                  activeColor: MarketColors.primary,
                  onChanged: (val) {
                    setState(() {
                      entry.isChecked = val ?? false;
                    });
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (needsCheck)
                      Container(
                        key: Key('check_this_badge_$index'),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFF59E0B)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.warning_amber_rounded, size: 13, color: Color(0xFFD97706)),
                            SizedBox(width: 4),
                            Text(
                              'Check this',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (entry.isDuplicate)
                      Container(
                        key: Key('already_in_catalog_badge_$index'),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: MarketColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: MarketColors.outlineVariant),
                        ),
                        child: const Text(
                          'Already in catalog',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: MarketColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                key: Key('delete_scanned_item_$index'),
                icon: const Icon(Icons.delete_outline_rounded, size: 20, color: MarketColors.secondary),
                onPressed: () => _removeItem(index),
                tooltip: 'Delete item',
              ),
            ],
          ),

          if (entry.hasSaveFailed && entry.saveError != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: MarketColors.errorContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Failed to save: ${entry.saveError}',
                style: const TextStyle(fontSize: 11, color: MarketColors.error),
              ),
            ),
          ],

          const SizedBox(height: 8),

          // Name field (full width)
          AppTextField(
            key: Key('scanned_item_name_$index'),
            controller: entry.nameCtrl,
            label: 'Item Name',
            hintText: 'e.g. Iced Latte (Large)',
            errorText: entry.isChecked && entry.isNameEmpty ? 'Name cannot be empty' : null,
          ),
          const SizedBox(height: 8),

          // Price & Category responsive fields
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(MarketRadii.input),
                    color: entry.isPriceMissingOrInvalid
                        ? const Color(0xFFFFFBEB) // Subtle amber highlight background
                        : null,
                  ),
                  child: AppTextField(
                    key: Key('scanned_item_price_$index'),
                    controller: entry.priceCtrl,
                    label: 'Price (₱)',
                    hintText: '0.00',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    errorText: entry.isChecked && entry.isPriceMissingOrInvalid
                        ? 'Valid price required'
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 6,
                child: AppTextField(
                  key: Key('scanned_item_category_$index'),
                  controller: entry.categoryCtrl,
                  label: 'Category',
                  hintText: 'General',
                ),
              ),
            ],
          ),

          // Photo selection section (Requirement 9 & 10)
          _buildPhotoSelectionSection(index, entry),
        ],
      ),
    );
  }

  Widget _buildPhotoSelectionSection(int index, ReviewItemEntry entry) {
    if (!stockPhotosEnabled) return const SizedBox.shrink();

    // 1. If merchant picked own photo
    if (entry.ownPhotoBytes != null) {
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: MarketColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: MarketColors.cardBorder),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                entry.ownPhotoBytes!,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Your Photo',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: MarketColors.onSurface,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Will be uploaded on save',
                    style: TextStyle(fontSize: 11, color: MarketColors.secondary),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18, color: MarketColors.secondary),
              onPressed: () {
                setState(() {
                  entry.ownPhotoBytes = null;
                  entry.ownPhotoName = null;
                });
              },
            ),
          ],
        ),
      );
    }

    // 2. If candidates exist
    if (entry.candidates.isNotEmpty) {
      final isUnselected = entry.selectedCandidate == null;

      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: MarketColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isUnselected
                ? const Color(0xFFF59E0B) // Amber for pick a photo prompt
                : MarketColors.cardBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Prompt header
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isUnselected) ...[
                      const Icon(Icons.touch_app_outlined, size: 14, color: Color(0xFFD97706)),
                      const SizedBox(width: 6),
                      const Text(
                        'Pick a photo',
                        key: Key('pick_a_photo_prompt'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ] else ...[
                      const Icon(Icons.check_circle_rounded, size: 14, color: MarketColors.primary),
                      const SizedBox(width: 6),
                      const Text(
                        'Selected photo',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: MarketColors.primary,
                        ),
                      ),
                    ],
                  ],
                ),
                // Add own photo action
                PopupMenuButton<ImageSource>(
                  tooltip: 'Add own photo',
                  onSelected: (source) => _pickOwnPhoto(entry, source),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: ImageSource.camera,
                      child: Row(
                        children: [
                          Icon(Icons.camera_alt_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Take Photo'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: ImageSource.gallery,
                      child: Row(
                        children: [
                          Icon(Icons.photo_library_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Choose from Gallery'),
                        ],
                      ),
                    ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.add_a_photo_outlined, size: 14, color: MarketColors.primary),
                        SizedBox(width: 4),
                        Text(
                          'Own photo',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: MarketColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Thumbnail strip (up to 6 candidates)
            SizedBox(
              height: 60,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: entry.candidates.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (ctx, cIdx) {
                  final cand = entry.candidates[cIdx];
                  final isSelected = entry.selectedCandidate?.id == cand.id;

                  return GestureDetector(
                    key: Key('photo_candidate_${index}_$cIdx'),
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          entry.selectedCandidate = null;
                        } else {
                          entry.selectedCandidate = cand;
                          entry.ownPhotoBytes = null;
                        }
                      });
                    },
                    child: Stack(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? MarketColors.primary : MarketColors.cardBorder,
                              width: isSelected ? 2.5 : 1.0,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              cand.thumbnailUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: MarketColors.surfaceContainerHigh,
                                child: const Icon(Icons.broken_image, size: 20, color: MarketColors.outline),
                              ),
                            ),
                          ),
                        ),
                        if (isSelected)
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: MarketColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check, size: 10, color: Colors.black),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Photographer credit & Remove action
            if (entry.selectedCandidate != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Photo by ${entry.selectedCandidate!.photographer} on Pixabay',
                      style: const TextStyle(
                        fontSize: 11,
                        color: MarketColors.secondary,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      setState(() {
                        entry.selectedCandidate = null;
                      });
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        'Remove',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: MarketColors.error,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    // 3. Photo save error banner (e.g. "Photo not added, retry")
    if (entry.photoSaveError != null) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: MarketColors.errorContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, size: 14, color: MarketColors.error),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                entry.photoSaveError!,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: MarketColors.error),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
