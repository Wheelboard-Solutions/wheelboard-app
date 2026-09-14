import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/Transport/company_booking_controller.dart';
import '../../models/service_booking_model.dart';
import '../../utils/map_navigation_utils.dart';
import '../../widgets/custom_snackbar.dart';
import 'services_screen.dart' show bookingStatusStyle;

/// Company (consumer) booking detail — mirrors the web `/company/bookings/[id]`:
/// status timeline, schedule/location/amount, and the company-side actions
/// (Pay Now, Confirm Completion, Cancel) backed by [CompanyBookingController].
class CompanyBookingDetailScreen extends StatefulWidget {
  final String bookingId;
  const CompanyBookingDetailScreen({super.key, required this.bookingId});

  @override
  State<CompanyBookingDetailScreen> createState() =>
      _CompanyBookingDetailScreenState();
}

class _CompanyBookingDetailScreenState
    extends State<CompanyBookingDetailScreen> {
  static const _primary = Color(0xFFF36969);
  static const _bg = Color(0xFFF6F7F8);
  static const _textDark = Color(0xFF111827);
  static const _textGrey = Color(0xFF6B7280);
  static const _border = Color(0xFFE5E7EB);

  late final CompanyBookingController _ctrl;
  final _loadingDetail = true.obs;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.isRegistered<CompanyBookingController>()
        ? Get.find<CompanyBookingController>()
        : Get.put(CompanyBookingController());
    _load();
  }

  Future<void> _load() async {
    _loadingDetail.value = true;
    await _ctrl.getBookingById(widget.bookingId);
    _loadingDetail.value = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: const BackButton(color: _textDark),
        title: const Text('Booking Details',
            style: TextStyle(
                color: _textDark,
                fontWeight: FontWeight.w700,
                fontFamily: 'Poppins')),
        centerTitle: true,
      ),
      body: Obx(() {
        if (_loadingDetail.value && _ctrl.selected.value == null) {
          return const Center(child: CircularProgressIndicator(color: _primary));
        }
        final b = _ctrl.selected.value;
        if (b == null) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline, size: 48, color: _textGrey),
              const SizedBox(height: 12),
              const Text('Booking not found',
                  style: TextStyle(color: _textGrey, fontFamily: 'Poppins')),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('Retry')),
            ]),
          );
        }
        return RefreshIndicator(
          color: _primary,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _headerCard(b),
              const SizedBox(height: 14),
              _timelineCard(b),
              const SizedBox(height: 14),
              _detailsCard(b),
              const SizedBox(height: 14),
              _paymentCard(b),
            ],
          ),
        );
      }),
      bottomNavigationBar: Obx(() {
        final b = _ctrl.selected.value;
        if (b == null) return const SizedBox.shrink();
        return _actionBar(b);
      }),
    );
  }

  // ── header ──────────────────────────────────────────────────────────────────
  Widget _headerCard(ServiceBookingModel b) {
    final st = bookingStatusStyle(b.status);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF36969), Color(0xFFE85555)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(b.serviceTitle,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins')),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: st.bg, borderRadius: BorderRadius.circular(20)),
            child: Text(b.status,
                style: TextStyle(
                    color: st.fg,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    fontFamily: 'Poppins')),
          ),
        ]),
        const SizedBox(height: 6),
        if ((b.category ?? '').isNotEmpty)
          Text(b.category!,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 14),
        Row(children: [
          // The amount is only meaningful once the provider sets it on
          // completion. Until then show "Amount on completion" instead of a
          // misleading ₹0.
          if (b.amount > 0) ...[
            const Icon(Icons.currency_rupee, color: Colors.white, size: 18),
            Text(b.amount.toStringAsFixed(0),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Poppins')),
          ] else
            const Text('Amount on completion',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins')),
          const SizedBox(width: 8),
          if (b.bookingNo != null && b.bookingNo!.isNotEmpty)
            Text('#${b.bookingNo}',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
      ]),
    );
  }

  // ── status timeline ─────────────────────────────────────────────────────────
  Widget _timelineCard(ServiceBookingModel b) {
    final statusL = b.status.toLowerCase();
    final cancelled = statusL == 'cancelled';

    // Bookings are created as 'Assigned' and move Assigned → Started →
    // Completed. ('Pending' was a phantom leading step that always showed as
    // done, making an assigned booking look half-finished.)
    const steps = ['Assigned', 'Started', 'Completed'];
    var idx = steps.indexWhere((s) => s.toLowerCase() == statusL);
    if (statusL == 'completed' || b.fullyCompleted) idx = steps.length - 1;
    if (idx < 0) idx = 0;

    final paid = b.isPaid;
    final paymentPending = !paid &&
        ['pending', 'confirmationpending']
            .contains(b.paymentStatus.toLowerCase());

    return _card(
      title: 'Progress',
      child: cancelled
          ? Row(children: const [
              Icon(Icons.cancel, color: Color(0xFFDC2626), size: 20),
              SizedBox(width: 10),
              Text('This booking was cancelled',
                  style: TextStyle(
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins')),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                children: [
                  for (var i = 0; i < steps.length; i++) ...[
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: i <= idx ? const Color(0xFF22C55E) : _border,
                          shape: BoxShape.circle,
                        ),
                        child: i <= idx
                            ? const Icon(Icons.check,
                                size: 11, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(height: 5),
                      Text(steps[i],
                          style: TextStyle(
                              fontSize: 10,
                              color: i <= idx ? _textDark : _textGrey,
                              fontWeight:
                                  i == idx ? FontWeight.w700 : FontWeight.w400,
                              fontFamily: 'Poppins')),
                    ]),
                    if (i < steps.length - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          margin: const EdgeInsets.only(bottom: 16),
                          color: i < idx ? const Color(0xFF22C55E) : _border,
                        ),
                      ),
                  ],
                ],
              ),
              // Payment / completion badges (mirrors the web booking detail), so
              // the progress reflects the real state — e.g. a booking that is
              // still 'Assigned' but has already been paid no longer looks like
              // nothing has happened.
              if (b.fullyCompleted || paid || paymentPending) ...[
                const SizedBox(height: 14),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  if (b.fullyCompleted)
                    _progressChip('Fully Completed', const Color(0xFF16A34A),
                        const Color(0xFFDCFCE7)),
                  if (paid)
                    _progressChip('Payment Completed', const Color(0xFF16A34A),
                        const Color(0xFFDCFCE7))
                  else if (paymentPending)
                    _progressChip('Payment Pending', const Color(0xFFB45309),
                        const Color(0xFFFEF3C7)),
                ]),
              ],
            ]),
    );
  }

  Widget _progressChip(String label, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              fontFamily: 'Poppins')),
    );
  }

  // ── details ─────────────────────────────────────────────────────────────────
  Widget _detailsCard(ServiceBookingModel b) {
    return _card(
      title: 'Booking Information',
      child: Column(children: [
        _row(Icons.calendar_today_outlined, 'Scheduled',
            _fmtSchedule(b.scheduledDate, b.scheduledTime)),
        if ((b.location ?? '').isNotEmpty) ...[
          _row(Icons.location_on_outlined, 'Location', b.location!),
          _navigateToServiceLocation(b),
        ],
        if ((b.customerName).isNotEmpty)
          _row(Icons.business_outlined, 'Booked for', b.customerName),
        if ((b.vehicleNumber ?? '').isNotEmpty)
          _row(Icons.local_shipping_outlined, 'Vehicle', b.vehicleNumber!),
        if ((b.description ?? '').isNotEmpty)
          _row(Icons.notes_outlined, 'Notes', b.description!),
      ]),
    );
  }

  // ── payment ─────────────────────────────────────────────────────────────────
  Widget _paymentCard(ServiceBookingModel b) {
    return _card(
      title: 'Payment',
      child: Column(children: [
        _row(Icons.payments_outlined, 'Method', b.paymentMethod),
        _row(
          b.isPaid ? Icons.check_circle : Icons.schedule,
          'Status',
          b.isPaid ? 'Paid' : b.paymentStatus,
          valueColor:
              b.isPaid ? const Color(0xFF16A34A) : const Color(0xFFD97706),
        ),
        if (b.amountPaid != null && b.amountPaid! > 0)
          _row(Icons.account_balance_wallet_outlined, 'Amount paid',
              '₹${b.amountPaid!.toStringAsFixed(0)}'),
      ]),
    );
  }

  // ── action bar ──────────────────────────────────────────────────────────────
  Widget _actionBar(ServiceBookingModel b) {
    final statusL = b.status.toLowerCase();
    final payL = b.paymentStatus.toLowerCase();

    // Payment is only DUE once the provider has completed the service and set a
    // payable amount (the backend marks `businessCompletionConfirmed` and writes
    // the final amount during completion). Before that the amount is ₹0 / not
    // finalised, so the old "Pay Now ₹0" button was wrong. Show payment ONLY
    // when it is genuinely due: online, unpaid, provider-completed, amount > 0.
    final paymentDue = b.isOnline &&
        !b.isPaid &&
        statusL != 'cancelled' &&
        b.businessCompletionConfirmed &&
        b.amount > 0;

    // Confirm only after payment is settled (online) or for cash — never show
    // Confirm and Pay at the same time.
    final canConfirm = b.businessCompletionConfirmed &&
        !b.companyCompletionConfirmed &&
        !paymentDue;

    // A booking can be cancelled ONLY while it is still early-stage. Once it is
    // paid, completed, or the provider has finished the work, cancellation is
    // not allowed (this is why a paid/completed booking must not show Cancel).
    final locked = b.isPaid ||
        b.fullyCompleted ||
        b.businessCompletionConfirmed ||
        ['completed', 'cancelled', 'started', 'inprogress'].contains(statusL) ||
        ['completed', 'paid', 'confirmationpending', 'refunded'].contains(payL);
    final canCancel =
        ['pending', 'assigned'].contains(statusL) && !locked;

    final buttons = <Widget>[];
    if (canConfirm) {
      buttons.add(_primaryBtn('Confirm Completion',
          () => _ctrl.confirmCompletion(b.assignmentId)));
    }
    if (paymentDue) {
      buttons.add(_primaryBtn('Pay Now ₹${b.amount.toStringAsFixed(0)}',
          () => _ctrl.payBooking(b)));
    }
    if (canCancel && buttons.isEmpty) {
      buttons.add(_outlineBtn('Cancel Booking', () => _confirmCancel(b)));
    }
    if (buttons.isEmpty) return const SizedBox.shrink();

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: _border)),
        ),
        child: Obx(() {
          final busy = _ctrl.isProcessing.value;
          return Row(
            children: [
              for (var i = 0; i < buttons.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: AbsorbPointer(absorbing: busy, child: Opacity(opacity: busy ? 0.6 : 1, child: buttons[i]))),
              ],
            ],
          );
        }),
      ),
    );
  }

  void _confirmCancel(ServiceBookingModel b) {
    Get.dialog(AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Cancel booking?',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
      content: const Text('This will cancel your service booking.',
          style: TextStyle(fontFamily: 'Poppins')),
      actions: [
        TextButton(
            onPressed: () => Get.back(),
            child: const Text('Keep', style: TextStyle(color: _textGrey))),
        ElevatedButton(
          onPressed: () {
            Get.back();
            _ctrl.cancelBooking(b.assignmentId);
          },
          style: ElevatedButton.styleFrom(backgroundColor: _primary),
          child: const Text('Cancel Booking',
              style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  // ── shared widgets ──────────────────────────────────────────────────────────
  Widget _card({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _textDark,
                fontFamily: 'Poppins')),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }

  /// Directions to where the service happens.
  ///
  /// The destination is the BOOKING'S service location — the address the
  /// provider saved on the listing and the company confirmed at assignment —
  /// never the phone's current position, which is where the driver already is.
  ///
  /// A booking records that location as text (the booking table has no
  /// coordinate columns), so this routes by address. Shown only when there is
  /// an address to route to; the caller already gates on that.
  Widget _navigateToServiceLocation(ServiceBookingModel b) {
    final destination = (b.location ?? '').trim();
    if (destination.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _openDirections(destination),
          icon: const Icon(Icons.directions_outlined, size: 18),
          label: const Text(
            'Navigate to service location',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFamily: 'Poppins',
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: _primary,
            side: const BorderSide(color: _primary),
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openDirections(String destination) async {
    final opened = await MapNavigationUtils.openDirectionsToAddress(
      address: destination,
    );
    if (!opened && mounted) {
      SnackBarHelper.error('No maps app could open this location.');
    }
  }

  Widget _row(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: _textGrey),
        const SizedBox(width: 10),
        Text('$label  ',
            style: const TextStyle(color: _textGrey, fontSize: 13)),
        Expanded(
          child: Text(value,
              textAlign: TextAlign.right,
              style: TextStyle(
                  color: valueColor ?? _textDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins')),
        ),
      ]),
    );
  }

  Widget _primaryBtn(String label, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label,
          style: const TextStyle(
              fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
    );
  }

  Widget _outlineBtn(String label, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: _primary,
        side: const BorderSide(color: _primary),
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label,
          style: const TextStyle(
              fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
    );
  }

  String _fmtSchedule(String date, String time) {
    final d = date.isNotEmpty ? date.split('T').first : '';
    if (d.isEmpty && time.isEmpty) return '—';
    return [d, if (time.isNotEmpty) time].join(' · ');
  }
}
