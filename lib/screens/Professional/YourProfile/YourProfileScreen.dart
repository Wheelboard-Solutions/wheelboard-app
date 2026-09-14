import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../controllers/Transport/driver_details_controller.dart';
import '../../../controllers/Transport/user_profile_controller.dart';
import '../../../core/auth/auth_service.dart';
import '../../../models/user_profile_model.dart';
import '../../../widgets/common_delete_button.dart';
import '../../../widgets/custom_snackbar.dart';
import '../../../widgets/change_password_sheet.dart';
import '../../../widgets/legal_widgets.dart';
import '../../auth/onboarding_screen.dart';
import '../EditYourProfile01/EditYourProfile01Screen.dart';
import '../CompleteProfile/professional_complete_profile_screen.dart';
import '../KYC/kyc_screen.dart';
import '../../shared/subscription_screen.dart';
import '../../shared/wallet_screen.dart';
import '../../shared/issues/issues_screen.dart';
import '../../shared/legal_screen.dart';
import '../../../widgets/language_selection_bottom_sheet.dart';
import '../../../core/localization/localization_service.dart';


// ── Design tokens ────────────────────────────────────────────────────────────
const _primary = Color(0xFFF36969);
const _primaryLight = Color(0xFFFFF1F1);
const _bg = Color(0xFFF9FAFB);
const _cardBg = Colors.white;
const _textDark = Color(0xFF111827);
const _textGrey = Color(0xFF6B7280);
const _border = Color(0xFFE5E7EB);

