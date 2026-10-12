import 'package:flutter/material.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_text_field.dart';

/// LoginScreen with standard email/password authentication and
/// one-tap "Demo Shopper" / "Demo Merchant" shortcuts when demoMode == true.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final AuthService _authService = AuthService();
  final DataService _dataService = DataService();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isDemoShopperLoading = false;
  bool _isDemoMerchantLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handlePostLoginRouting() async {
    final profile = await _authService.fetchCurrentProfile();
    if (!mounted) return;

    if (profile == null) {
      Navigator.of(context).pushReplacementNamed('/role-selection');
      return;
    }

    if (profile.role == 'shopper') {
      if (profile.interests.isEmpty) {
        Navigator.of(context).pushReplacementNamed('/interests');
      } else {
        Navigator.of(context).pushReplacementNamed('/shopper-home');
      }
    } else if (profile.role == 'merchant') {
      final business = await _dataService.fetchMerchantBusiness(profile.id);
      if (!mounted) return;

      if (business == null) {
        Navigator.of(context).pushReplacementNamed('/merchant-reg');
      } else if (business.verified) {
        Navigator.of(context).pushReplacementNamed('/merchant-home');
      } else {
        Navigator.of(context).pushReplacementNamed('/merchant-waiting');
      }
    } else {
      Navigator.of(context).pushReplacementNamed('/role-selection');
    }
  }

  Future<void> _loginStandard() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signInWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );
      await _handlePostLoginRouting();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loginDemoShopper() async {
    setState(() {
      _isDemoShopperLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signInDemoShopper();
      await _handlePostLoginRouting();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Demo Shopper sign-in failed: ${e.toString().replaceAll('Exception:', '').trim()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDemoShopperLoading = false;
        });
      }
    }
  }

  Future<void> _loginDemoMerchant() async {
    setState(() {
      _isDemoMerchantLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signInDemoMerchant();
      await _handlePostLoginRouting();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Demo Merchant sign-in failed: ${e.toString().replaceAll('Exception:', '').trim()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDemoMerchantLoading = false;
        });
      }
    }
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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: MarketSpacing.screenMargin,
            vertical: 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo & Title
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: const [
                  Text(
                    'Log in to ',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: MarketColors.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'MARK',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: MarketColors.primaryContainer,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'et',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: MarketColors.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Enter your credentials to access your local promos, storefront, or vouchers.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: MarketColors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // Error Banner (if any)
              if (_errorMessage != null) ...[
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
                          _errorMessage!,
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
                const SizedBox(height: 18),
              ],

              // Standard Form
              Form(
                key: _formKey,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: MarketColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: MarketColors.cardBorder),
                    boxShadow: MarketElevation.level1,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppTextField(
                        controller: _emailController,
                        label: 'Email Address',
                        hintText: 'name@example.com',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: const Icon(Icons.email_outlined, color: MarketColors.outline, size: 20),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@') || !value.contains('.')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _passwordController,
                        label: 'Password',
                        hintText: 'Enter your password',
                        obscureText: _obscurePassword,
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: MarketColors.outline, size: 20),
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
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 22),
                      PrimaryButton(
                        width: double.infinity,
                        label: 'Log In',
                        isLoading: _isLoading,
                        onPressed: (_isDemoShopperLoading || _isDemoMerchantLoading) ? null : _loginStandard,
                      ),
                    ],
                  ),
                ),
              ),

              // Demo Shortcuts Section (shown only when demoMode == true)
              if (demoMode) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: MarketColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: MarketColors.primaryContainer.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: MarketColors.primaryContainer.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.bolt_rounded,
                              size: 18,
                              color: MarketColors.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'One-Tap Demo Logins',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: MarketColors.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Instant login for live evaluation (no typing required)',
                        style: TextStyle(
                          fontSize: 12,
                          color: MarketColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Demo Shopper Button
                      SecondaryButton(
                        width: double.infinity,
                        label: 'Demo Shopper',
                        icon: const Icon(Icons.shopping_bag_outlined, size: 18, color: MarketColors.primary),
                        isLoading: _isDemoShopperLoading,
                        onPressed: (_isLoading || _isDemoMerchantLoading) ? null : _loginDemoShopper,
                      ),
                      const SizedBox(height: 10),

                      // Demo Merchant Button
                      SecondaryButton(
                        width: double.infinity,
                        label: 'Demo Merchant (Kape Tahanan)',
                        icon: const Icon(Icons.storefront_rounded, size: 18, color: MarketColors.primary),
                        isLoading: _isDemoMerchantLoading,
                        onPressed: (_isLoading || _isDemoShopperLoading) ? null : _loginDemoMerchant,
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // Sign up prompt
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Don't have an account?",
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
                        Navigator.of(context).pushReplacementNamed('/role-selection');
                      },
                      child: const Text(
                        'Register',
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
    );
  }
}
