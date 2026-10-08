import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../screens/shared/blocked_users_screen.dart';
import '../screens/shared/legal_screen.dart';

// Design tokens (match the app's legal/auth styling)
const _primary = Color(0xFFF36969);
const _textGrey = Color(0xFF6B7280);
const _textDark = Color(0xFF111827);
const _border = Color(0xFFE5E7EB);

void openPrivacyPolicy() =>
    Get.to(() => const LegalScreen(type: LegalType.privacyPolicy));

void openTermsAndConditions() =>
    Get.to(() => const LegalScreen(type: LegalType.termsOfService));

/// Rich text: "I agree to the Terms & Conditions and Privacy Policy." with the
/// two documents as clickable links (open the in-app legal screens).
Widget legalAgreeText({double fontSize = 12.5}) {
  final base = TextStyle(
      fontSize: fontSize, color: _textGrey, fontFamily: 'Poppins', height: 1.4);
  final link = base.copyWith(color: _primary, fontWeight: FontWeight.w600);
  return Text.rich(
    TextSpan(style: base, children: [
      const TextSpan(text: 'I agree to the '),
      TextSpan(
        text: 'Terms & Conditions',
        style: link,
        recognizer: TapGestureRecognizer()..onTap = openTermsAndConditions,
      ),
      const TextSpan(text: ' and '),
      TextSpan(
        text: 'Privacy Policy',
        style: link,
        recognizer: TapGestureRecognizer()..onTap = openPrivacyPolicy,
      ),
      const TextSpan(text: '.'),
    ]),
  );
}

/// Mandatory legal-acceptance checkbox shown on registration screens.
/// The parent owns [value] and blocks registration until it is true.
class LegalAcceptanceCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const LegalAcceptanceCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            activeColor: _primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            onChanged: (v) => onChanged(v ?? false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: legalAgreeText()),
      ],
    );
  }
}

/// "By continuing, you agree to our Terms & Conditions and Privacy Policy."
/// — login screen notice with clickable links.
Widget legalLoginNotice({double fontSize = 12}) {
  final base = TextStyle(
      fontSize: fontSize, color: _textGrey, fontFamily: 'Poppins', height: 1.4);
  final link = base.copyWith(color: _primary, fontWeight: FontWeight.w600);
  return Text.rich(
    TextSpan(style: base, children: [
      const TextSpan(text: 'By continuing, you agree to our '),
      TextSpan(
        text: 'Terms & Conditions',
        style: link,
        recognizer: TapGestureRecognizer()..onTap = openTermsAndConditions,
      ),
      const TextSpan(text: ' and '),
      TextSpan(
        text: 'Privacy Policy',
        style: link,
        recognizer: TapGestureRecognizer()..onTap = openPrivacyPolicy,
      ),
      const TextSpan(text: '.'),
    ]),
    textAlign: TextAlign.center,
  );
}

/// A reusable "Legal" section for any Settings/Profile screen:
/// Privacy Policy · Terms & Conditions · Blocked users · Contact Support ·
/// About Wheelboard.
class LegalSettingsSection extends StatelessWidget {
  const LegalSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Text(
            'Legal',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _textGrey,
              fontFamily: 'Poppins',
              letterSpacing: 0.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            children: [
              _tile(Icons.shield_outlined, 'Privacy Policy', openPrivacyPolicy),
              _divider(),
              _tile(Icons.gavel_rounded, 'Terms & Conditions',
                  openTermsAndConditions),
              _divider(),
              _tile(Icons.block_rounded, 'Blocked users',
                  () => Get.to(() => const BlockedUsersScreen())),
              _divider(),
              _tile(Icons.support_agent_outlined, 'Contact Support',
                  () => Get.to(() => const ContactSupportScreen())),
              _divider(),
              _tile(Icons.info_outline_rounded, 'About Wheelboard',
                  () => Get.to(() => const AboutWheelboardScreen())),
            ],
          ),
        ),
      ],
    );
  }

  Widget _divider() =>
      const Divider(height: 1, thickness: 1, color: _border, indent: 56);

  Widget _tile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: _primary, size: 19),
      ),
      title: Text(title,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w500, color: _textDark,
              fontFamily: 'Poppins')),
      trailing:
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _textGrey),
    );
  }
}
