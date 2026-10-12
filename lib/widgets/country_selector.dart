import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Country information model with validation parameters.
class CountryInfo {
  final String name;
  final String isoCode;
  final String dialCode;
  final String flag;
  final int minDigits;
  final int maxDigits;

  const CountryInfo({
    required this.name,
    required this.isoCode,
    required this.dialCode,
    required this.flag,
    this.minDigits = 7,
    this.maxDigits = 12,
  });
}

/// Predefined country list with Philippines default (+63) first.
const List<CountryInfo> kCountries = [
  CountryInfo(
    name: 'Philippines',
    isoCode: 'PH',
    dialCode: '+63',
    flag: '🇵🇭',
    minDigits: 10,
    maxDigits: 10,
  ),
  CountryInfo(
    name: 'United States',
    isoCode: 'US',
    dialCode: '+1',
    flag: '🇺🇸',
    minDigits: 10,
    maxDigits: 10,
  ),
  CountryInfo(
    name: 'Canada',
    isoCode: 'CA',
    dialCode: '+1',
    flag: '🇨🇦',
    minDigits: 10,
    maxDigits: 10,
  ),
  CountryInfo(
    name: 'United Kingdom',
    isoCode: 'GB',
    dialCode: '+44',
    flag: '🇬🇧',
    minDigits: 10,
    maxDigits: 10,
  ),
  CountryInfo(
    name: 'Australia',
    isoCode: 'AU',
    dialCode: '+61',
    flag: '🇦🇺',
    minDigits: 9,
    maxDigits: 9,
  ),
  CountryInfo(
    name: 'Singapore',
    isoCode: 'SG',
    dialCode: '+65',
    flag: '🇸🇬',
    minDigits: 8,
    maxDigits: 8,
  ),
  CountryInfo(
    name: 'Japan',
    isoCode: 'JP',
    dialCode: '+81',
    flag: '🇯🇵',
    minDigits: 10,
    maxDigits: 10,
  ),
  CountryInfo(
    name: 'South Korea',
    isoCode: 'KR',
    dialCode: '+82',
    flag: '🇰🇷',
    minDigits: 9,
    maxDigits: 10,
  ),
  CountryInfo(
    name: 'United Arab Emirates',
    isoCode: 'AE',
    dialCode: '+971',
    flag: '🇦🇪',
    minDigits: 9,
    maxDigits: 9,
  ),
  CountryInfo(
    name: 'Saudi Arabia',
    isoCode: 'SA',
    dialCode: '+966',
    flag: '🇸🇦',
    minDigits: 9,
    maxDigits: 9,
  ),
  CountryInfo(
    name: 'Hong Kong',
    isoCode: 'HK',
    dialCode: '+852',
    flag: '🇭🇰',
    minDigits: 8,
    maxDigits: 8,
  ),
  CountryInfo(
    name: 'Taiwan',
    isoCode: 'TW',
    dialCode: '+886',
    flag: '🇹🇼',
    minDigits: 9,
    maxDigits: 9,
  ),
  CountryInfo(
    name: 'Malaysia',
    isoCode: 'MY',
    dialCode: '+60',
    flag: '🇲🇾',
    minDigits: 9,
    maxDigits: 10,
  ),
  CountryInfo(
    name: 'Indonesia',
    isoCode: 'ID',
    dialCode: '+62',
    flag: '🇮🇩',
    minDigits: 9,
    maxDigits: 12,
  ),
  CountryInfo(
    name: 'Thailand',
    isoCode: 'TH',
    dialCode: '+66',
    flag: '🇹🇭',
    minDigits: 9,
    maxDigits: 9,
  ),
  CountryInfo(
    name: 'Vietnam',
    isoCode: 'VN',
    dialCode: '+84',
    flag: '🇻🇳',
    minDigits: 9,
    maxDigits: 10,
  ),
  CountryInfo(
    name: 'India',
    isoCode: 'IN',
    dialCode: '+91',
    flag: '🇮🇳',
    minDigits: 10,
    maxDigits: 10,
  ),
  CountryInfo(
    name: 'China',
    isoCode: 'CN',
    dialCode: '+86',
    flag: '🇨🇳',
    minDigits: 11,
    maxDigits: 11,
  ),
  CountryInfo(
    name: 'Germany',
    isoCode: 'DE',
    dialCode: '+49',
    flag: '🇩🇪',
    minDigits: 10,
    maxDigits: 11,
  ),
  CountryInfo(
    name: 'France',
    isoCode: 'FR',
    dialCode: '+33',
    flag: '🇫🇷',
    minDigits: 9,
    maxDigits: 9,
  ),
  CountryInfo(
    name: 'Italy',
    isoCode: 'IT',
    dialCode: '+39',
    flag: '🇮🇹',
    minDigits: 9,
    maxDigits: 10,
  ),
  CountryInfo(
    name: 'Spain',
    isoCode: 'ES',
    dialCode: '+34',
    flag: '🇪🇸',
    minDigits: 9,
    maxDigits: 9,
  ),
  CountryInfo(
    name: 'New Zealand',
    isoCode: 'NZ',
    dialCode: '+64',
    flag: '🇳🇿',
    minDigits: 8,
    maxDigits: 10,
  ),
  CountryInfo(
    name: 'Qatar',
    isoCode: 'QA',
    dialCode: '+974',
    flag: '🇶🇦',
    minDigits: 8,
    maxDigits: 8,
  ),
  CountryInfo(
    name: 'Kuwait',
    isoCode: 'KW',
    dialCode: '+965',
    flag: '🇰🇼',
    minDigits: 8,
    maxDigits: 8,
  ),
];