class YourProfileScreen extends StatelessWidget {
  const YourProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(UserProfileController());
    final driverCtrl = Get.put(DriverDetailsController());

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ctrl.fetchCurrentUserProfile();
      ctrl.syncKycStatus(); // live-sync from /kyc/my-kyc (matches web panel)
      final profile = ctrl.userProfile.value;
      if (profile != null &&
          (profile.professionalType?.toLowerCase().contains('driver') ??
              false)) {
        driverCtrl.fetchDriverDetails(profile.userId);
      }
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
                  _buildKycBanner(context, profile, driverCtrl),
                  _buildCompleteProfileBanner(context),
                  _buildPersonalDetails(context, profile),
                  const SizedBox(height: 12),
                  _buildContactInfo(profile),
                  const SizedBox(height: 12),
                  _buildPlatformPreferences(ctrl),
                  const SizedBox(height: 12),
                  _buildWalletCard(),
                  const SizedBox(height: 12),
                  _buildSubscriptionCard(),
                  const SizedBox(height: 12),
                  _buildQuickActions(context),
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
    final name = profile?.name ?? 'Professional';
    final initials = _initials(name);
    final imgUrl = profile?.profileImagePath;
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
          onPressed: () => Get.to(() => const EditYourProfile01Screen()),
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
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    GestureDetector(
                      onTap: () =>
                          Get.to(() => const EditYourProfile01Screen()),
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
                    Container(
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
                if (profile?.professionalType != null &&
                    profile!.professionalType!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      profile.professionalType!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Iconsax.star1, size: 14, color: Colors.amber),
                    SizedBox(width: 4),
                    Text(
                      '4.7 / 5',
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

  // ── KYC Banner ────────────────────────────────────────────────────────────

  Widget _buildKycBanner(
    BuildContext context,
    UserProfileModel? profile,
    DriverDetailsController driverCtrl,
  ) {
    final isComplete =
        AuthService.to.isUserKYCCompleted || (profile?.isKYCCompleted ?? false);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: isComplete
          ? _kycVerifiedBanner()
          : _kycIncompleteBanner(context, profile, driverCtrl),
    );
  }

  Widget _kycVerifiedBanner() {
    return Container(
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
            child: const Icon(
              Iconsax.shield_tick,
              size: 22,
              color: Color(0xFF22C55E),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KYC Verified',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF14532D),
                    fontFamily: 'Poppins',
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'You can apply for jobs and submit bids.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF166534),
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF22C55E),
            size: 22,
          ),
        ],
      ),
    );
  }

  Widget _kycIncompleteBanner(
    BuildContext context,
    UserProfileModel? profile,
    DriverDetailsController driverCtrl,
  ) {
    final professionalType = profile?.professionalType?.toLowerCase() ?? '';
    final isDriver = professionalType.contains('driver');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
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
                      'Complete Your KYC',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF92400E),
                        fontFamily: 'Poppins',
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Required to apply for jobs and submit bids.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF92400E),
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // KYC action item
          GestureDetector(
            onTap: () => Get.to(() => const KycScreen()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isDriver ? Iconsax.card : Iconsax.document_text,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isDriver ? 'Verify Driving License' : 'Verify PAN Card',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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

  // ── Personal details ──────────────────────────────────────────────────────

  Widget _buildPersonalDetails(
    BuildContext context,
    UserProfileModel? profile,
  ) {
    final location = [
      profile?.city,
      profile?.state,
    ].whereType<String>().join(', ');
    return _card(
      title: 'Personal Details',
      trailing: GestureDetector(
        onTap: () => Get.to(() => const EditYourProfile01Screen()),
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
          Iconsax.profile_circle,
          const Color(0xFF3B82F6),
          'Full Name',
          profile?.name ?? '—',
        ),
        if (profile?.fatherName != null && profile!.fatherName!.isNotEmpty)
          _infoRow(
            Iconsax.profile_2user,
            const Color(0xFF8B5CF6),
            "Father's Name",
            profile.fatherName!,
          ),
        if (profile?.dateOfBirth != null)
          _infoRow(
            Iconsax.calendar,
            const Color(0xFFF59E0B),
            'Date of Birth',
            _formatDate(profile?.dateOfBirth),
          ),
        if (location.isNotEmpty)
          _infoRow(
            Iconsax.location,
            const Color(0xFF0EA5E9),
            'City / State',
            location,
          ),
      ],
    );
  }

  // ── Contact info ──────────────────────────────────────────────────────────

  Widget _buildContactInfo(UserProfileModel? profile) {
    return _card(
      title: 'Contact Information',
      children: [
        _infoRow(
          Iconsax.call,
          const Color(0xFF22C55E),
          'Mobile Number',
          profile?.mobileNo ?? '—',
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
          profile?.mobileNo ?? '—',
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
          Get.to(() => const SubscriptionScreen(category: 'professional')),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF36969), Color(0xFFE84545)],
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

  // ── Complete-profile nudge ─────────────────────────────────────────────────
  // Mirrors the web `/professional/complete-profile` step (address + vehicle +
  // license). Shown only while those details are missing.

  Widget _buildCompleteProfileBanner(BuildContext context) {
    final p = AuthService.to.user?.profile ?? const {};
    bool has(String k) => (p[k]?.toString().trim().isNotEmpty ?? false);
    final isComplete = has('address') &&
        has('city') &&
        has('state') &&
        has('vehicleType') &&
        has('licenseNumber');
    if (isComplete) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: GestureDetector(
        onTap: () =>
            Get.to(() => const ProfessionalCompleteProfileScreen()),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Iconsax.user_edit,
                    color: Color(0xFF3B82F6), size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Complete your profile',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                            fontFamily: 'Poppins')),
                    SizedBox(height: 2),
                    Text('Add your address, vehicle & license details',
                        style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                            fontFamily: 'Poppins')),
                  ],
                ),
              ),
              const Icon(Iconsax.arrow_right_3,
                  color: Color(0xFF3B82F6), size: 18),
            ],
          ),
        ),
      ),
    );
  }

  // ── Quick actions ─────────────────────────────────────────────────────────

  Widget _buildQuickActions(BuildContext context) {
    return _card(
      title: 'Quick Actions',
      children: [
        Row(
          children: [
            _actionTile(
              Iconsax.call,
              'Contact Us',
              const Color(0xFF3B82F6),
              const Color(0xFFEFF6FF),
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
                    'Having issues?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Our support team is ready to help you.',
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

  // ── Helpers ───────────────────────────────────────────────────────────────

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

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return 'P';
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

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    try {
      final d = DateTime.parse(raw);
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) {
      return raw;
    }
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
