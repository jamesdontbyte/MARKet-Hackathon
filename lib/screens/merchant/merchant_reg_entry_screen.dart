import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import 'merchant_reg_controller.dart';
import 'reg_step1_screen.dart';
import 'reg_step2_screen.dart';
import 'waiting_screen.dart';
import 'dashboard_screen.dart';

/// Entry router for merchant registration.
/// If user is already authenticated with a merchant profile but has no business row,
/// resumes directly at Step 2 with fields re-populated from their profile.
class MerchantRegEntryScreen extends StatefulWidget {
  const MerchantRegEntryScreen({super.key});

  @override
  State<MerchantRegEntryScreen> createState() => _MerchantRegEntryScreenState();
}

class _MerchantRegEntryScreenState extends State<MerchantRegEntryScreen> {
  final AuthService _authService = AuthService();
  final DataService _dataService = DataService();

  bool _isChecking = true;
  Widget? _targetScreen;

  @override
  void initState() {
    super.initState();
    _evaluateStartingStep();
  }

  Future<void> _evaluateStartingStep() async {
    try {
      if (_authService.isAuthenticated) {
        final profile = await _authService.fetchCurrentProfile();
        if (profile != null && profile.role == 'merchant') {
          final business = await _dataService.fetchMerchantBusiness(profile.id);

          if (business != null) {
            if (business.verified) {
              _targetScreen = MerchantDashboardScreen(business: business);
            } else {
              _targetScreen = WaitingScreen(business: business);
            }
          } else {
            // Merchant has profile but no business row -> Resume at Step 2!
            final controller = MerchantRegController();
            controller.populateFromProfile(profile, _authService.currentUser);
            _targetScreen = RegStep2Screen(controller: controller);
          }
        } else {
          _targetScreen = const RegStep1Screen();
        }
      } else {
        _targetScreen = const RegStep1Screen();
      }
    } catch (_) {
      _targetScreen = const RegStep1Screen();
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return _targetScreen ?? const RegStep1Screen();
  }
}
