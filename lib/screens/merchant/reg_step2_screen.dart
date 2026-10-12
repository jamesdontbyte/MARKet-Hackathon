import 'package:flutter/material.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_text_field.dart';
import 'merchant_reg_controller.dart';
import 'reg_step3_screen.dart';
import 'widgets/merchant_reg_stepper.dart';

/// MSME Registration Step 2: Business Information & GPS Location
/// Matches Stitch frame: market_msme_registration_step_2_business_information
class RegStep2Screen extends StatefulWidget {
  final MerchantRegController controller;

  const RegStep2Screen({
    super.key,
    required this.controller,
  });

  @override
  State<RegStep2Screen> createState() => _RegStep2ScreenState();
}

class _RegStep2ScreenState extends State<RegStep2Screen> {
  final _formKey = GlobalKey<FormState>();
  late final MerchantRegController _regController;

  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _hoursController;

  late String _selectedCategory;
  late String _selectedMunicipality;
  String? _errorMessage;

  final List<String> _municipalities = [
    'San Jose de Buenavista, Antique',
    'Sibalom, Antique',
    'Hamtic, Antique',
    'Belison, Antique',
    'Patnongon, Antique',
    'Iloilo City, Iloilo',
  ];

  @override
  void initState() {
    super.initState();
    _regController = widget.controller;

    _nameController = TextEditingController(
      text: _regController.businessName,
    );
    _bioController = TextEditingController(
      text: _regController.bio,
    );
    _addressController = TextEditingController(
      text: _regController.address,
    );
    _phoneController = TextEditingController(
      text: _regController.contactPhone.isNotEmpty
          ? _regController.contactPhone
          : _regController.phone,
    );
    _hoursController = TextEditingController(
      text: _regController.hours,
    );

    _selectedCategory = _regController.category;

    _selectedMunicipality = _municipalities.contains(_regController.municipality)
        ? _regController.municipality
        : _municipalities.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  void _onContinue() {
    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategory.isEmpty) {
      setState(() {
        _errorMessage = 'Please select a primary category';
      });
      return;
    }

    if (_regController.lat == null || _regController.lng == null) {
      setState(() {
        _errorMessage = 'Please tap "Use my current location" to set store GPS coordinates';
      });
      return;
    }

    _regController.businessName = _nameController.text.trim();
    _regController.category = _selectedCategory;
    _regController.bio = _bioController.text.trim();
    _regController.municipality = _selectedMunicipality;
    _regController.address = _addressController.text.trim();
    _regController.contactPhone = _phoneController.text.trim();
    _regController.hours = _hoursController.text.trim();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RegStep3Screen(controller: _regController),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarketColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: MarketColors.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Business Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MarketColors.onSurface,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: MarketSpacing.screenMargin,
                  vertical: 12,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 4-Step Stepper
                      const MerchantRegStepper(currentStep: 2),
                      const SizedBox(height: 20),

                      // Section Title
                      const Text(
                        'Business Information',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: MarketColors.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Step 2 of 4: Tell nearby customers about your shop and storefront.',
                        style: TextStyle(
                          fontSize: 13,
                          color: MarketColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: MarketColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(MarketRadii.button),
                            border: Border.all(color: MarketColors.error.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: MarketColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Form Card Container
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: MarketColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: MarketColors.outlineVariant.withValues(alpha: 0.3),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0A0F172A),
                              offset: Offset(0, 4),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Business Name
                            AppTextField(
                              controller: _nameController,
                              label: 'Registered Business Name *',
                              hintText: "e.g. Maria's Artisan Bakery",
                              prefixIcon: const Icon(Icons.storefront_rounded, size: 20, color: MarketColors.outline),
                              helperText: 'Must match your DTI or BIR trade name',
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Business name is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // 2. Category Selection (8 canonical slugs)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Primary Category *',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: MarketColors.onSurface,
                                  ),
                                ),
                                Text(
                                  _selectedCategory.isEmpty
                                      ? 'None selected'
                                      : (categoryLabels[_selectedCategory] ?? _selectedCategory),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _selectedCategory.isEmpty
                                        ? MarketColors.outline
                                        : MarketColors.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: canonicalCategories.map((slug) {
                                final isSelected = _selectedCategory == slug;
                                final label = categoryLabels[slug] ?? slug;

                                return ChoiceChip(
                                  label: Text(label),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _selectedCategory = slug;
                                      });
                                    }
                                  },
                                  selectedColor: MarketColors.primaryContainer,
                                  backgroundColor: MarketColors.surfaceContainerLow,
                                  labelStyle: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? MarketColors.onSurface : MarketColors.onSurfaceVariant,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: BorderSide(
                                      color: isSelected
                                          ? MarketColors.primaryContainer
                                          : MarketColors.outlineVariant.withValues(alpha: 0.4),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),

                            // 3. Shop Bio & Specialties
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Shop Bio & Specialties',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: MarketColors.onSurface,
                                  ),
                                ),
                                AnimatedBuilder(
                                  animation: _bioController,
                                  builder: (context, _) => Text(
                                    '${_bioController.text.length} / 250',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: MarketColors.outline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _bioController,
                              maxLines: 3,
                              maxLength: 250,
                              decoration: InputDecoration(
                                counterText: '',
                                hintText: 'Describe your specialties and local heritage...',
                                filled: true,
                                fillColor: MarketColors.surfaceContainerLowest,
                                contentPadding: const EdgeInsets.all(14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(MarketRadii.input),
                                  borderSide: const BorderSide(color: MarketColors.fieldBorder),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(MarketRadii.input),
                                  borderSide: const BorderSide(color: MarketColors.fieldBorder),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(MarketRadii.input),
                                  borderSide: const BorderSide(
                                    color: MarketColors.primaryContainer,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Visible on nearby search snippets and community maps.',
                              style: TextStyle(
                                fontSize: 11,
                                color: MarketColors.outline,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Divider(height: 1),
                            const SizedBox(height: 16),

                            // 4. Location & Contact
                            Row(
                              children: const [
                                Icon(Icons.pin_drop_rounded,
                                    color: MarketColors.primary, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Location & Contact',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: MarketColors.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // City / Municipality Dropdown
                            const Text(
                              'City / Municipality *',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: MarketColors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: MarketColors.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(MarketRadii.input),
                                border: Border.all(color: MarketColors.fieldBorder),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedMunicipality,
                                  isExpanded: true,
                                  icon: const Icon(Icons.expand_more_rounded,
                                      color: MarketColors.outline),
                                  items: _municipalities.map((item) {
                                    return DropdownMenuItem(
                                      value: item,
                                      child: Text(item),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _selectedMunicipality = val;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Street Address
                            AppTextField(
                              controller: _addressController,
                              label: 'Street Address & Barangay *',
                              hintText: 'Street name, Bldg No., Barangay',
                              prefixIcon: const Icon(Icons.home_work_outlined, size: 20, color: MarketColors.outline),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Address is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Business Contact Phone
                            const Text(
                              'Business Hotline / Mobile *',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: MarketColors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  height: 52,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: MarketColors.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(MarketRadii.input),
                                    border: Border.all(color: MarketColors.fieldBorder),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    '🇵🇭 +63',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: MarketColors.onSurface,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    decoration: InputDecoration(
                                      hintText: '9XX XXX XXXX',
                                      filled: true,
                                      fillColor: MarketColors.surfaceContainerLowest,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(MarketRadii.input),
                                        borderSide: const BorderSide(color: MarketColors.fieldBorder),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(MarketRadii.input),
                                        borderSide: const BorderSide(color: MarketColors.fieldBorder),
                                      ),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Phone is required';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Operating Hours
                            AppTextField(
                              controller: _hoursController,
                              label: 'Operating Hours *',
                              hintText: 'e.g. Mon – Sun: 7:00 AM – 9:00 PM',
                              prefixIcon: const Icon(Icons.schedule_rounded, size: 20, color: MarketColors.outline),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Operating hours required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            const Divider(height: 1),
                            const SizedBox(height: 16),

                            // GPS Coordinates & Button
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Store GPS Coordinates',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: MarketColors.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    ListenableBuilder(
                                      listenable: _regController,
                                      builder: (context, _) => Text(
                                        _regController.lat != null && _regController.lng != null
                                            ? 'Lat: ${_regController.lat!.toStringAsFixed(6)}, Lng: ${_regController.lng!.toStringAsFixed(6)}'
                                            : 'Coordinates not set',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _regController.lat != null
                                              ? MarketColors.primary
                                              : MarketColors.outline,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // "Use my current location" Button
                            ListenableBuilder(
                              listenable: _regController,
                              builder: (context, _) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(double.infinity, 46),
                                        side: const BorderSide(color: MarketColors.primaryContainer),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      icon: _regController.isLocating
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : const Icon(Icons.my_location_rounded,
                                              size: 18, color: MarketColors.primary),
                                      label: Text(
                                        _regController.isLocating
                                            ? 'Acquiring GPS fix...'
                                            : 'Use my current location',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: MarketColors.primary,
                                        ),
                                      ),
                                      onPressed: _regController.isLocating
                                          ? null
                                          : () => _regController.useCurrentLocation(),
                                    ),
                                    if (_regController.locationMessage != null) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        _regController.locationMessage!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: _regController.lat != null
                                              ? MarketColors.outline
                                              : MarketColors.error,
                                        ),
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),

            // Sticky Bottom Continue Button
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: MarketSpacing.screenMargin,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: MarketColors.surface,
                border: Border(
                  top: BorderSide(
                    color: MarketColors.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A0F172A),
                    offset: Offset(0, -4),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: PrimaryButton(
                width: double.infinity,
                height: 52,
                label: 'Continue to Business Verification',
                icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                onPressed: _onContinue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
