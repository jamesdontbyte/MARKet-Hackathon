import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../services/geofence_service.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_text_field.dart';

/// LoginScreen with standard email/password authentication.
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
        final locInUse = await Permission.locationWhenInUse.isGranted;
        final locAlways = await Permission.locationAlways.isGranted;
        final notif = await Permission.notification.isGranted;
        if (!mounted) return;
        if (!locInUse || !locAlways || !notif) {
          Navigator.of(context).pushReplacementNamed('/permission-explainer');
        } else {
          await GeofenceService.instance.start();
          if (!mounted) return;
          Navigator.of(context).pushReplacementNamed('/shopper-home');
        }
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
              Image.asset(
                'assets/logos/logo_icon.png',
                width: 44,
                height: 44,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 16),
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
                        onPressed: _isLoading ? null : _loginStandard,
                      ),
                    ],
                  ),
                ),
              ),

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
