import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../utils/app_logger.dart';
import '../utils/platform_features.dart';
import '../widgets/custom_snackbar.dart';

/// Handles the Razorpay payment flow triggered by a 402 response when adding
/// a fleet resource (driver or vehicle) that exceeds the plan limit.
///
/// Flow mirrors the web app's `handleSaveVehicle` / `handleSaveDriver` 402 path:
///   1. Backend returns 402 with { orderId, razorpayKey, amount, currency }
///   2. This service opens Razorpay checkout
///   3. On success → calls [onPaymentSuccess] with { orderId, paymentId, signature }
///      so the caller can retry the create API call with the payment proof
///   4. On failure / dismiss → calls [onPaymentError]
///
/// Usage:
/// ```dart
/// final service = FleetPaymentService(
///   onPaymentSuccess: (orderId, paymentId, signature) async {
///     await createDriver(..., payment: { orderId, paymentId, signature });
///   },
///   onPaymentError: (message) => SnackBarHelper.error(message),
/// );
/// service.openCheckout(orderData: responseData402, description: 'Extra Driver Charge');
/// // Remember to call service.dispose() when done.
/// ```
class FleetPaymentService {
  FleetPaymentService({
    required this.onPaymentSuccess,
    required this.onPaymentError,
  }) {
    _razorpay = Razorpay()
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _handleError)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  /// Called when Razorpay reports a successful payment.
  /// The caller should retry the fleet resource creation with the provided proof.
  final Future<void> Function(
    String orderId,
    String paymentId,
    String signature,
  )
  onPaymentSuccess;

  /// Called when the payment fails or is dismissed by the user.
  final void Function(String message) onPaymentError;

  late final Razorpay _razorpay;

  // We capture the orderId from the checkout options so we can pass it back
  // in [_handleSuccess] (the SDK's success response includes it too, but we
  // keep a local copy for safety).
  String? _pendingOrderId;

  /// Opens the Razorpay checkout sheet.
  ///
  /// [orderData] must contain the fields returned by the backend 402 response:
  ///   - `orderId`     : Razorpay order ID
  ///   - `razorpayKey` : Razorpay key ID
  ///   - `amount`      : charge in **rupees** (backend sends rupees, not paise)
  ///   - `currency`    : e.g. `'INR'`
  /// [description]  : Human-readable charge description shown in the sheet.
  void openCheckout({
    required Map<String, dynamic> orderData,
    required String description,
  }) {
    final orderId = orderData['orderId']?.toString() ?? '';
    final razorpayKey = orderData['razorpayKey']?.toString() ?? '';
    final amountRupees = (orderData['amount'] as num?)?.toDouble() ?? 0.0;
    final currency = orderData['currency']?.toString() ?? 'INR';

    if (orderId.isEmpty || razorpayKey.isEmpty) {
      AppLogger.e(
        '[FleetPaymentService] Missing orderId or razorpayKey in 402 data: $orderData',
      );
      onPaymentError('Payment details could not be loaded. Please try again.');
      return;
    }

    if (amountRupees <= 0) {
      AppLogger.e('[FleetPaymentService] Invalid amount: $amountRupees');
      onPaymentError('Invalid payment amount. Please contact support.');
      return;
    }

    // Razorpay SDK expects amount in PAISE (1 INR = 100 paise).
    final amountPaise = (amountRupees * 100).toInt();
    _pendingOrderId = orderId;

    AppLogger.d(
      '[FleetPaymentService] Opening checkout | orderId=$orderId '
      'amount=$amountRupees₹ (${amountPaise}p) currency=$currency',
    );

    _razorpay.open({
      'key': razorpayKey,
      'amount': amountPaise,
      'currency': currency,
      'name': 'WheelBoard',
      'description': description,
      'order_id': orderId,
      'prefill': {'contact': '', 'email': ''},
      'theme': {'color': '#F36969'},
    });
  }

  void _handleSuccess(PaymentSuccessResponse response) async {
    final orderId = response.orderId ?? _pendingOrderId ?? '';
    final paymentId = response.paymentId ?? '';
    final signature = response.signature ?? '';

    AppLogger.d(
      '[FleetPaymentService] Payment success | paymentId=$paymentId '
      'orderId=$orderId',
    );
    _pendingOrderId = null;

    try {
      await onPaymentSuccess(orderId, paymentId, signature);
    } catch (e) {
      AppLogger.e('[FleetPaymentService] Retry after payment failed: $e');
      // Payment went through but the API retry failed — show a specific message
      // so the user knows to contact support with their payment ID.
      SnackBarHelper.error(
        'Payment received (ID: $paymentId) but resource could not be added. '
        'Please contact support.',
      );
    }
  }

  void _handleError(PaymentFailureResponse response) {
    _pendingOrderId = null;
    // Code 2 = user dismissed the sheet (not a real error).
    if (response.code == 2) {
      AppLogger.d('[FleetPaymentService] User dismissed Razorpay sheet');
      return;
    }
    final message = response.message ?? 'Payment failed. Please try again.';
    AppLogger.e(
      '[FleetPaymentService] Payment error code=${response.code}: $message',
    );
    onPaymentError(message);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _pendingOrderId = null;
    AppLogger.d(
      '[FleetPaymentService] External wallet: ${response.walletName}',
    );
  }

  /// Must be called when the parent widget / controller is disposed.
  void dispose() {
    _razorpay.clear();
    AppLogger.d('[FleetPaymentService] Razorpay cleared');
  }
}

// ── Upgrade Required Dialog ───────────────────────────────────────────────────

/// Shows a dialog informing the user they have hit their plan limit (hard block)
/// and must upgrade. Matches the web app's `router.push('/company/subscriptions')`
/// flow — in the Flutter app we navigate to the subscription screen instead.
void showFleetUpgradeLimitDialog({
  required String resourceType, // 'driver' or 'vehicle'
  required int limit,
}) {
  Get.dialog(
    AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: Color(0xFFF36969),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${resourceType == 'driver' ? 'Driver' : 'Vehicle'} Limit Reached',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFamily: 'Poppins',
                color: Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'You have reached the $resourceType limit ($limit) on your current plan.',
            style: const TextStyle(
              fontSize: 13,
              fontFamily: 'Poppins',
              color: Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            paidPlansAvailable
                ? 'Upgrade your subscription to add more resources.'
                : 'Your current plan does not allow more. Contact Wheelboard to change your plan.',
            style: const TextStyle(
              fontSize: 13,
              fontFamily: 'Poppins',
              color: Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: Text(
            paidPlansAvailable ? 'Later' : 'OK',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (paidPlansAvailable)
          ElevatedButton(
            onPressed: () {
              Get.back();
              // Navigate to the subscriptions screen
              Get.toNamed('/subscriptions');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF36969),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              elevation: 0,
            ),
            child: const Text(
              'Upgrade Plan',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
      ],
    ),
    barrierDismissible: true,
  );
}
