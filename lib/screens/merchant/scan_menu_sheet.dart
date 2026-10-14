import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme.dart';
import '../../models/business.dart';
import '../../services/scan_service.dart';
import '../../widgets/app_buttons.dart';

/// Modal bottom sheet for capturing/selecting menu photos and scanning them
class ScanMenuSheet extends StatefulWidget {
  final Business business;
  final ScanService? scanService;
  final ImagePicker? picker;
  final List<XFile>? initialFiles;

  const ScanMenuSheet({
    super.key,
    required this.business,
    this.scanService,
    this.picker,
    this.initialFiles,
  });

  @override
  State<ScanMenuSheet> createState() => _ScanMenuSheetState();
}

class _ScanMenuSheetState extends State<ScanMenuSheet> {
  late final ScanService _scanService;
  late final ImagePicker _picker;

  final List<XFile> _selectedFiles = [];
  bool _isScanning = false;
  bool _isCancelled = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scanService = widget.scanService ?? ScanService();
    _picker = widget.picker ?? ImagePicker();

    if (widget.initialFiles != null) {
      _selectedFiles.addAll(widget.initialFiles!);
    }
  }

  Future<void> _takePhoto() async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          _showCameraPermissionDialog();
        }
        return;
      }

      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );

      if (photo != null && mounted) {
        if (_selectedFiles.length < 4) {
          setState(() {
            _selectedFiles.add(photo);
            _errorMessage = null;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Maximum 4 photos allowed.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not access camera: $e';
        });
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final images = await _picker.pickMultiImage(
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );

      if (images.isNotEmpty && mounted) {
        setState(() {
          for (final img in images) {
            if (_selectedFiles.length < 4) {
              _selectedFiles.add(img);
            }
          }
          _errorMessage = null;
        });

        if (images.length + _selectedFiles.length > 4 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Maximum 4 photos allowed. Extra photos ignored.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not access photos: $e';
        });
      }
    }
  }

  void _showCameraPermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Camera Permission Needed'),
        content: const Text(
          'MARKet requires camera access so you can photograph your store\'s menu, price list, or service sheet to automatically extract items for your catalog.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _removePhoto(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<void> _startScan() async {
    if (_selectedFiles.isEmpty) return;

    setState(() {
      _isScanning = true;
      _isCancelled = false;
      _errorMessage = null;
    });

    try {
      final imagePayloads = <Map<String, String>>[];
      for (final file in _selectedFiles) {
        final bytes = await file.readAsBytes();
        final base64Str = base64Encode(bytes);
        final ext = file.name.split('.').lastOrNull?.toLowerCase() ?? 'jpg';
        final mime = ext == 'png'
            ? 'image/png'
            : (ext == 'webp' ? 'image/webp' : 'image/jpeg');

        imagePayloads.add({
          'mime': mime,
          'data': base64Str,
        });
      }

      if (_isCancelled) return;

      final result = await _scanService.scanMenu(
        images: imagePayloads,
        businessType: widget.business.category,
      );

      if (_isCancelled) return;

      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } on ScanException catch (e) {
      if (!_isCancelled && mounted) {
        setState(() {
          _isScanning = false;
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      if (!_isCancelled && mounted) {
        setState(() {
          _isScanning = false;
          _errorMessage =
              'The menu scanner is temporarily unavailable. Please try again shortly.';
        });
      }
    }
  }

  void _cancelScan() {
    setState(() {
      _isCancelled = true;
      _isScanning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: MarketColors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
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

          // Header
          Row(
            children: [
              const Icon(
                Icons.document_scanner_outlined,
                size: 24,
                color: MarketColors.primary,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Scan Menu or Price List',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: MarketColors.onSurface,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Photograph or upload up to 4 pages of your menu or service list. Items and prices will be extracted for your review.',
            style: TextStyle(
              fontSize: 12,
              color: MarketColors.secondary,
            ),
          ),
          const SizedBox(height: 16),

          // Progress State: Reading your menu...
          if (_isScanning) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              decoration: BoxDecoration(
                color: MarketColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: MarketColors.cardBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 44,
                    height: 44,
                    child: CircularProgressIndicator(
                      color: MarketColors.primary,
                      strokeWidth: 3.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Reading your menu...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: MarketColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Extracting items, prices, and categories with Gemini AI.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: MarketColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SecondaryButton(
                    key: const Key('cancel_scan_button'),
                    label: 'Cancel',
                    height: 38,
                    onPressed: _cancelScan,
                  ),
                ],
              ),
            ),
          ] else ...[
            // Error Message with Retry
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MarketColors.errorContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: MarketColors.error.withValues(alpha: 0.5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: MarketColors.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: MarketColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Photo Source Options
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('take_photo_button'),
                    onPressed: _selectedFiles.length >= 4 ? null : _takePhoto,
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: const Text('Take photo'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MarketColors.primary,
                      side: const BorderSide(color: MarketColors.primary),
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('choose_gallery_button'),
                    onPressed: _selectedFiles.length >= 4 ? null : _pickFromGallery,
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('From gallery'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MarketColors.primary,
                      side: const BorderSide(color: MarketColors.primary),
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Thumbnail List with Remove Actions
            if (_selectedFiles.isNotEmpty) ...[
              Text(
                'Selected Photos (${_selectedFiles.length}/4):',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MarketColors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 84,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedFiles.length,
                  separatorBuilder: (_, index) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final file = _selectedFiles[index];
                    return Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: MarketColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: MarketColors.cardBorder),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: FutureBuilder<List<int>>(
                              future: file.readAsBytes(),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  return Image.memory(
                                    Uint8List.fromList(snapshot.data!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (ctx, err, stack) => const Center(
                                      child: Icon(Icons.receipt_long, size: 28, color: MarketColors.primary),
                                    ),
                                  );
                                }
                                return const Center(
                                  child: Icon(Icons.image, size: 28, color: MarketColors.outline),
                                );
                              },
                            ),
                          ),
                        ),
                        PositionTileRemove(
                          key: Key('remove_photo_$index'),
                          onRemove: () => _removePhoto(index),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
            ],

            // Action Button
            if (_errorMessage != null)
              PrimaryButton(
                key: const Key('retry_scan_button'),
                width: double.infinity,
                height: 48,
                label: 'Retry Scan',
                onPressed: _selectedFiles.isNotEmpty ? _startScan : null,
              )
            else
              PrimaryButton(
                key: const Key('scan_photos_button'),
                width: double.infinity,
                height: 48,
                label: _selectedFiles.isEmpty
                    ? 'Select at least 1 photo'
                    : 'Scan ${_selectedFiles.length} ${_selectedFiles.length == 1 ? 'photo' : 'photos'}',
                onPressed: _selectedFiles.isNotEmpty ? _startScan : null,
              ),
          ],
        ],
      ),
    );
  }
}

class PositionTileRemove extends StatelessWidget {
  final VoidCallback onRemove;

  const PositionTileRemove({super.key, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 2,
      right: 2,
      child: GestureDetector(
        onTap: onRemove,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(
            color: Colors.black87,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.close,
            size: 14,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
