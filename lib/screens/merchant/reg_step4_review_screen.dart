import 'package:flutter/material.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_header.dart';
import '../../widgets/country_selector.dart';
import 'merchant_reg_controller.dart';
import 'waiting_screen.dart';
import 'widgets/merchant_reg_stepper.dart';

/// MSME Registration Step 4: Review & Submit Unverified Business
class RegStep4ReviewScreen extends StatefulWidget {
  final MerchantRegController controller;

  const RegStep4ReviewScreen({
    super.key,
    required this.controller,
  });

  @override
  State<RegStep4ReviewScreen> createState() => _RegStep4ReviewScreenState();
}

class _RegStep4ReviewScreenState extends State<RegStep4ReviewScreen> {
  late final MerchantRegController _regController;
  final AuthService _authService = AuthService();
  final DataService _dataService = DataService();

  @override
  void initState() {
    super.initState();
    _regController = widget.controller;
  }

  Future<void> _submit() async {
    final success = await _regController.submitRegistration(
      authService: _authService,
      dataService: _dataService,
    );

    if (success && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => WaitingScreen(
            business: _regController.createdBusiness,
          ),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final catLabel = categoryLabels[_regController.category] ?? _regController.category;

    return Scaffold(
      backgroundColor: MarketColors.surface,
      appBar: const AppHeader(
        showBack: true,
        subtitle: 'Review',
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 4-Step Stepper
                    const MerchantRegStepper(currentStep: 4),
                    const SizedBox(height: 20),

                    // Title
                    const Text(
                      'Review Registration',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: MarketColors.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Step 4 of 4: Please confirm your merchant profile and business details before submission.',
                      style: TextStyle(
                        fontSize: 13,
                        color: MarketColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Submission Error Banner
                    ListenableBuilder(
                      listenable: _regController,
                      builder: (context, _) {
                        if (_regController.submitError == null) {
                          return const SizedBox.shrink();
                        }
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
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
                                  _regController.submitError!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: MarketColors.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // Store Photos & Branding Preview Card
                    Container(
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
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_regController.coverBytes != null)
                            AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.memory(_regController.coverBytes!, fit: BoxFit.cover),
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
                                    bottom: 12,
                                    left: 14,
                                    right: 14,
                                    child: Row(
                                      children: [
                                        if (_regController.logoBytes != null)
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: Colors.white, width: 2),
                                            ),
                                            clipBehavior: Clip.antiAlias,
                                            child: Image.memory(
                                              _regController.logoBytes!,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            _regController.businessName.isNotEmpty
                                                ? _regController.businessName
                                                : 'Your Business',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  const Icon(Icons.storefront_rounded,
                                      size: 32, color: MarketColors.primary),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _regController.businessName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: MarketColors.onSurface,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 1. Owner Profile Card
                    _buildSummaryCard(
                      title: 'Owner Information',
                      icon: Icons.person_rounded,
                      rows: [
                        _buildRow('Full Name', _regController.fullName),
                        _buildRow('Date of Birth', _regController.dob.isNotEmpty ? _regController.dob : '—'),
                        _buildRow(
                          'Mobile Number',
                          '${formatPhoneDisplay(_regController.phone)} (Verified)',
                        ),
                        _buildRow('Email Address', _regController.email),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 2. Business Details Card
                    _buildSummaryCard(
                      title: 'Business Information',
                      icon: Icons.storefront_rounded,
                      rows: [
                        _buildRow('Business Name', _regController.businessName),
                        _buildRow('Category', catLabel),
                        _buildRow('Municipality', _regController.municipality),
                        _buildRow('Street Address', _regController.address),
                        _buildRow('Hotline', formatPhoneDisplay(_regController.contactPhone)),
                        _buildRow('Operating Hours', _regController.hours.isNotEmpty ? _regController.hours : '—'),
                        _buildRow('Coordinates',
                            _regController.lat != null && _regController.lng != null
                                ? '${_regController.lat!.toStringAsFixed(5)}, ${_regController.lng!.toStringAsFixed(5)}'
                                : '—'),
                        _buildRow('Bio', _regController.bio.isNotEmpty ? _regController.bio : '—'),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 3. Verification Documents Checklist Card
                    _buildSummaryCard(
                      title: 'Submitted Permits & Documents',
                      icon: Icons.verified_user_rounded,
                      rows: [
                        _buildDocRow('DTI / SEC Certificate', _regController.dtiFileName),
                        _buildDocRow('BIR Form 2303', _regController.birFileName),
                        _buildDocRow("Mayor's / Business Permit", _regController.mayorFileName),
                        _buildDocRow('Valid Gov ID / Clearance', _regController.validIdFileName),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Sticky Bottom Submit Button
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
              child: ListenableBuilder(
                listenable: _regController,
                builder: (context, _) {
                  return PrimaryButton(
                    width: double.infinity,
                    height: 52,
                    label: _regController.isSubmitting
                        ? 'Submitting Application...'
                        : 'Submit Application',
                    isLoading: _regController.isSubmitting,
                    icon: const Icon(Icons.send_rounded, size: 20),
                    onPressed: _regController.isSubmitting ? null : _submit,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required IconData icon,
    required List<Widget> rows,
  }) {
    return Container(
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
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: MarketColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: MarketColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: MarketColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          ...rows,
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: MarketColors.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(
                fontSize: 13,
                color: MarketColors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocRow(String label, String? fileName) {
    final isUploaded = fileName != null && fileName.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: MarketColors.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isUploaded
                  ? const Color(0xFFDCFCE7)
                  : MarketColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              isUploaded ? 'Attached ✓' : 'Not attached',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isUploaded
                    ? const Color(0xFF166534)
                    : MarketColors.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
