import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/service_provider/sp_register_controller.dart';
//import '../../services/profile_service.dart';
import '../../services/firebase_storage_service.dart';
import '../../controllers/Transport/user_profile_controller.dart';
import '../../core/auth/auth_service.dart';
import '../../models/user_profile_model.dart';
import '../../utils/app_logger.dart';
import '../../widgets/common_delete_button.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/change_password_sheet.dart';
import '../../widgets/legal_widgets.dart';
import '../auth/onboarding_screen.dart';
import 'complete_profile_screen.dart';
import '../shared/subscription_screen.dart';
import '../shared/wallet_screen.dart';
import '../shared/issues/issues_screen.dart';
import '../shared/legal_screen.dart';
import '../../widgets/language_selection_bottom_sheet.dart';
import '../../core/localization/localization_service.dart';

import '../Professional/KYC/kyc_screen.dart';

// ── Design tokens ────────────────────────────────────────────────────────────
const _primary = Color(0xFFF36969);
const _primaryLight = Color(0xFFFFF1F1);
const _bg = Color(0xFFF9FAFB);
const _cardBg = Colors.white;
const _textDark = Color(0xFF111827);
const _textGrey = Color(0xFF6B7280);
const _border = Color(0xFFE5E7EB);

class ServiceProviderProfileScreen extends StatelessWidget {
  const ServiceProviderProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(UserProfileController());

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ctrl.fetchCurrentUserProfile();
      ctrl.syncKycStatus(); // live-sync from /kyc/my-kyc (matches web panel)
    });

    return Scaffold(
      backgroundColor: _bg,
      body: Obx(() {
        if (ctrl.isLoading.value && ctrl.userProfile.value == null) {
          return const Center(
            child: CircularProgressIndicator(color: _primary),
          );
        }
        if (ctrl.errorMessage.value.isNotEmpty &&
            ctrl.userProfile.value == null) {
          return _ErrorRetry(
            message: ctrl.errorMessage.value,
            onRetry: ctrl.fetchCurrentUserProfile,
          );
        }
        final profile = ctrl.userProfile.value;
        return CustomScrollView(
          slivers: [
            _buildSliverHeader(context, profile),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _buildStatsRow(profile),
                  const SizedBox(height: 16),
                  _buildKycBanner(profile),
                  _buildServicesSection(profile),
                  const SizedBox(height: 12),
                  _buildBusinessInfo(profile),
                  const SizedBox(height: 12),
                  _buildContactInfo(profile),
                  const SizedBox(height: 12),
                  _buildPlatformPreferences(ctrl),
                  const SizedBox(height: 12),
                  _buildWalletCard(),
                  const SizedBox(height: 12),
                  _buildSubscriptionCard(),
                  const SizedBox(height: 12),
                  _buildQuickActions(context, profile),
                  const SizedBox(height: 12),
                  _buildDangerZone(ctrl),
                  const SizedBox(height: 12),
                  _buildSupportCard(),
                  const SizedBox(height: 12),
                  const LegalSettingsSection(),
                  const SizedBox(height: 12),
                  _buildFooter(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  // ── Sliver header ─────────────────────────────────────────────────────────

  Widget _buildSliverHeader(BuildContext context, UserProfileModel? profile) {
    final name = profile?.businessName ?? 'My Business';
    final initials = _initials(name);
    final imgUrl = profile?.businessLogoPath;
    final isVerified = profile?.isKYCCompleted ?? false;

    return SliverAppBar(
      expandedHeight: 230,
      pinned: true,
      backgroundColor: _primary,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.white,
          size: 20,
        ),
        onPressed: () => Get.back(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Iconsax.edit, color: Colors.white, size: 20),
          onPressed: () => _navigateToEdit(context, profile),
          tooltip: 'Edit profile',
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFE84545), Color(0xFFF36969)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // Avatar
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    GestureDetector(
                      onTap: () => _navigateToEdit(context, profile),
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        child: ClipOval(
                          child: (imgUrl != null && imgUrl.isNotEmpty)
                              ? Image.network(
                                  imgUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _initialsAvatar(initials, 88),
                                )
                              : _initialsAvatar(initials, 88),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _pickAndUploadPhoto(context),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: _primary, width: 1.5),
                        ),
                        child: const Icon(
                          Iconsax.camera,
                          size: 13,
                          color: _primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    if (isVerified) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.verified_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                if (profile?.businessCategory != null &&
                    profile!.businessCategory!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Iconsax.shop, size: 13, color: Colors.white),
                        const SizedBox(width: 5),
                        Text(
                          profile.businessCategory!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Iconsax.star1, size: 14, color: Colors.amber),
                    SizedBox(width: 4),
                    Text(
                      '4.5 / 5',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Stats row ─────────────────────────────────────────────────────────────

  Widget _buildStatsRow(UserProfileModel? profile) {
    // For service provider we show relevant business stats
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            _statItem(
              'Services',
              'Active',
              Iconsax.setting_2,
              const Color(0xFF8B5CF6),
            ),
            _vDivider(),
            _statItem(
              'Bookings',
              'Total',
              Iconsax.receipt_1,
              const Color(0xFF3B82F6),
            ),
            _vDivider(),
            _statItem(
              'Clients',
              'Happy',
              Iconsax.people,
              const Color(0xFF22C55E),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _textDark,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: _textGrey,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(width: 1, height: 48, color: _border);

  // ── KYC Banner ────────────────────────────────────────────────────────────

  Widget _buildKycBanner(UserProfileModel? profile) {
    final isVerified =
        AuthService.to.isUserKYCCompleted || (profile?.isKYCCompleted ?? false);
    if (isVerified) return _kycVerifiedBanner();

    return GestureDetector(
      onTap: () => Get.to(() => const KycScreen()),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Iconsax.warning_2,
                  size: 22,
                  color: Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Business Verification Pending',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF92400E),
                        fontFamily: 'Poppins',
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Complete verification to publish services and receive bookings.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF92400E),
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFF59E0B)),
            ],
          ),
        ),
      ),
    );
  }

  /// Green "KYC Verified" banner shown once the business is verified — mirrors
  /// the Professional persona's verified banner and the web verified badge.
  Widget _kycVerifiedBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF22C55E), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Iconsax.shield_tick, size: 22, color: Color(0xFF22C55E)),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('KYC Verified',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF14532D),
                          fontFamily: 'Poppins')),
                  SizedBox(height: 2),
                  Text('Your business is verified — services are live.',
                      style: TextStyle(
                          fontSize: 11, color: Color(0xFF166534), fontFamily: 'Poppins')),
                ],
              ),
            ),
            const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 22),
          ],
        ),
      ),
    );
  }

  // ── Services offered ──────────────────────────────────────────────────────

  Widget _buildServicesSection(UserProfileModel? profile) {
    final raw = profile?.servicesOffered ?? '';
    if (raw.isEmpty) return const SizedBox.shrink();

    final services = raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (services.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
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
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Iconsax.setting_2,
                    size: 18,
                    color: Color(0xFF8B5CF6),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Services Offered',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: services.map((s) => _serviceChip(s)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _serviceChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _primaryLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _primary.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _primary,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }

  // ── Section card helper ───────────────────────────────────────────────────

  Widget _card({
    required String title,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                    fontFamily: 'Poppins',
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, Color iconColor, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _textGrey,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _textDark,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Business information ──────────────────────────────────────────────────

  Widget _buildBusinessInfo(UserProfileModel? profile) {
    return _card(
      title: 'Business Information',
      trailing: GestureDetector(
        onTap: () => _navigateToEditFromCtrl(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _primaryLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Iconsax.edit, size: 12, color: _primary),
              SizedBox(width: 4),
              Text(
                'Edit',
                style: TextStyle(
                  fontSize: 12,
                  color: _primary,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
        ),
      ),
      children: [
        _infoRow(
          Iconsax.shop,
          const Color(0xFF8B5CF6),
          'Business Name',
          profile?.businessName ?? '—',
        ),
        _infoRow(
          Iconsax.category,
          const Color(0xFF3B82F6),
          'Business Category',
          profile?.businessCategory ?? '—',
        ),
        _infoRow(
          Iconsax.receipt_text,
          const Color(0xFFF59E0B),
          'GST Number',
          profile?.gstNumber ?? '—',
        ),
        _infoRow(
          Iconsax.location,
          const Color(0xFF0EA5E9),
          'City',
          profile?.city ?? '—',
        ),
        if (profile?.businessType != null && profile!.businessType!.isNotEmpty)
          _infoRow(
            Iconsax.buildings,
            const Color(0xFF22C55E),
            'Business Type',
            profile.businessType!,
          ),
      ],
    );
  }

  // ── Contact information ───────────────────────────────────────────────────

  Widget _buildContactInfo(UserProfileModel? profile) {
    return _card(
      title: 'Contact Information',
      children: [
        _infoRow(
          Iconsax.call,
          const Color(0xFF22C55E),
          'Mobile Number',
          profile?.mobileNo != null && profile!.mobileNo!.isNotEmpty
              ? '+91 ${profile.mobileNo}'
              : '—',
        ),
        _infoRow(
          Iconsax.sms,
          const Color(0xFF3B82F6),
          'Email Address',
          profile?.email ?? '—',
        ),
        _infoRow(
          Icons.chat_rounded,
          const Color(0xFF22C55E),
          'WhatsApp',
          profile?.mobileNo != null && profile!.mobileNo!.isNotEmpty
              ? '+91 ${profile.mobileNo}'
              : '—',
        ),
      ],
    );
  }

  // ── Platform preferences ──────────────────────────────────────────────────

  Widget _buildPlatformPreferences(UserProfileController ctrl) {
    return _card(
      title: 'Platform Preferences',
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Iconsax.language_circle,
                size: 18,
                color: Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Language'.tr,
                style: const TextStyle(
                  fontSize: 14,
                  color: _textDark,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            InkWell(
              onTap: () => LanguageSelectionBottomSheet.show(),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      LocalizationService.to.currentLanguageName,
                      style: const TextStyle(
                        fontSize: 13,
                        color: _textDark,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: _textGrey,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(color: _border, height: 1),
        const SizedBox(height: 16),
        Obx(
          () => _toggleRow(
            Iconsax.sms,
            'SMS Notifications',
            ctrl.smsNotifications.value,
            ctrl.toggleSmsNotifications,
          ),
        ),
        const SizedBox(height: 14),
        Obx(
          () => _toggleRow(
            Iconsax.sms_notification,
            'Email Notifications',
            ctrl.emailNotifications.value,
            ctrl.toggleEmailNotifications,
          ),
        ),
        const SizedBox(height: 14),
        Obx(
          () => _toggleRow(
            Icons.chat_rounded,
            'WhatsApp Notifications',
            ctrl.whatsappNotifications.value,
            ctrl.toggleWhatsappNotifications,
          ),
        ),
      ],
    );
  }

  Widget _toggleRow(
    IconData icon,
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: _textGrey),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: _textDark,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: _primary,
          activeThumbColor: Colors.white,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }

  // ── Wallet / Earnings ──────────────────────────────────────────────────────

  Widget _buildWalletCard() {
    return GestureDetector(
      onTap: () => Get.to(() => const WalletScreen()),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF16A34A), Color(0xFF15803D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(13),
                ),
                child:
                    const Icon(Iconsax.wallet_3, size: 24, color: Colors.white),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Earnings',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'View wallet balance & claim earnings',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.white70,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Subscription ──────────────────────────────────────────────────────────

  Widget _buildSubscriptionCard() {
    return GestureDetector(
      onTap: () =>
          Get.to(() => const SubscriptionScreen(category: 'service_provider')),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Iconsax.crown, size: 24, color: Colors.white),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subscription Plans',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'View plans & manage your subscription',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.white70,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Quick actions ─────────────────────────────────────────────────────────

  Widget _buildQuickActions(BuildContext context, UserProfileModel? profile) {
    return _card(
      title: 'Quick Actions',
      children: [
        Row(
          children: [
            _actionTile(
              Iconsax.edit,
              'Edit Profile',
              const Color(0xFF3B82F6),
              const Color(0xFFEFF6FF),
              () => _navigateToEdit(context, profile),
            ),
            const SizedBox(width: 10),
            _actionTile(
              Iconsax.call,
              'Contact Us',
              const Color(0xFF22C55E),
              const Color(0xFFF0FDF4),
              _contactUs,
            ),
            const SizedBox(width: 10),
            _actionTile(
              Iconsax.lock,
              'Password',
              const Color(0xFFF59E0B),
              const Color(0xFFFFFBEB),
              () => ChangePasswordSheet.show(context),
            ),
            const SizedBox(width: 10),
            _actionTile(
              Iconsax.logout,
              'Logout',
              _primary,
              _primaryLight,
              () => _showLogoutDialog(context),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionTile(
    IconData icon,
    String label,
    Color iconColor,
    Color bg,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: iconColor.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: iconColor,
                  fontFamily: 'Poppins',
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Danger zone ───────────────────────────────────────────────────────────

  Widget _buildDangerZone(UserProfileController ctrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Account',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _textDark,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 16),
            CommonDeleteButton(
              onConfirm: (password) async {
                try {
                  await AuthService.to.deleteAccount(password: password);
                  Get.offAll(() => const RegisterScreen());
                } catch (e) {
                  SnackBarHelper.error(AuthService.extractError(e));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Support card ──────────────────────────────────────────────────────────

  Widget _buildSupportCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE84545), Color(0xFFF36969)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Having issues with your profile?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Our support team is ready to help.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => Get.to(() => const IssuesScreen()),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Get Help',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _primary,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    return Column(
      children: [
        const Text(
          'App v1.3.2',
          style: TextStyle(
            fontSize: 11,
            color: _textGrey,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () =>
                  Get.to(() => const LegalScreen(type: LegalType.termsOfService)),
              child: const Text(
                'Terms & Conditions',
                style: TextStyle(
                  fontSize: 11,
                  color: _primary,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                '•',
                style: TextStyle(color: _textGrey, fontSize: 11),
              ),
            ),
            GestureDetector(
              onTap: () =>
                  Get.to(() => const LegalScreen(type: LegalType.privacyPolicy)),
              child: const Text(
                'Privacy Policy',
                style: TextStyle(
                  fontSize: 11,
                  color: _primary,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Profile photo upload ──────────────────────────────────────────────────

  /// Pick a photo (camera/gallery) and upload it as the business logo via the
  /// web-parity base64 `PUT /users/profile` flow, then refresh the profile.
  Future<void> _pickAndUploadPhoto(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Iconsax.camera, color: _primary),
            title: const Text('Take Photo',
                style: TextStyle(fontFamily: 'Poppins')),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Iconsax.gallery, color: _primary),
            title: const Text('Choose from Gallery',
                style: TextStyle(fontFamily: 'Poppins')),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Iconsax.close_circle, color: _textGrey),
            title: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins')),
            onTap: () => Navigator.pop(context),
          ),
        ]),
      ),
    );
    if (source == null) return;

    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (picked == null) return;
      final file = File(picked.path);
      if (await file.length() > 5 * 1024 * 1024) {
        SnackBarHelper.error('Image size should be less than 5MB');
        return;
      }
      final photoUrl = await FirebaseStorageService.uploadProfileImage(file);
      if (photoUrl.isEmpty) {
        SnackBarHelper.error('Could not upload the selected photo. Please try again.');
        return;
      }

      final ctrl = Get.isRegistered<SpRegisterController>()
          ? Get.find<SpRegisterController>()
          : Get.put(SpRegisterController());
      final ok = await ctrl.updateProfilePhoto(photoUrl);
      if (ok) {
        await Get.find<UserProfileController>().fetchCurrentUserProfile();
        SnackBarHelper.success('Profile photo updated');
      }
    } catch (e) {
      AppLogger.e('Failed to update profile photo', error: e);
      SnackBarHelper.error('Failed to update photo: $e');
    }
  }

  // ── Navigation helpers ────────────────────────────────────────────────────

  void _navigateToEdit(BuildContext context, UserProfileModel? profile) {
    if (profile == null || profile.userId.isEmpty) {
      SnackBarHelper.error('Unable to edit profile. User ID not found.');
      return;
    }
    // Edit reuses the business profile form (pre-filled from the cached user
    // profile) and posts the same PUT /users/profile as the web edit flow.
    Get.to(() => const ServiceProviderCompleteProfileScreen(isEdit: true))
        ?.then((result) {
      if (result == true) {
        Get.find<UserProfileController>().fetchCurrentUserProfile();
      }
    });
  }

  void _navigateToEditFromCtrl() {
    final ctrl = Get.find<UserProfileController>();
    final profile = ctrl.userProfile.value;
    if (profile == null || profile.userId.isEmpty) {
      SnackBarHelper.error('Unable to edit profile.');
      return;
    }
    Get.to(() => const ServiceProviderCompleteProfileScreen(isEdit: true))
        ?.then((result) {
      if (result == true) ctrl.fetchCurrentUserProfile();
    });
  }

  void _contactUs() async {
    final uri = Uri(scheme: 'tel', path: '+917420861942');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      SnackBarHelper.error('Cannot open phone dialer');
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Log Out',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: _textGrey, fontFamily: 'Poppins'),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              try {
                await AuthService.to.logout();
                Get.offAll(() => const RegisterScreen());
              } catch (e) {
                AppLogger.e('Logout error: $e');
                SnackBarHelper.error('An error occurred during logout.');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Log Out',
              style: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Pure helpers ──────────────────────────────────────────────────────────

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return 'B';
  }

  Widget _initialsAvatar(String initials, double size) {
    return Container(
      width: size,
      height: size,
      color: Colors.white.withValues(alpha: 0.25),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: size * 0.35,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontFamily: 'Poppins',
          ),
        ),
      ),
    );
  }
}

// ── Error / retry widget ─────────────────────────────────────────────────────

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Iconsax.warning_2, size: 48, color: _primary),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: _textGrey,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Iconsax.refresh, size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
