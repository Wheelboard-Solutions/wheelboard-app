import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Whether the app may sell paid plans and capacity charges (Razorpay).
///
/// Subscriptions and extra-vehicle/driver charges unlock features inside the
/// app, so on iOS App Store guideline 3.1.1 would require In-App Purchase.
/// They stay on Android and the web; iOS shows the user's limits but never
/// offers a purchase.
bool get paidPlansAvailable => kIsWeb || !Platform.isIOS;
