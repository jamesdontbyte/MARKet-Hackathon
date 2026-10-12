import 'package:flutter/material.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../models/profile.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_card.dart';
import '../../widgets/filter_chip.dart';

/// ShopperHomeScreen destination after onboarding/login.
/// Displays user info, chosen interest tags, access to geofence spike, and logout.
class ShopperHomeScreen extends StatefulWidget {
  const ShopperHomeScreen({super.key});

  @override
  State<ShopperHomeScreen> createState() => _ShopperHomeScreenState();
}

class _ShopperHomeScreenState extends State<ShopperHomeScreen> {
  final AuthService _authService = AuthService();
  Profile? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final p = await _authService.fetchCurrentProfile();
      if (mounted) {
        setState(() {
          _profile = p;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/role-selection', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarketColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: const [
            Text(
              'MARK',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: MarketColors.primaryContainer,
              ),
            ),
            Text(
              'et',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: MarketColors.onSurface,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: MarketColors.onSurfaceVariant),
            tooltip: 'Log Out',
            onPressed: _logout,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(MarketSpacing.screenMargin),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Banner
                    AppCardElevated(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: MarketColors.primaryContainer.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.check_circle_rounded,
                                  color: MarketColors.primary,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Shopper Onboarding Complete',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: MarketColors.onSurface,
                                      ),
                                    ),
                                    Text(
                                      _profile?.fullName ?? _authService.currentUser?.email ?? 'Logged in',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: MarketColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Your profile is registered with hyperlocal discovery preferences for San Jose de Buenavista, Antique.',
                            style: TextStyle(
                              fontSize: 13,
                              color: MarketColors.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Interests Section
                    const Text(
                      'Your Selected Interests',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: MarketColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_profile == null || _profile!.interests.isEmpty)
                      const Text(
                        'No interests selected yet.',
                        style: TextStyle(fontSize: 13, color: MarketColors.outline),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _profile!.interests.map((slug) {
                          final label = categoryLabels[slug] ?? slug;
                          return AppFilterChip(
                            label: label,
                            isSelected: true,
                            onSelected: (_) {},
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit Interests'),
                      onPressed: () {
                        Navigator.of(context).pushNamed('/interests');
                      },
                    ),
                    const SizedBox(height: 24),



                    // Log out
                    SecondaryButton(
                      width: double.infinity,
                      label: 'Log Out',
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      onPressed: _logout,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
