import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../services/profile_service.dart';
import '../../../services/verification_service.dart';
import '../../../theme/design_system.dart';
import '../../../widgets/custom_snackbar.dart';

/// Professional profile completion.
///
/// 1:1 with the web `src/app/professional/complete-profile/page.tsx`:
/// same fields (address / city / state / zip + DOB / vehicleType / licenseNumber),
/// same "Verify License" step (the licence image is read by OCR — the provider
/// sells no licence-number + date-of-birth lookup), and the same
/// `PUT /users/profile` payload — the verified flags (`isVerified` / `kycStatus` /
/// `kycDetails`) are merged into the profile exactly like the web page does.
///
/// Doubles as an "Edit" entry ([isEdit] = true): pre-filled, no "Skip", returns
/// `true` to the caller on success.
class ProfessionalCompleteProfileScreen extends StatefulWidget {
  const ProfessionalCompleteProfileScreen({super.key, this.isEdit = false});

  final bool isEdit;

  @override
  State<ProfessionalCompleteProfileScreen> createState() =>
      _ProfessionalCompleteProfileScreenState();
}

class _ProfessionalCompleteProfileScreenState
    extends State<ProfessionalCompleteProfileScreen> {
  final ProfileService _profileService = ProfileService();

  // Same option lists as the web page.
  static const _vehicleTypes = <String>[
    'Car',
    'Truck',
    'Van',
    'Bus',
    'Motorcycle',
    'Heavy Vehicle',
  ];

  static const _indianStates = <String>[
    'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
    'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka',
    'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya',
    'Mizoram', 'Nagaland', 'Odisha', 'Punjab', 'Rajasthan', 'Sikkim',
    'Tamil Nadu', 'Telangana', 'Tripura', 'Uttar Pradesh', 'Uttarakhand',
    'West Bengal', 'Delhi', 'Jammu and Kashmir', 'Ladakh',
  ];

  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();

  String? _state;
  String? _vehicleType;
  String _dateOfBirth = ''; // ISO 'YYYY-MM-DD'

  // DL verification state (mirrors the web page).
  bool _verifying = false;
  bool _dlVerified = false;
  Map<String, dynamic>? _verifiedDetails;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _prefillFromProfile();
  }

  void _prefillFromProfile() {
    final p = AuthService.to.user?.profile ?? const {};
    _addressCtrl.text = (p['address'] ?? '').toString();
    _cityCtrl.text = (p['city'] ?? '').toString();
    _zipCtrl.text = (p['zipCode'] ?? '').toString();
    _licenseCtrl.text = (p['licenseNumber'] ?? '').toString();
    _dateOfBirth = (p['dateOfBirth'] ?? '').toString();

    final st = (p['state'] ?? '').toString();
    if (_indianStates.contains(st)) _state = st;
    final vt = (p['vehicleType'] ?? '').toString();
    if (_vehicleTypes.contains(vt)) _vehicleType = vt;
    if ((p['isVerified'] == true) || (p['kycStatus'] == 'verified')) {
      _dlVerified = true;
    }
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _zipCtrl.dispose();
    _licenseCtrl.dispose();
    super.dispose();
  }

  // ── Date of birth picker ───────────────────────────────────────────────
  Future<void> _pickDob() async {
    DateTime initial = DateTime(2000, 1, 1);
    if (_dateOfBirth.isNotEmpty) {
      initial = DateTime.tryParse(_dateOfBirth) ?? initial;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppPalette.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _dateOfBirth =
            '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
        _dlVerified = false; // DOB changed → re-verify
      });
    }
  }

  // ── Verify License — reads the licence from a photo of it ──────────────
  //
  // The provider's only Driving Licence product is OCR, so the licence itself
  // is the input; the number and date of birth are filled in from what it
  // reads rather than typed in to look it up.
  Future<void> _verifyLicense() async {
    if (_verifying) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppPalette.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined,
                  color: AppPalette.primary),
              title: Text('Take a photo of your licence',
                  style: AppText.body.on(AppPalette.textDark)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppPalette.primary),
              title: Text('Choose from gallery',
                  style: AppText.body.on(AppPalette.textDark)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    // Downscaled before upload: the OCR endpoint caps a document at 5MB.
    final picked = await ImagePicker()
        .pickImage(source: source, imageQuality: 70, maxWidth: 1600);
    if (picked == null || !mounted) return;

    setState(() => _verifying = true);
    try {
      final result =
          await VerificationService().verifyDriverLicence(File(picked.path));
      if (!mounted) return;

      final dl = result.data;
      if (!result.verified || dl == null) {
        // Backend-authored and always user-safe.
        SnackBarHelper.error(result.message);
        return;
      }

      setState(() {
        _dlVerified = true;
        _verifiedDetails = {
          'name': dl.name,
          'licenseNumber': dl.licenseNumber,
          'dateOfBirth': dl.dateOfBirth,
          'address': dl.address,
          'expiryDate': dl.expiryDate,
        };
        // Fill in what the licence itself says, so the profile carries the
        // verified values rather than whatever was typed before.
        final licence = dl.licenseNumber?.trim() ?? '';
        if (licence.isNotEmpty) _licenseCtrl.text = licence;

        final dob = _isoFromDDMMYYYY(dl.dateOfBirth?.trim() ?? '');
        if (dob != null) _dateOfBirth = dob;

        final address = dl.address?.trim() ?? '';
        if (address.isNotEmpty && _addressCtrl.text.trim().isEmpty) {
          _addressCtrl.text = address;
        }
      });
      SnackBarHelper.success(result.message);
    } catch (e) {
      if (mounted) {
        SnackBarHelper.error('Verification failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  /// `DD/MM/YYYY` (what the provider returns) to the `YYYY-MM-DD` this screen
  /// stores. Parsed explicitly so 10/02/2030 is never read as 2 October.
  String? _isoFromDDMMYYYY(String value) {
    final parts = value.split('/');
    if (parts.length != 3) return null;
    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (d == null || m == null || y == null) return null;
    return '${y.toString().padLeft(4, '0')}-'
        '${m.toString().padLeft(2, '0')}-'
        '${d.toString().padLeft(2, '0')}';
  }

  String? _validate() {
    if (_addressCtrl.text.trim().isEmpty ||
        _cityCtrl.text.trim().isEmpty ||
        _state == null ||
        _zipCtrl.text.trim().isEmpty) {
      return 'Please fill in all required address fields.';
    }
    return null;
  }

  Future<void> _submit() async {
    final error = _validate();
    if (error != null) {
      SnackBarHelper.error(error);
      return;
    }
    setState(() => _saving = true);

    // Merge onto the existing profile (web spreads `...user.profile` first).
    final profile = <String, dynamic>{...?AuthService.to.user?.profile};

    void putStr(String key, String value) {
      if (value.trim().isNotEmpty) profile[key] = value.trim();
    }

    putStr('address', _addressCtrl.text);
    putStr('city', _cityCtrl.text);
    if (_state != null) profile['state'] = _state;
    putStr('zipCode', _zipCtrl.text);
    if (_dateOfBirth.isNotEmpty) profile['dateOfBirth'] = _dateOfBirth;
    if (_vehicleType != null) profile['vehicleType'] = _vehicleType;
    putStr('licenseNumber', _licenseCtrl.text);

    // Verification state is NOT sent from here.
    //
    // This previously submitted `isVerified` / `kycStatus` / `kycDetails`
    // derived from the client's own DL check, letting the app declare itself
    // verified. Those fields are owned by the backend — the DL verification
    // this screen performs already goes through `POST /kyc/verify/driving-license`,
    // which validates against the provider and persists `dlStatus` server-side.
    // The server now strips these keys from client profile updates, so sending
    // them would be a silent no-op anyway.

    try {
      await _profileService.updateProfile(profile: profile);
      // Refresh the cached user so home/profile reflect the new data.
      await AuthService.to.getProfile();
      if (!mounted) return;
      if (widget.isEdit) {
        SnackBarHelper.success('Profile updated successfully!');
        Get.back(result: true);
      } else {
        SnackBarHelper.success('Profile completed successfully!');
        Get.offAllNamed(AppRoutes.professionalHome);
      }
    } catch (e) {
      SnackBarHelper.error('Failed to update profile. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _skip() => Get.offAllNamed(AppRoutes.professionalHome);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.bg,
      appBar: AppBar(
        backgroundColor: AppPalette.card,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppPalette.textDark),
          onPressed: () => Get.back(),
        ),
        title: Text(
          widget.isEdit ? 'Edit Profile' : 'Complete Your Profile',
          style: AppText.h3,
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.isEdit) ...[
              Text(
                'Please provide additional details to verify your account.',
                style: AppText.bodySm,
              ),
              AppSpacing.vGapLg,
            ],

            _card('Address Information', [
              _field(
                label: 'Detailed Address',
                hint: '123, Street name, area',
                controller: _addressCtrl,
                required: true,
              ),
              AppSpacing.vGapLg,
              _field(
                label: 'City',
                hint: 'Mumbai',
                controller: _cityCtrl,
                required: true,
              ),
              AppSpacing.vGapLg,
              _dropdown(
                label: 'State',
                required: true,
                value: _state,
                hint: 'Select State',
                items: _indianStates,
                onChanged: (v) => setState(() => _state = v),
              ),
              AppSpacing.vGapLg,
              _field(
                label: 'ZIP Code',
                hint: '400001',
                controller: _zipCtrl,
                required: true,
                keyboardType: TextInputType.number,
              ),
            ]),
            AppSpacing.vGapLg,

            _card('Professional Details', [
              _dateField(),
              AppSpacing.vGapLg,
              _dropdown(
                label: 'Vehicle Type',
                value: _vehicleType,
                hint: 'Select Vehicle Type',
                items: _vehicleTypes,
                onChanged: (v) => setState(() => _vehicleType = v),
              ),
              AppSpacing.vGapLg,
              _field(
                label: 'License Number',
                hint: 'DL-1234567890',
                controller: _licenseCtrl,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) {
                  if (_dlVerified) setState(() => _dlVerified = false);
                },
              ),
              const SizedBox(height: 10),
              _verifyRow(),
            ]),
            const SizedBox(height: 24),

            AppPrimaryButton(
              label: widget.isEdit ? 'Save Changes' : 'Complete Profile',
              icon: Icons.check_rounded,
              loading: _saving,
              onPressed: _submit,
            ),
            if (!widget.isEdit) ...[
              AppSpacing.vGapMd,
              Center(
                child: TextButton(
                  onPressed: _saving ? null : _skip,
                  child: Text('Skip for now',
                      style: AppText.subtitle.on(AppPalette.textGrey)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Verify-license row (button + verified summary) ─────────────────────
  Widget _verifyRow() {
    // The licence photo IS the input, so there is nothing to fill in first.
    final canVerify = !_verifying && !_dlVerified;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: canVerify ? _verifyLicense : null,
            icon: Icon(
              _dlVerified ? Icons.verified_rounded : Icons.badge_outlined,
              size: 18,
              color: _dlVerified ? AppPalette.green : AppPalette.blue,
            ),
            label: Text(
              _verifying
                  ? 'Reading licence…'
                  : _dlVerified
                      ? 'Verified'
                      : 'Scan License',
              style: AppText.subtitle.on(
                _dlVerified ? AppPalette.green : AppPalette.blue,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              side: BorderSide(
                color: _dlVerified ? AppPalette.green : AppPalette.blue,
              ),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.rLg),
            ),
          ),
        ),
        if (_dlVerified && _verifiedDetails != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppPalette.greenBg,
              borderRadius: AppRadius.rLg,
              border: Border.all(color: AppPalette.green.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verified: ${_verifiedDetails!['name'] ?? _verifiedDetails!['holderName'] ?? ''}',
                  style: AppText.bodySm.on(AppPalette.green),
                ),
                if ((_verifiedDetails!['expiryDate'] ?? '').toString().isNotEmpty)
                  Text(
                    'Expiry: ${_verifiedDetails!['expiryDate']}',
                    style: AppText.caption.on(AppPalette.green),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── Helpers (mirrors the SP complete-profile design-system widgets) ────
  Widget _card(String title, List<Widget> children) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: AppText.micro.copyWith(letterSpacing: 0.8)),
          AppSpacing.vGapMd,
          ...children,
        ],
      ),
    );
  }

  Widget _label(String text, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          text: text,
          style: AppText.label.copyWith(color: AppPalette.textMid),
          children: [
            if (required)
              const TextSpan(
                  text: ' *', style: TextStyle(color: AppPalette.danger)),
          ],
        ),
      ),
    );
  }

  BoxDecoration get _inputBox => BoxDecoration(
        color: AppPalette.bg,
        borderRadius: AppRadius.rLg,
        border: Border.all(color: AppPalette.border),
      );

  Widget _field({
    required String label,
    required String hint,
    required TextEditingController controller,
    bool required = false,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label, required: required),
        Container(
          decoration: _inputBox,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            onChanged: (v) {
              if (onChanged != null) onChanged(v);
              setState(() {});
            },
            style: AppText.body.on(AppPalette.textDark),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppText.body.on(AppPalette.textFaint),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dateField() {
    final hasValue = _dateOfBirth.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Date of Birth'),
        GestureDetector(
          onTap: _pickDob,
          child: Container(
            decoration: _inputBox,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 18, color: AppPalette.textGrey),
                const SizedBox(width: 10),
                Text(
                  hasValue ? _dateOfBirth : 'Select date of birth',
                  style: AppText.body.on(
                      hasValue ? AppPalette.textDark : AppPalette.textFaint),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label, required: required),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: _inputBox,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.expand_more_rounded,
                  color: AppPalette.textGrey),
              hint: Text(hint, style: AppText.body.on(AppPalette.textFaint)),
              style: AppText.body.on(AppPalette.textDark),
              items: items
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
