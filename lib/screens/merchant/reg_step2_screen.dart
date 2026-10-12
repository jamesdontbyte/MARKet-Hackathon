import 'package:flutter/material.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/country_selector.dart';
import 'merchant_reg_controller.dart';
import 'reg_step3_screen.dart';
import 'widgets/merchant_reg_stepper.dart';

/// MSME Registration Step 2: Business Information & Store Photos
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
  final AuthService _authService = AuthService();
  final DataService _dataService = DataService();

  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;

  late String _selectedCategory;
  late String _selectedMunicipality;
  late CountryInfo _selectedCountry;

  // Operating Hours State
  final List<String> _dayKeys = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final List<String> _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  late Set<String> _selectedDays;
  late bool _sameHoursDaily;
  late TimeOfDay _opensAt;
  late TimeOfDay _closesAt;

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

    // All business data starts empty unless resumed from controller
    _nameController = TextEditingController(text: _regController.businessName);
    _bioController = TextEditingController(text: _regController.bio);
    _addressController = TextEditingController(text: _regController.address);

    // Initial country & phone extraction
    _selectedCountry = kCountries.first; // +63 Philippines default
    String initialPhoneDigits = _regController.contactPhone;
    if (initialPhoneDigits.startsWith('+')) {
      for (final country in kCountries) {
        if (initialPhoneDigits.startsWith(country.dialCode)) {
          _selectedCountry = country;
          initialPhoneDigits = initialPhoneDigits.substring(country.dialCode.length);
          break;
        }
      }
    }
    _phoneController = TextEditingController(text: initialPhoneDigits);

    _selectedCategory = _regController.category;
    _selectedMunicipality = _regController.municipality.isNotEmpty &&
            _municipalities.contains(_regController.municipality)
        ? _regController.municipality
        : _municipalities.first;

    _selectedDays = Set<String>.from(_regController.openDays);
    if (_selectedDays.isEmpty) {
      _selectedDays = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'};
    }
    _sameHoursDaily = _regController.sameHoursDaily;

    _opensAt = _parseTimeOfDay(_regController.opensAt) ?? const TimeOfDay(hour: 7, minute: 30);
    _closesAt = _parseTimeOfDay(_regController.closesAt) ?? const TimeOfDay(hour: 21, minute: 0);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  TimeOfDay? _parseTimeOfDay(String str) {
    try {
      final clean = str.trim().toUpperCase().replaceAll('AM', '').replaceAll('PM', '').trim();
      final parts = clean.split(':');
      if (parts.length >= 2) {
        var h = int.parse(parts[0].trim());
        final m = int.parse(parts[1].trim());
        if (str.toUpperCase().contains('PM') && h < 12) h += 12;
        if (str.toUpperCase().contains('AM') && h == 12) h = 0;
        return TimeOfDay(hour: h, minute: m);
      }
    } catch (_) {}
    return null;
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final h12 = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final mStr = tod.minute.toString().padLeft(2, '0');
    final ampm = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h12:$mStr $ampm';
  }

  String _formatTime24(TimeOfDay tod) {
    final hStr = tod.hour.toString().padLeft(2, '0');
    final mStr = tod.minute.toString().padLeft(2, '0');
    return '$hStr:$mStr';
  }

  Future<void> _selectTime({required bool isOpensAt}) async {
    final initial = isOpensAt ? _opensAt : _closesAt;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      setState(() {
        if (isOpensAt) {
          _opensAt = picked;
        } else {
          _closesAt = picked;
        }
      });
    }
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

    // Exterior photo is required
    final hasCover = _regController.coverBytes != null ||
        (_regController.coverUrl != null && _regController.coverUrl!.isNotEmpty);
    if (!hasCover) {
      setState(() {
        _errorMessage = 'Storefront exterior photo is required (16:9 ratio)';
      });
      return;
    }

    if (_regController.lat == null || _regController.lng == null) {
      setState(() {
        _errorMessage = 'Please tap "Use my current location" to set store GPS coordinates';
      });
      return;
    }

    // Save fields into controller
    _regController.businessName = _nameController.text.trim();
    _regController.category = _selectedCategory;
    _regController.bio = _bioController.text.trim();
    _regController.municipality = _selectedMunicipality;
    _regController.address = _addressController.text.trim();
    _regController.contactPhone = buildInternationalPhone(_phoneController.text, _selectedCountry);

    // Save hours
    _regController.openDays = _selectedDays.toList();
    _regController.sameHoursDaily = _sameHoursDaily;
    _regController.opensAt = _formatTime24(_opensAt);
    _regController.closesAt = _formatTime24(_closesAt);
    _regController.hours =
        '${_selectedDays.join(', ')}: ${_formatTimeOfDay(_opensAt)} – ${_formatTimeOfDay(_closesAt)}';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RegStep3Screen(controller: _regController),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _authService.currentUserId ?? '';

    return Scaffold(
      backgroundColor: MarketColors.surface,
      appBar: const AppHeader(
        showBack: true,
        subtitle: 'Registration',
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

                      // Section Header
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: MarketColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.storefront_rounded,
                                color: MarketColors.primary, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Business Information',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: MarketColors.onSurface,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Tell customers about your brand and services',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: MarketColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: MarketColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(MarketRadii.button),
                            border: Border.all(color: MarketColors.error.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: MarketColors.error, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: MarketColors.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
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
                              hintText: 'e.g. Kape Tahanan Specialty Brews',
                              prefixIcon: const Icon(Icons.store_rounded, size: 20, color: MarketColors.outline),
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
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
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
                                      ? 'Select one'
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
                                  avatar: isSelected
                                      ? const Icon(Icons.check_circle_rounded,
                                          size: 16, color: MarketColors.primary)
                                      : null,
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
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
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
                                hintText: 'Describe your specialty and what makes your shop unique to nearby customers...',
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

                            // 4. Location & Contact Subsection
                            Row(
                              children: const [
                                Icon(Icons.pin_drop_rounded,
                                    color: MarketColors.primary, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Location & Contact',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: MarketColors.onSurface,
                                    ),
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

                            // Hotline with Country Code Selector
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CountrySelectorButton(
                                  selectedCountry: _selectedCountry,
                                  onCountryChanged: (c) {
                                    setState(() {
                                      _selectedCountry = c;
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    decoration: InputDecoration(
                                      hintText: _selectedCountry.isoCode == 'PH' ? '9XX XXX XXXX' : 'Mobile number',
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
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(MarketRadii.input),
                                        borderSide: const BorderSide(
                                          color: MarketColors.primaryContainer,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                    validator: (v) => validatePhoneNumber(v, _selectedCountry),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            const Divider(height: 1),
                            const SizedBox(height: 16),

                            // 5. Operating Hours Subsection
                            Row(
                              children: const [
                                Icon(Icons.schedule_rounded,
                                    color: MarketColors.primary, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Operating Hours',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: MarketColors.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Configure when your storefront is open for orders and pickup.',
                              style: TextStyle(
                                fontSize: 13,
                                color: MarketColors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Day of Week Toggle Pills
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: MarketColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: MarketColors.outlineVariant.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: const [
                                      Text(
                                        'Active Days',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: MarketColors.onSurface,
                                        ),
                                      ),
                                      Text(
                                        'Tap day to toggle',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: MarketColors.outline,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: List.generate(_dayKeys.length, (idx) {
                                      final dayKey = _dayKeys[idx];
                                      final isSelected = _selectedDays.contains(dayKey);

                                      return Expanded(
                                        child: Padding(
                                          padding: EdgeInsets.only(right: idx < _dayKeys.length - 1 ? 4 : 0),
                                          child: InkWell(
                                            onTap: () {
                                              setState(() {
                                                if (isSelected) {
                                                  if (_selectedDays.length > 1) {
                                                    _selectedDays.remove(dayKey);
                                                  }
                                                } else {
                                                  _selectedDays.add(dayKey);
                                                }
                                              });
                                            },
                                            borderRadius: BorderRadius.circular(10),
                                            child: Container(
                                              height: 48,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? MarketColors.primary
                                                    : MarketColors.surfaceContainerLowest,
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: isSelected
                                                      ? MarketColors.primary
                                                      : MarketColors.outlineVariant.withValues(alpha: 0.4),
                                                ),
                                              ),
                                              child: Text(
                                                _dayLabels[idx],
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: isSelected
                                                      ? MarketColors.onPrimary
                                                      : MarketColors.outline,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(height: 1),
                                  const SizedBox(height: 12),

                                  // Same hours daily toggle
                                  Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      const Text(
                                        'Default Store Hours',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: MarketColors.onSurface,
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Flexible(
                                            child: Text(
                                              'Same hours daily',
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: MarketColors.secondary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Switch(
                                            value: _sameHoursDaily,
                                            activeThumbColor: MarketColors.primaryContainer,
                                            onChanged: (val) {
                                              setState(() {
                                                _sameHoursDaily = val;
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Opens at / Closes at Dual Time Slots
                                  Row(
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: () => _selectTime(isOpensAt: true),
                                          borderRadius: BorderRadius.circular(12),
                                          child: Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: MarketColors.surfaceContainerLowest,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: MarketColors.outlineVariant.withValues(alpha: 0.5),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Opens at',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: MarketColors.outline,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Wrap(
                                                  alignment: WrapAlignment.spaceBetween,
                                                  crossAxisAlignment: WrapCrossAlignment.center,
                                                  spacing: 4,
                                                  runSpacing: 2,
                                                  children: [
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.schedule_rounded,
                                                            size: 16, color: MarketColors.primary),
                                                        const SizedBox(width: 4),
                                                        Flexible(
                                                          child: Text(
                                                            _formatTimeOfDay(_opensAt).split(' ')[0],
                                                            overflow: TextOverflow.ellipsis,
                                                            style: const TextStyle(
                                                              fontSize: 16,
                                                              fontWeight: FontWeight.w700,
                                                              color: MarketColors.onSurface,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: MarketColors.surfaceContainerLow,
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        _formatTimeOfDay(_opensAt).split(' ').last,
                                                        style: const TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w700,
                                                          color: MarketColors.primary,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: InkWell(
                                          onTap: () => _selectTime(isOpensAt: false),
                                          borderRadius: BorderRadius.circular(12),
                                          child: Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: MarketColors.surfaceContainerLowest,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: MarketColors.outlineVariant.withValues(alpha: 0.5),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Closes at',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: MarketColors.outline,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Wrap(
                                                  alignment: WrapAlignment.spaceBetween,
                                                  crossAxisAlignment: WrapCrossAlignment.center,
                                                  spacing: 4,
                                                  runSpacing: 2,
                                                  children: [
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.bedtime_rounded,
                                                            size: 16, color: MarketColors.primary),
                                                        const SizedBox(width: 4),
                                                        Flexible(
                                                          child: Text(
                                                            _formatTimeOfDay(_closesAt).split(' ')[0],
                                                            overflow: TextOverflow.ellipsis,
                                                            style: const TextStyle(
                                                              fontSize: 16,
                                                              fontWeight: FontWeight.w700,
                                                              color: MarketColors.onSurface,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: MarketColors.surfaceContainerLow,
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        _formatTimeOfDay(_closesAt).split(' ').last,
                                                        style: const TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w700,
                                                          color: MarketColors.primary,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Divider(height: 1),
                            const SizedBox(height: 16),

                            // 6. Store Photos & Branding Subsection
                            Row(
                              children: const [
                                Icon(Icons.add_photo_alternate_rounded,
                                    color: MarketColors.primary, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Store Photos & Branding',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: MarketColors.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Upload Slot A: Logo
                            ListenableBuilder(
                              listenable: _regController,
                              builder: (context, _) {
                                return _buildLogoSection(uid);
                              },
                            ),
                            const SizedBox(height: 16),

                            // Upload Slot B: Exterior Photo (Required, 16:9)
                            ListenableBuilder(
                              listenable: _regController,
                              builder: (context, _) {
                                return _buildExteriorSection(uid);
                              },
                            ),
                            const SizedBox(height: 16),

                            // Upload Slot C: Interior Photos (Optional, up to 3)
                            ListenableBuilder(
                              listenable: _regController,
                              builder: (context, _) {
                                return _buildInteriorSection(uid);
                              },
                            ),
                            const SizedBox(height: 20),
                            const Divider(height: 1),
                            const SizedBox(height: 16),

                            // 7. Store GPS Coordinates
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
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
                                ListenableBuilder(
                                  listenable: _regController,
                                  builder: (context, _) => ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: MarketColors.surfaceContainerLow,
                                      foregroundColor: MarketColors.primary,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: const BorderSide(color: MarketColors.fieldBorder),
                                      ),
                                    ),
                                    onPressed: _regController.isLocating
                                        ? null
                                        : () => _regController.useCurrentLocation(),
                                    icon: _regController.isLocating
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Icon(Icons.my_location_rounded, size: 16),
                                    label: const Text(
                                      'Use my location',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            ListenableBuilder(
                              listenable: _regController,
                              builder: (context, _) {
                                if (_regController.locationMessage != null) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      _regController.locationMessage!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _regController.lat != null
                                            ? MarketColors.primary
                                            : MarketColors.error,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
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

            // Sticky Bottom CTA Actions
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PrimaryButton(
                    width: double.infinity,
                    height: 50,
                    label: 'Continue to Permits',
                    icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                    onPressed: _onContinue,
                  ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16, color: MarketColors.secondary),
                    label: const Text(
                      'Back to Personal Info',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: MarketColors.secondary,
                      ),
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

  Widget _buildLogoSection(String uid) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MarketColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: MarketColors.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: MarketColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: MarketColors.outlineVariant.withValues(alpha: 0.4)),
            ),
            clipBehavior: Clip.antiAlias,
            child: _regController.logoBytes != null
                ? Image.memory(
                    _regController.logoBytes!,
                    fit: BoxFit.cover,
                  )
                : const Icon(Icons.account_circle_rounded,
                    size: 32, color: MarketColors.outline),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    const Text(
                      'Business Logo',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: MarketColors.onSurface,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: MarketColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Square',
                        style: TextStyle(fontSize: 10, color: MarketColors.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'PNG or JPG (Max 5MB)',
                  style: TextStyle(fontSize: 11, color: MarketColors.outline),
                ),
                if (_regController.logoError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _regController.logoError!,
                      style: const TextStyle(fontSize: 11, color: MarketColors.error),
                    ),
                  ),
              ],
            ),
          ),
          if (_regController.uploadingLogo)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (_regController.logoBytes != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: MarketColors.error, size: 20),
              onPressed: () => _regController.removeLogo(),
            )
          else
            TextButton.icon(
              icon: const Icon(Icons.upload_rounded, size: 16),
              label: const Text('Upload', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              onPressed: () => _regController.pickLogo(userId: uid, dataService: _dataService),
            ),
        ],
      ),
    );
  }

  Widget _buildExteriorSection(String uid) {
    final hasCover = _regController.coverBytes != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 2,
              children: [
                const Text(
                  'Storefront Exterior Photo',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MarketColors.onSurface,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: MarketColors.primaryContainer.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Required',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: MarketColors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const Text(
              '16:9 Ratio',
              style: TextStyle(fontSize: 11, color: MarketColors.outline),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (hasCover)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MarketColors.primaryContainer),
            ),
            clipBehavior: Clip.antiAlias,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(
                    _regController.coverBytes!,
                    fit: BoxFit.cover,
                  ),
                  // Dark gradient overlay on bottom
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0x99000000)],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    left: 12,
                    right: 12,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.check_circle_rounded,
                                  size: 14, color: MarketColors.primaryContainer),
                              SizedBox(width: 4),
                              Text(
                                'Cover Photo Ready',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          style: IconButton.styleFrom(backgroundColor: Colors.black54),
                          icon: const Icon(Icons.delete_rounded, color: Colors.white, size: 18),
                          onPressed: () => _regController.removeCover(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          InkWell(
            onTap: () => _regController.pickCover(userId: uid, dataService: _dataService),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: MarketColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: MarketColors.outlineVariant.withValues(alpha: 0.5),
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.add_a_photo_rounded, size: 32, color: MarketColors.primary),
                  SizedBox(height: 6),
                  Text(
                    'Upload Storefront Exterior Photo',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: MarketColors.onSurface,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'This becomes your cover image on customer discovery maps',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: MarketColors.outline),
                  ),
                ],
              ),
            ),
          ),

        if (_regController.coverError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _regController.coverError!,
              style: const TextStyle(fontSize: 11, color: MarketColors.error),
            ),
          ),
      ],
    );
  }

  Widget _buildInteriorSection(String uid) {
    final photos = _regController.interiorPhotos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 2,
              children: [
                const Text(
                  'Store Interior / Workspace',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MarketColors.onSurface,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: MarketColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Optional',
                    style: TextStyle(fontSize: 10, color: MarketColors.secondary),
                  ),
                ),
              ],
            ),
            Text(
              '${photos.length} / 3 images',
              style: const TextStyle(fontSize: 11, color: MarketColors.outline),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (photos.isNotEmpty)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ...List.generate(photos.length, (idx) {
                final item = photos[idx];
                return Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: MarketColors.outlineVariant.withValues(alpha: 0.4)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.memory(
                        item.bytes,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _regController.removeInteriorPhoto(idx),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              }),
              if (photos.length < 3)
                InkWell(
                  onTap: () => _regController.pickInteriorPhoto(userId: uid, dataService: _dataService),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: MarketColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: MarketColors.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.add_rounded, size: 24, color: MarketColors.primary),
                        Text('Add', style: TextStyle(fontSize: 11, color: MarketColors.outline)),
                      ],
                    ),
                  ),
                ),
            ],
          )
        else
          InkWell(
            onTap: () => _regController.pickInteriorPhoto(userId: uid, dataService: _dataService),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MarketColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: MarketColors.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: const [
                  Icon(Icons.add_photo_alternate_outlined, size: 24, color: MarketColors.primary),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tap to add interior photos',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: MarketColors.onSurface,
                          ),
                        ),
                        Text(
                          'Showcase your seating, counter, or display shelves',
                          style: TextStyle(fontSize: 11, color: MarketColors.outline),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

        if (_regController.interiorsError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _regController.interiorsError!,
              style: const TextStyle(fontSize: 11, color: MarketColors.error),
            ),
          ),
      ],
    );
  }
}
