import 'package:flutter/material.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/country_selector.dart';
import 'merchant_reg_controller.dart';
import 'reg_step2_screen.dart';
import 'widgets/merchant_reg_stepper.dart';

/// MSME Registration Step 1: Owner Basics & Mobile Verification
/// Matches Stitch frame: market_msme_registration_step_1_basics
class RegStep1Screen extends StatefulWidget {
  final MerchantRegController? controller;
  final AuthService? authService;

  const RegStep1Screen({
    super.key,
    this.controller,
    this.authService,
  });

  @override
  State<RegStep1Screen> createState() => _RegStep1ScreenState();
}

class _RegStep1ScreenState extends State<RegStep1Screen> {
  final _formKey = GlobalKey<FormState>();
  late final MerchantRegController _regController;
  late final AuthService _authService;

  late final TextEditingController _nameController;
  late final TextEditingController _dobController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  String? _dobError;
  CountryInfo _selectedCountry = kCountries.first;

  @override
  void initState() {
    super.initState();
    _regController = widget.controller ?? MerchantRegController();
    _authService = widget.authService ?? AuthService();

    _nameController = TextEditingController(text: _regController.fullName);
    _dobController = TextEditingController(text: _regController.dob);
    _emailController = TextEditingController(text: _regController.email);
    _passwordController = TextEditingController(text: _regController.password);
    _confirmPasswordController = TextEditingController(text: _regController.password);

    // Identify country from pre-existing phone in controller
    var initialPhone = _regController.phone;
    for (final c in kCountries) {
      if (initialPhone.startsWith(c.dialCode)) {
        _selectedCountry = c;
        initialPhone = initialPhone.substring(c.dialCode.length);
        break;
      }
    }
    _phoneController = TextEditingController(text: cleanPhoneNumber(initialPhone));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _formatDob(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final adultCutoff = DateTime(now.year - 18, now.month, now.day);
    final firstDate = DateTime(1900, 1, 1);
    final initialDate = _regController.dobDateTime ?? DateTime(now.year - 25, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(adultCutoff) ? adultCutoff : initialDate,
      firstDate: firstDate,
      lastDate: adultCutoff,
      helpText: 'Select Date of Birth',
    );

    if (picked != null) {
      if (picked.isAfter(adultCutoff)) {
        setState(() {
          _dobError = 'You must be at least 18';
        });
        return;
      }
      setState(() {
        _dobError = null;
        _dobController.text = _formatDob(picked);
        _regController.dob = _dobController.text;
        _regController.dobDateTime = picked;
      });
    }
  }

  Future<void> _onContinue() async {
    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) return;

    final rawPhone = _phoneController.text.trim();
    final fullPhone = buildInternationalPhone(rawPhone, _selectedCountry);

    // If OTP was already verified (e.g. going back from Step 2 to Step 1),
    // save any updated fields and advance straight to Step 2 WITHOUT re-running sign-up or showing OTP.
    if (_regController.isOtpVerified) {
      _regController.fullName = _nameController.text.trim();
      _regController.dob = _dobController.text.trim();
      _regController.phone = fullPhone;
      _regController.email = _emailController.text.trim();
      _regController.password = _passwordController.text;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RegStep2Screen(controller: _regController),
        ),
      );
      return;
    }

    // Open OTP bottom sheet for one-time verification and sign-up
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return _MerchantOtpBottomSheet(
          phone: cleanPhoneNumber(rawPhone),
          country: _selectedCountry,
          onVerifySuccess: () async {
            // Register merchant via Supabase Auth & create profiles row exactly once at Step 1
            await _authService.signUpMerchant(
              email: _emailController.text.trim(),
              password: _passwordController.text,
              fullName: _nameController.text.trim(),
              phone: fullPhone,
            );

            if (mounted) {
              setState(() {
                _regController.fullName = _nameController.text.trim();
                _regController.dob = _dobController.text.trim();
                _regController.phone = fullPhone;
                _regController.email = _emailController.text.trim();
                _regController.password = _passwordController.text;
                _regController.isOtpVerified = true;
              });
            }

            if (modalContext.mounted) {
              Navigator.of(modalContext).pop();
            }
            if (mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RegStep2Screen(controller: _regController),
                ),
              );
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
                      const MerchantRegStepper(currentStep: 1),
                      const SizedBox(height: 20),

                      // Exact Logo Icon
                      Image.asset(
                        'assets/logos/logo_icon.png',
                        width: 44,
                        height: 44,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 16),

                      // Section Title
                      const Text(
                        'Account & Owner Credentials',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: MarketColors.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Step 1 of 4: Enter owner details and verify your contact number.',
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
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: MarketColors.error, size: 20),
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

                      // Personal Information Container
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
                            // Card Header
                            Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: MarketColors.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.person_rounded,
                                    color: MarketColors.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Personal Information',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: MarketColors.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),

                            // Full Name
                            AppTextField(
                              controller: _nameController,
                              label: 'Full Name (Owner / Representative)',
                              hintText: 'e.g. Maria Santos',
                              prefixIcon: const Icon(Icons.badge_outlined, size: 20, color: MarketColors.outline),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Full name is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Date of Birth
                            AppTextField(
                              controller: _dobController,
                              readOnly: true,
                              onTap: _pickDateOfBirth,
                              label: 'Date of Birth',
                              hintText: 'Select date of birth',
                              errorText: _dobError,
                              prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20, color: MarketColors.outline),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Date of birth is required';
                                }
                                if (_dobError != null) return _dobError;
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Mobile Number with Country Selector
                            const Text(
                              'Mobile Number',
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
                            const SizedBox(height: 16),

                            // Email Address
                            AppTextField(
                              controller: _emailController,
                              label: 'Email Address',
                              hintText: 'name@business.com',
                              prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20, color: MarketColors.outline),
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Email is required';
                                }
                                if (!v.contains('@') || !v.contains('.')) {
                                  return 'Enter a valid email address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Password
                            AppTextField(
                              controller: _passwordController,
                              label: 'Account Password',
                              hintText: '••••••••••••',
                              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: MarketColors.outline),
                              obscureText: _obscurePassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: MarketColors.outline,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Password is required';
                                }
                                if (v.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Confirm Password
                            AppTextField(
                              controller: _confirmPasswordController,
                              label: 'Confirm Password',
                              hintText: '••••••••••••',
                              prefixIcon: const Icon(Icons.lock_reset_rounded, size: 20, color: MarketColors.outline),
                              obscureText: _obscureConfirmPassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: MarketColors.outline,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirmPassword = !_obscureConfirmPassword;
                                  });
                                },
                              ),
                              validator: (v) {
                                if (v != _passwordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
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
                label: 'Continue to Business Information',
                isLoading: false,
                onPressed: _onContinue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// OTP Modal Bottom Sheet with Demo Shortcut ("Demo code: 123456")
class _MerchantOtpBottomSheet extends StatefulWidget {
  final String phone;
  final CountryInfo country;
  final Future<void> Function() onVerifySuccess;

  const _MerchantOtpBottomSheet({
    required this.phone,
    required this.country,
    required this.onVerifySuccess,
  });

  @override
  State<_MerchantOtpBottomSheet> createState() => _MerchantOtpBottomSheetState();
}

class _MerchantOtpBottomSheetState extends State<_MerchantOtpBottomSheet> {
  final _otpController = TextEditingController();
  bool _isVerifying = false;
  String? _otpError;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      setState(() {
        _otpError = 'Please enter the 6-digit verification code.';
      });
      return;
    }

    if (code != demoOtp) {
      setState(() {
        _otpError = 'Invalid code. Please enter demo code: $demoOtp';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _otpError = null;
    });

    try {
      await widget.onVerifySuccess();
    } catch (e) {
      if (mounted) {
        setState(() {
          _otpError = e.toString().replaceAll('Exception:', '').trim();
          _isVerifying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: MarketColors.surfaceContainerLowest,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
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
            const SizedBox(height: 18),
            const Text(
              'Verify Mobile Number',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: MarketColors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Enter the 6-digit code sent to ${widget.country.dialCode} ${widget.phone.isNotEmpty ? widget.phone : "your mobile"}',
              style: const TextStyle(
                fontSize: 14,
                color: MarketColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),

            // Demo Shortcut Hint Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF8FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBAE6FD)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Color(0xFF0284C7), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Demo code: $demoOtp',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0369A1),
                      ),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(48, 36),
                    ),
                    onPressed: () {
                      _otpController.text = demoOtp;
                    },
                    child: const Text(
                      'Auto-fill',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_otpError != null) ...[
              Text(
                _otpError!,
                style: const TextStyle(
                  fontSize: 13,
                  color: MarketColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
            ],

            TextFormField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                letterSpacing: 10,
                fontWeight: FontWeight.w800,
                color: MarketColors.onSurface,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: '••••••',
                filled: true,
                fillColor: MarketColors.surfaceContainerLow,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(MarketRadii.input),
                  borderSide: const BorderSide(color: MarketColors.fieldBorder),
                ),
              ),
            ),
            const SizedBox(height: 20),

            PrimaryButton(
              width: double.infinity,
              height: 50,
              label: _isVerifying ? 'Verifying...' : 'Confirm Verification',
              isLoading: _isVerifying,
              onPressed: _isVerifying ? null : _verifyOtp,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
