import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';

import '../../controllers/Transport/company_profile_controller.dart';
import '../../utils/app_logger.dart';
import '../../utils/placeservices.dart';
import '../../utils/constants.dart';

// ── Design tokens ────────────────────────────────────────────────────────────
const _primary = Color(0xFFF36969);
const _primaryLight = Color(0xFFFFF1F1);
const _bg = Color(0xFFF9FAFB);
const _border = Color(0xFFE5E7EB);
const _textDark = Color(0xFF111827);
const _textGrey = Color(0xFF6B7280);

class EditCompanyProfileScreen extends StatefulWidget {
  const EditCompanyProfileScreen({super.key});

  @override
  State<EditCompanyProfileScreen> createState() =>
      _EditCompanyProfileScreenState();
}

class _EditCompanyProfileScreenState extends State<EditCompanyProfileScreen> {
  final CompanyProfileController _ctrl = Get.put(CompanyProfileController());
  final PlacesService _places =
      PlacesService(apiKey: MapsConstants.googleMapsApiKey);

  List<Suggestion> _suggestions = [];
  final FocusNode _locationFocus = FocusNode();
  Worker? _saveWorker;

  @override
  void initState() {
    super.initState();
    _locationFocus.addListener(() {
      if (!_locationFocus.hasFocus && mounted) {
        setState(() => _suggestions = []);
      }
    });
    _saveWorker = ever(_ctrl.isSaving, (bool saving) async {
      if (!saving && mounted) {
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) {
          Navigator.canPop(context)
              ? Navigator.pop(context, true)
              : Get.back(result: true);
        }
      }
    });
  }

  @override
  void dispose() {
    _saveWorker?.dispose();
    _locationFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: _border,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: _textDark),
          onPressed: () => Get.back(),
        ),
        title: const Text('Edit Company Profile',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _textDark,
                fontFamily: 'Poppins')),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: _textGrey),
            onPressed: () => Get.back(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            children: [
              // ── Logo picker ──────────────────────────────────────────
              _buildLogoPicker(),
              const SizedBox(height: 20),

              // ── Form card ────────────────────────────────────────────
              _section('Company Information', [
                _field('Company Name', _ctrl.companyNameController,
                    icon: Iconsax.building, required: true),
                _field('Contact Person', _ctrl.fullNameController,
                    icon: Iconsax.profile_circle, required: true),
                _field('Email Address', _ctrl.emailController,
                    icon: Iconsax.sms,
                    keyboard: TextInputType.emailAddress,
                    required: true),
                _field('Business Category', _ctrl.businessCategoryController,
                    icon: Iconsax.category),
                _field('Fleet Size', _ctrl.fleetSizeController,
                    icon: Iconsax.truck,
                    keyboard: TextInputType.number,
                    hint: 'No. of vehicles'),
                _field('GST Number (Optional)', _ctrl.gstController,
                    icon: Iconsax.receipt_text),
              ]),

              const SizedBox(height: 16),
              _section('Contact Details', [
                _field('Mobile Number', _ctrl.phoneController,
                    icon: Iconsax.call,
                    keyboard: TextInputType.phone),
                _field('WhatsApp Number', _ctrl.whatsappController,
                    icon: Icons.chat_rounded,
                    keyboard: TextInputType.phone),
              ]),

              const SizedBox(height: 16),
              _section('Location', [
                _locationField(),
              ]),

              const SizedBox(height: 16),
              _section('About', [
                _field('Description (Optional)', _ctrl.descriptionController,
                    icon: Iconsax.document_text,
                    maxLines: 4,
                    hint: 'Tell clients about your company…'),
                _field('Website (Optional)', _ctrl.websiteController,
                    icon: Iconsax.global,
                    keyboard: TextInputType.url,
                    hint: 'https://yourcompany.com'),
              ]),

              const SizedBox(height: 24),
              _saveButton(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Logo picker ───────────────────────────────────────────────────────────

  void _showLogoSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: _border, borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: const Icon(Iconsax.camera, color: _primary),
              title: const Text('Take a photo',
                  style: TextStyle(fontFamily: 'Poppins')),
              onTap: () {
                Navigator.pop(sheetCtx);
                _ctrl.pickLogo(source: ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Iconsax.gallery, color: _primary),
              title: const Text('Choose from gallery',
                  style: TextStyle(fontFamily: 'Poppins')),
              onTap: () {
                Navigator.pop(sheetCtx);
                _ctrl.pickLogo(source: ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoPicker() {
    return Obx(() {
      ImageProvider? img;
      if (_ctrl.logoFile != null) {
        img = FileImage(_ctrl.logoFile!);
      } else if (_ctrl.existingLogoUrl?.isNotEmpty == true) {
        img = NetworkImage(_ctrl.existingLogoUrl!);
      }

      return Center(
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            GestureDetector(
              onTap: _showLogoSourceSheet,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _primary, width: 3),
                  color: _primaryLight,
                  image: img != null
                      ? DecorationImage(image: img, fit: BoxFit.cover)
                      : null,
                ),
                child: img == null
                    ? const Icon(Iconsax.building, size: 40, color: _primary)
                    : null,
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Iconsax.camera, size: 14, color: Colors.white),
            ),
          ],
        ),
      );
    });
  }

  // ── Section card ──────────────────────────────────────────────────────────

  Widget _section(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                  fontFamily: 'Poppins')),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  // ── Text field ────────────────────────────────────────────────────────────

  Widget _field(
    String label,
    TextEditingController ctrl, {
    IconData? icon,
    TextInputType? keyboard,
    String? hint,
    bool required = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _textGrey,
                      fontFamily: 'Poppins')),
              if (required)
                const Text(' *',
                    style: TextStyle(fontSize: 12, color: _primary)),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            keyboardType: keyboard,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint ?? 'Enter $label',
              hintStyle: const TextStyle(
                  fontSize: 14, color: Color(0xFF9CA3AF), fontFamily: 'Poppins'),
              prefixIcon:
                  icon != null ? Icon(icon, size: 18, color: _textGrey) : null,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _primary, width: 1.5)),
            ),
            style: const TextStyle(
                fontSize: 14, color: _textDark, fontFamily: 'Poppins'),
          ),
        ],
      ),
    );
  }

  // ── Location field ────────────────────────────────────────────────────────

  Widget _locationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Location',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _textGrey,
                fontFamily: 'Poppins')),
        const SizedBox(height: 6),
        TextField(
          controller: _ctrl.locationController,
          focusNode: _locationFocus,
          decoration: InputDecoration(
            hintText: 'Search location…',
            hintStyle: const TextStyle(
                fontSize: 14, color: Color(0xFF9CA3AF), fontFamily: 'Poppins'),
            prefixIcon: const Icon(Iconsax.location, size: 18, color: _textGrey),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _primary, width: 1.5)),
          ),
          onChanged: (v) async {
            if (v.length > 2) {
              try {
                final results = await _places.fetchSuggestions(v);
                if (mounted) setState(() => _suggestions = results);
              } catch (e) {
                AppLogger.e('Location suggestions error: $e');
              }
            } else {
              if (mounted) setState(() => _suggestions = []);
            }
          },
        ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _suggestions.length.clamp(0, 5),
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: _border),
              itemBuilder: (_, i) {
                final s = _suggestions[i];
                return ListTile(
                  dense: true,
                  leading: const Icon(Iconsax.location, size: 18, color: _primary),
                  title: Text(s.description,
                      style: const TextStyle(
                          fontSize: 13, fontFamily: 'Poppins')),
                  onTap: () {
                    _ctrl.locationController.text = s.description;
                    _locationFocus.unfocus();
                    setState(() => _suggestions = []);
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  // ── Save button ───────────────────────────────────────────────────────────

  Widget _saveButton() {
    return Obx(() => SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _ctrl.isSaving.value ? null : _ctrl.saveProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              disabledBackgroundColor: _primary.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _ctrl.isSaving.value
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
                : const Text('Save Changes',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontFamily: 'Poppins')),
          ),
        ));
  }
}
