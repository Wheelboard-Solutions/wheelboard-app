import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/referral_program_service.dart';
import '../utils/share_service.dart';
import '../theme/app_palette.dart';

/// The partner's QR code and partner id. The QR is the signup link with their
/// referral code filled in, the same one the admin sees on the user page.
class PartnerQrCard extends StatefulWidget {
  const PartnerQrCard({super.key});

  @override
  State<PartnerQrCard> createState() => _PartnerQrCardState();
}

class _PartnerQrCardState extends State<PartnerQrCard> {
  Map<String, dynamic>? _share;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final s = await ReferralProgramService().getShareInfo();
      if (mounted) setState(() => _share = s);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final link = _share?['link']?.toString() ?? '';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppPalette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.border),
      ),
      child: Column(children: [
        Row(children: [
          const Icon(Iconsax.scan_barcode, size: 18, color: AppPalette.primary),
          const SizedBox(width: 8),
          Text('My QR code', style: GoogleFonts.poppins(
            fontSize: 14, fontWeight: FontWeight.w700, color: AppPalette.textDark)),
        ]),
        const SizedBox(height: 14),
        if (_failed)
          TextButton(onPressed: _load, child: const Text('Could not load. Tap to retry'))
        else if (link.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(color: AppPalette.primary))
        else ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppPalette.border)),
            child: QrImageView(data: link, size: 168, backgroundColor: Colors.white),
          ),
          const SizedBox(height: 12),
          Text('Partner ID', style: GoogleFonts.poppins(fontSize: 11, color: AppPalette.textGrey)),
          SelectableText(_share!['partnerId']?.toString() ?? '',
            style: GoogleFonts.poppins(
              fontSize: 15, fontWeight: FontWeight.w700, color: AppPalette.textDark)),
          const SizedBox(height: 4),
          Text('Referral code ${_share!['code'] ?? ''}',
            style: GoogleFonts.poppins(fontSize: 12, color: AppPalette.textGrey)),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => ShareService.shareGeneric(
              title: 'Join me on WheelBoard',
              content: 'List your garage on WheelBoard and get service jobs. Sign up: $link'),
            icon: const Icon(Iconsax.share, size: 16),
            label: Text('Share link', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(foregroundColor: AppPalette.primary,
              side: const BorderSide(color: AppPalette.primary))),
        ],
      ]),
    );
  }
}
