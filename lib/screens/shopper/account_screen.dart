import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../models/profile.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_card.dart';
import '../../widgets/filter_chip.dart';
import '../../widgets/shopper_bottom_nav.dart';

/// AccountScreen manages shopper preferences, canonical interest chips,
/// live geofence permissions, and debug access to the spike harness.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final AuthService _authService = AuthService();

  Profile? _profile;
  bool _isLoading = true;
  bool _geoAlertsEnabled = true;
  bool _promoAlertsEnabled = true;

  PermissionStatus _locationStatus = PermissionStatus.denied;
  PermissionStatus _notificationStatus = PermissionStatus.denied;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final p = await _authService.fetchCurrentProfile();
      final loc = await Permission.locationAlways.status;
      final notif = await Permission.notification.status;

      if (mounted) {
        setState(() {
          _profile = p;
          _locationStatus = loc;
          _notificationStatus = notif;
          final prefs = p?.prefs;
          if (prefs != null) {
            _geoAlertsEnabled = prefs['geo_alerts'] as bool? ?? true;
            _promoAlertsEnabled = prefs['promo_alerts'] as bool? ?? true;
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePreference(String key, bool val) async {
    if (_profile == null) return;
    final updatedPrefs = Map<String, dynamic>.from(_profile!.prefs);
    updatedPrefs[key] = val;

    final updatedProfile = _profile!.copyWith(prefs: updatedPrefs);
    setState(() {
      _profile = updatedProfile;
      if (key == 'geo_alerts') _geoAlertsEnabled = val;
      if (key == 'promo_alerts') _promoAlertsEnabled = val;
    });

    try {
      await _authService.updateProfile(updatedProfile);
    } catch (_) {}
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
            SizedBox(width: 8),
            Text(
              'Account',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: MarketColors.outline,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(MarketSpacing.screenMargin),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Card
                    AppCardElevated(
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: MarketColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                _getInitials(_profile?.fullName ?? _authService.currentUser?.email ?? 'U'),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _profile?.fullName ?? 'Shopper',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: MarketColors.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _authService.currentUser?.email ?? '',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: MarketColors.onSurfaceVariant,
                                  ),
                                ),
                                if (_profile?.phone != null && _profile!.phone!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    _profile!.phone!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: MarketColors.secondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // My Interests Section
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'My Interests',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: MarketColors.onSurface,
                                ),
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.edit_outlined, size: 14),
                                label: const Text('Update'),
                                onPressed: () {
                                  Navigator.of(context).pushNamed('/interests');
                                },
                              ),
                            ],
                          ),
                          const Text(
                            'Tailors your Dashboard recommendations and geofenced promo alerts in Antique.',
                            style: TextStyle(fontSize: 12, color: MarketColors.onSurfaceVariant),
                          ),
                          const SizedBox(height: 12),
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
                                return AppFilterChip(
                                  label: categoryLabels[slug] ?? slug,
                                  isSelected: true,
                                  onSelected: (_) {},
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Permissions & Location Status
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.location_on_rounded, size: 20, color: MarketColors.primary),
                              SizedBox(width: 8),
                              Text(
                                'Location & Alerts Status',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: MarketColors.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _buildPermissionRow(
                            'Background Location',
                            _locationStatus.isGranted ? 'Enabled ("Always")' : 'Needs Permission',
                            _locationStatus.isGranted,
                          ),
                          const SizedBox(height: 10),
                          _buildPermissionRow(
                            'Promo Notifications',
                            _notificationStatus.isGranted ? 'Enabled' : 'Needs Permission',
                            _notificationStatus.isGranted,
                          ),
                          const SizedBox(height: 14),
                          SecondaryButton(
                            width: double.infinity,
                            height: 44,
                            label: 'Manage App Permissions',
                            icon: const Icon(Icons.settings_outlined, size: 18),
                            onPressed: () => openAppSettings(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Notification Preferences
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Notification Preferences',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: MarketColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Geofence Arrival Alerts', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            subtitle: const Text('Notify when entering San Jose de Buenavista zone', style: TextStyle(fontSize: 12)),
                            value: _geoAlertsEnabled,
                            activeThumbColor: MarketColors.primaryContainer,
                            onChanged: (val) => _updatePreference('geo_alerts', val),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Exclusive MSME Discounts', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            subtitle: const Text('Receive secret BOGO promotions matching your interests', style: TextStyle(fontSize: 12)),
                            value: _promoAlertsEnabled,
                            activeThumbColor: MarketColors.primaryContainer,
                            onChanged: (val) => _updatePreference('promo_alerts', val),
                          ),
                        ],
                      ),
                    ),


                    // Log out
                    SecondaryButton(
                      width: double.infinity,
                      height: 50,
                      label: 'Log Out',
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      onPressed: _logout,
                    ),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: ShopperBottomNav(
        currentIndex: 3,
        onTap: (idx) {
          if (idx == 0) Navigator.of(context).pushReplacementNamed('/shopper-home');
          if (idx == 1) Navigator.of(context).pushReplacementNamed('/roam');
          if (idx == 2) Navigator.of(context).pushReplacementNamed('/stash');
        },
      ),
    );
  }

  Widget _buildPermissionRow(String title, String statusText, bool isGranted) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 13, color: MarketColors.onSurfaceVariant)),
        Row(
          children: [
            Icon(
              isGranted ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
              size: 16,
              color: isGranted ? MarketColors.success : MarketColors.warning,
            ),
            const SizedBox(width: 4),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isGranted ? MarketColors.success : MarketColors.warning,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getInitials(String text) {
    final parts = text.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return text.isNotEmpty ? text.substring(0, 1).toUpperCase() : 'U';
  }
}
