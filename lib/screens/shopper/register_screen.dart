import 'package:flutter/material.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/country_selector.dart';

/// Shopper registration screen matching the Stitch market_consumer_registration frame.
/// Tapping "Create Account & Continue" opens a bottom sheet for OTP verification
/// with demo shortcut ("Demo code: 123456").
class ShopperRegisterScreen extends StatefulWidget {
  const ShopperRegisterScreen({super.key});

  @override
  State<ShopperRegisterScreen> createState() => _ShopperRegisterScreenState();
}

class _ShopperRegisterScreenState extends State<ShopperRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  CountryInfo _selectedCountry = kCountries.first;

  final AuthService _authService = AuthService();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToTerms = true;
  String _selectedIdType = 'philsys';
  String? _frontIdName;
  String? _backIdName;
  String? _formError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onSubmit() {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreedToTerms) {
      setState(() {
        _formError = 'Please agree to the Terms of Service and Privacy Notice.';
      });
      return;
    }

    setState(() {
      _formError = null;
    });

    _showOtpBottomSheet();
  }

  void _showOtpBottomSheet() {
    final rawPhone = _phoneController.text.trim();
    final fullPhone = buildInternationalPhone(rawPhone, _selectedCountry);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return _ShopperOtpBottomSheet(
          phone: cleanPhoneNumber(rawPhone),
          country: _selectedCountry,
          onVerifySuccess: () async {
            // Register shopper via Supabase Auth & profiles table
            await _authService.signUpShopper(
              email: _emailController.text.trim(),
              password: _passwordController.text,
              fullName: _nameController.text.trim(),
              phone: fullPhone,
            );

            if (modalContext.mounted) {
              Navigator.of(modalContext).pop(); // dismiss modal
            }
            if (mounted) {
              Navigator.of(context).pushReplacementNamed('/interests');
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
        subtitle: 'Register',
      ),
      body: SafeArea(
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
                // Exact Logo Icon
                Image.asset(
                  'assets/logos/logo_icon.png',
                  width: 44,
                  height: 44,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),

                // Header
                const Text(
                  'Create Your Account',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: MarketColors.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Join MARKet and discover local businesses near you.',
                  style: TextStyle(
                    fontSize: 14,
                    color: MarketColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),

                if (_formError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: MarketColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(MarketRadii.button),
                      border: Border.all(
                        color: MarketColors.error.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: MarketColors.error, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _formError!,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: MarketColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // SECTION 1: Personal Information
                _buildSectionCard(
                  icon: Icons.person_outline_rounded,
                  title: 'Personal Information',
                  subtitle: 'Step 1 of 2 • Basic profile',
                  badgeText: 'Required',
                  badgeBgColor: MarketColors.primaryContainer.withValues(alpha: 0.2),
                  badgeTextColor: MarketColors.primary,
                  child: Column(
                    children: [
                      AppTextField(
                        controller: _nameController,
                        label: 'Full Name',
                        hintText: 'e.g., Maria Aquino',
                        helperText: 'As it appears on your official Philippine identification',
                        validator: (value) {
                          if (value == null || value.trim().length < 2) {
                            return 'Please enter your full name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: _emailController,
                        label: 'Email Address',
                        hintText: 'e.g., maria.aquino@gmail.com',
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || !value.contains('@') || !value.contains('.')) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Mobile Number with +63 prefix
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Mobile Number',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: MarketColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 6),                          Row(
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
                                child: AppTextField(
                                  controller: _phoneController,
                                  hintText: _selectedCountry.isoCode == 'PH' ? '917 888 4321' : 'Mobile number',
                                  keyboardType: TextInputType.phone,
                                  validator: (value) => validatePhoneNumber(value, _selectedCountry),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Used for SMS instant order notifications and merchant updates',
                            style: TextStyle(
                              fontSize: 11,
                              color: MarketColors.outline,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Password
                      AppTextField(
                        controller: _passwordController,
                        label: 'Password',
                        hintText: 'Create secure password',
                        obscureText: _obscurePassword,
                        helperText: 'Minimum 8 characters with letters & numbers',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: MarketColors.outline,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        validator: (value) {
                          if (value == null || value.length < 8) {
                            return 'Password must be at least 8 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Confirm Password
                      AppTextField(
                        controller: _confirmPasswordController,
                        label: 'Confirm Password',
                        hintText: 'Repeat password',
                        obscureText: _obscureConfirmPassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: MarketColors.outline,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword = !_obscureConfirmPassword;
                            });
                          },
                        ),
                        validator: (value) {
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // SECTION 2: Government ID Verification (Optional / Non-blocking)
                _buildSectionCard(
                  icon: Icons.badge_outlined,
                  title: 'Government ID Verification',
                  subtitle: 'Resident verification',
                  badgeText: 'Recommended',
                  badgeBgColor: MarketColors.surfaceContainerHigh,
                  badgeTextColor: MarketColors.onSurfaceVariant,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: MarketColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: MarketColors.primaryContainer.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Icon(
                              Icons.verified_user_outlined,
                              size: 18,
                              color: MarketColors.primary,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Verify your identity to unlock exclusive verified resident promotions, seamless merchant QR claims, and trusted community status in Antique.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: MarketColors.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ID Type Dropdown
                      const Text(
                        'Select ID Type',
                        style: TextStyle(
                          fontSize: 14,
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
                            value: _selectedIdType,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(
                                value: 'philsys',
                                child: Text('PhilSys National ID (ePhilID / Card)'),
                              ),
                              DropdownMenuItem(
                                value: 'umid',
                                child: Text('Unified Multi-Purpose ID (UMID)'),
                              ),
                              DropdownMenuItem(
                                value: 'drivers_license',
                                child: Text("LTO Driver's License"),
                              ),
                              DropdownMenuItem(
                                value: 'passport',
                                child: Text('DFA Philippine Passport'),
                              ),
                              DropdownMenuItem(
                                value: 'postal',
                                child: Text('PhlPost Postal ID'),
                              ),
                              DropdownMenuItem(
                                value: 'prc',
                                child: Text('Professional Regulation Commission (PRC) ID'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedIdType = val;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Dual Upload Slots (Simulated / Optional)
                      Row(
                        children: [
                          Expanded(
                            child: _buildUploadSlot(
                              title: 'Upload Front Side',
                              fileName: _frontIdName,
                              onTap: () {
                                setState(() {
                                  _frontIdName = 'id_front_${DateTime.now().millisecondsSinceEpoch}.jpg';
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildUploadSlot(
                              title: 'Upload Back Side',
                              fileName: _backIdName,
                              onTap: () {
                                setState(() {
                                  _backIdName = 'id_back_${DateTime.now().millisecondsSinceEpoch}.jpg';
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // SECTION 3: Privacy & Terms
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MarketColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: MarketColors.cardBorder),
                    boxShadow: MarketElevation.level1,
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBAE6FD)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Icon(Icons.security_rounded, size: 18, color: MarketColors.primary),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Philippine Data Privacy Act (RA 10173): Your personal information is encrypted and processed strictly for identity validation and local MSME verification in Antique.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: MarketColors.onSurfaceVariant,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _agreedToTerms,
                            activeColor: MarketColors.primaryContainer,
                            checkColor: MarketColors.onSurface,
                            onChanged: (val) {
                              setState(() {
                                _agreedToTerms = val ?? false;
                              });
                            },
                          ),
                          const Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(top: 10),
                              child: Text(
                                'I agree to the Terms of Service and acknowledge the Privacy Notice.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: MarketColors.onSurfaceVariant,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Action Button
                PrimaryButton(
                  width: double.infinity,
                  height: 52,
                  label: 'Create Account & Continue',
                  icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                  onPressed: _onSubmit,
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Next: Choose your local interests & preferences',
                    style: TextStyle(
                      fontSize: 12,
                      color: MarketColors.outline,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Already have an account?',
                        style: TextStyle(
                          fontSize: 14,
                          color: MarketColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: () {
                          Navigator.of(context).pushReplacementNamed('/login');
                        },
                        child: const Text(
                          'Log in',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: MarketColors.link,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeBgColor,
    required Color badgeTextColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MarketColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MarketColors.cardBorder),
        boxShadow: MarketElevation.level1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: MarketColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: MarketColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: MarketColors.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: MarketColors.outline,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBgColor,
                  borderRadius: BorderRadius.circular(MarketRadii.pill),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildUploadSlot({
    required String title,
    required String? fileName,
    required VoidCallback onTap,
  }) {
    final hasFile = fileName != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: hasFile
              ? const Color(0xFFF0FDF4)
              : MarketColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasFile
                ? MarketColors.success
                : const Color(0xFFCBD5E1),
            style: BorderStyle.solid,
            width: hasFile ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasFile ? Icons.check_circle_rounded : Icons.cloud_upload_outlined,
              size: 24,
              color: hasFile ? MarketColors.success : MarketColors.primary,
            ),
            const SizedBox(height: 6),
            Text(
              hasFile ? 'Uploaded' : title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: hasFile ? MarketColors.success : MarketColors.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              hasFile ? fileName : 'Tap to select',
              style: const TextStyle(
                fontSize: 10,
                color: MarketColors.outline,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// OTP Modal Bottom Sheet with Demo Shortcut
class _ShopperOtpBottomSheet extends StatefulWidget {
  final String phone;
  final CountryInfo country;
  final Future<void> Function() onVerifySuccess;

  const _ShopperOtpBottomSheet({
    required this.phone,
    required this.country,
    required this.onVerifySuccess,
  });

  @override
  State<_ShopperOtpBottomSheet> createState() => _ShopperOtpBottomSheetState();
}

class _ShopperOtpBottomSheetState extends State<_ShopperOtpBottomSheet> {
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

            if (_otpError != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: MarketColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: MarketColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _otpError!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: MarketColors.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            AppTextField(
              controller: _otpController,
              hintText: '123456',
              keyboardType: TextInputType.number,
              helperText: 'Demo code: $demoOtp',
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _verifyOtp(),
            ),
            const SizedBox(height: 20),

            PrimaryButton(
              width: double.infinity,
              height: 50,
              label: 'Verify & Complete Registration',
              isLoading: _isVerifying,
              onPressed: _isVerifying ? null : _verifyOtp,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