/// Strips all non-digit characters and removes any leading 0.
String cleanPhoneNumber(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  return digits;
}

/// Builds the international phone number string (e.g. +639171234567).
String buildInternationalPhone(String rawNumber, CountryInfo country) {
  final cleaned = cleanPhoneNumber(rawNumber);
  return '${country.dialCode}$cleaned';
}

/// Validates phone number input against country digits rules.
String? validatePhoneNumber(String? value, CountryInfo country) {
  if (value == null || value.trim().isEmpty) {
    return 'Mobile number is required';
  }
  final cleaned = cleanPhoneNumber(value);
  if (cleaned.isEmpty) {
    return 'Enter digits only';
  }
  if (cleaned.length < country.minDigits || cleaned.length > country.maxDigits) {
    if (country.minDigits == country.maxDigits) {
      return 'Enter valid ${country.minDigits}-digit number for ${country.name}';
    }
    return 'Enter valid ${country.minDigits}-${country.maxDigits} digits for ${country.name}';
  }
  return null;
}

/// Formats stored phone number for display on review and account screens.
/// If already has country code (e.g. starts with +), displays it.
/// If existing number without country code, preserves and displays as is.
String formatPhoneDisplay(String? phone) {
  if (phone == null || phone.trim().isEmpty) {
    return 'No phone set';
  }
  return phone.trim();
}

/// Tappable button showing current country flag, dial code, and dropdown arrow.
class CountrySelectorButton extends StatelessWidget {
  final CountryInfo selectedCountry;
  final ValueChanged<CountryInfo> onCountryChanged;

  const CountrySelectorButton({
    super.key,
    required this.selectedCountry,
    required this.onCountryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showCountryPickerDialog(
        context,
        initial: selectedCountry,
        onSelect: onCountryChanged,
      ),
      borderRadius: BorderRadius.circular(MarketRadii.input),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: MarketColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(MarketRadii.input),
          border: Border.all(color: MarketColors.fieldBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedCountry.flag,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(width: 4),
            Text(
              selectedCountry.dialCode,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: MarketColors.onSurface,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.arrow_drop_down_rounded,
              color: MarketColors.outline,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal bottom sheet allowing searching and selecting a country.
Future<void> showCountryPickerDialog(
  BuildContext context, {
  CountryInfo? initial,
  required ValueChanged<CountryInfo> onSelect,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CountryPickerSheet(
      initial: initial,
      onSelect: onSelect,
    ),
  );
}

class _CountryPickerSheet extends StatefulWidget {
  final CountryInfo? initial;
  final ValueChanged<CountryInfo> onSelect;

  const _CountryPickerSheet({
    this.initial,
    required this.onSelect,
  });

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<CountryInfo> _filteredCountries = kCountries;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCountries = kCountries;
      } else {
        _filteredCountries = kCountries.where((c) {
          return c.name.toLowerCase().contains(query) ||
              c.dialCode.toLowerCase().contains(query) ||
              c.isoCode.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: MarketColors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: MarketColors.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Select Country',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: MarketColors.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              autofocus: false,
              decoration: InputDecoration(
                hintText: 'Search by country or dial code...',
                hintStyle: const TextStyle(
                  fontSize: 14,
                  color: MarketColors.outline,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: MarketColors.outline,
                ),
                filled: true,
                fillColor: MarketColors.surfaceContainerLow,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(MarketRadii.input),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _filteredCountries.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No matching country found',
                        style: TextStyle(
                          fontSize: 14,
                          color: MarketColors.outline,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredCountries.length,
                    itemBuilder: (context, index) {
                      final country = _filteredCountries[index];
                      final isSelected = widget.initial?.isoCode == country.isoCode;

                      return ListTile(
                        leading: Text(
                          country.flag,
                          style: const TextStyle(fontSize: 24),
                        ),
                        title: Text(
                          country.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: MarketColors.onSurface,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              country.dialCode,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? MarketColors.primary
                                    : MarketColors.onSurfaceVariant,
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.check_rounded,
                                color: MarketColors.primary,
                                size: 18,
                              ),
                            ],
                          ],
                        ),
                        onTap: () {
                          widget.onSelect(country);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
