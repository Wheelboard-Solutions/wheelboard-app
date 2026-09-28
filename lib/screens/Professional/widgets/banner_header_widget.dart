import 'package:flutter/material.dart';

import 'professional_header_widget.dart';

/// Legacy banner widget — greeting text is now directly integrated into
/// [ProfessionalHeaderWidget].
@Deprecated('Use ProfessionalHeaderWidget which now integrates user greeting.')
class BannerHeaderWidget extends StatelessWidget {
  const BannerHeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
