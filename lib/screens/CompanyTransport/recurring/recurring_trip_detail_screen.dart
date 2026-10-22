import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

import '../../../models/trip_template_model.dart';
import '../../../services/trip_template_service.dart';
import '../../../theme/app_palette.dart';
import '../../../widgets/custom_snackbar.dart';
import 'recurring_trip_form_screen.dart';
import 'recurring_trips_screen.dart' show formatRunDate, statusPill;

/// One repeat trip: its schedule, upcoming runs (skip / restore each one),
/// pause/resume, edit and stop.
class RecurringTripDetailScreen extends StatefulWidget {
  final String templateId;
  const RecurringTripDetailScreen({super.key, required this.templateId});

  @override
  State<RecurringTripDetailScreen> createState() => _RecurringTripDetailScreenState();
}

class _RecurringTripDetailScreenState extends State<RecurringTripDetailScreen> {
  final _service = TripTemplateService();
  TripTemplate? _t;
  String? _error;
  String? _busyDate;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final t = await _service.get(widget.templateId);
      if (mounted) setState(() { _t = t; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _run(Future<TripTemplate> Function() action, String ok, {String? date}) async {
    setState(() { _busy = true; _busyDate = date; });
    try {
      final t = await action();
      if (mounted) setState(() => _t = t);
      SnackBarHelper.success(ok);
    } catch (e) {
      SnackBarHelper.error(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() { _busy = false; _busyDate = null; });
    }
  }

  Future<void> _skip(TemplateRun r) async {
    if (r.status == 'created') {
      final ok = await _confirm('Skip ${formatRunDate(r)}?',
        'Trip ${r.tripId ?? ''} has already been created for this run. Skipping will cancel it.');
      if (ok != true) return;
    }
    await _run(() => _service.skip(_t!.templateId, r.date), 'Run skipped', date: r.date);
  }

  Future<void> _stop() async {
    final ok = await _confirm('Stop this repeat trip?',
      'No new trips will be created. Trips already created stay as they are.');
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await _service.delete(_t!.templateId);
      SnackBarHelper.success('Repeat trip stopped');
      Get.back();
    } catch (e) {
      SnackBarHelper.error(e.toString().replaceFirst('Exception: ', ''));
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirm(String title, String body) => showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
      content: Text(body, style: GoogleFonts.poppins(fontSize: 13)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(c, true),
          child: const Text('Confirm', style: TextStyle(color: AppPalette.danger))),
      ],
    ));

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return Scaffold(
      backgroundColor: AppPalette.bg,
      appBar: AppBar(
        backgroundColor: AppPalette.card,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppPalette.primary, size: 20),
          onPressed: () => Get.back()),
        centerTitle: true,
        title: Text(t?.name ?? 'Repeat Trip', maxLines: 1, overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600, color: AppPalette.textDark)),
        actions: [
          if (t != null)
            IconButton(
              icon: const Icon(Iconsax.edit, color: AppPalette.primary, size: 20),
              onPressed: _busy ? null : () async {
                final saved = await Get.to<TripTemplate>(() => RecurringTripFormScreen(template: t));
                if (saved != null) _load();
              }),
        ],
      ),
      body: t == null
          ? Center(child: _error == null
              ? const CircularProgressIndicator(color: AppPalette.primary)
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!, style: GoogleFonts.poppins(fontSize: 13, color: AppPalette.textGrey)),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ]))
          : RefreshIndicator(
              color: AppPalette.primary,
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
                _summary(t),
                const SizedBox(height: 14),
                _card('Upcoming runs', Iconsax.calendar_1, t.upcoming.isEmpty
                    ? Text(t.isPaused ? 'Paused. Resume to schedule runs again.' : 'No more runs scheduled.',
                        style: GoogleFonts.poppins(fontSize: 13, color: AppPalette.textGrey))
                    : Column(children: [for (final r in t.upcoming) _runTile(r)])),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _run(
                      () => _service.setPaused(t.templateId, !t.isPaused),
                      t.isPaused ? 'Resumed' : 'Paused'),
                    icon: Icon(t.isPaused ? Iconsax.play : Iconsax.pause, size: 18),
                    label: Text(t.isPaused ? 'Resume' : 'Pause',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    style: _outlined(AppPalette.primary))),
                  const SizedBox(width: 10),
                  Expanded(child: OutlinedButton.icon(
                    onPressed: _busy ? null : _stop,
                    icon: const Icon(Iconsax.stop_circle, size: 18),
                    label: Text('Stop', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    style: _outlined(AppPalette.danger))),
                ]),
              ]),
            ),
    );
  }

  Widget _summary(TripTemplate t) {
    final h = t.durationMinutes ~/ 60, m = t.durationMinutes % 60;
    return _card('Schedule', Iconsax.repeat, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(t.repeatLabel, style: GoogleFonts.poppins(
          fontSize: 15, fontWeight: FontWeight.w700, color: AppPalette.textDark))),
        statusPill(t.isPaused ? 'Paused' : 'Active', t.isPaused ? AppPalette.amber : AppPalette.green),
      ]),
      const SizedBox(height: 10),
      _line(Iconsax.location, 'Pickup', t.start.address),
      for (var i = 0; i < t.stops.length; i++) _line(Iconsax.location_tick, 'Stop ${i + 1}', t.stops[i].address),
      _line(Iconsax.flag, 'Drop', t.end.address),
      _line(Iconsax.clock, 'Starts', '${t.startTime} · ${h}h${m > 0 ? ' ${m}m' : ''} trip'),
      _line(Iconsax.calendar, 'Runs', t.repeatType == 'dates'
          ? t.dates.join(', ')
          : '${t.startDate} → ${t.endDate ?? 'no end date'}'),
      _line(Iconsax.truck, 'Vehicle', t.vehicleNumber ?? t.vehicleId),
      _line(Iconsax.user, 'Driver', t.driverName ?? (t.driverId == null ? 'Open for bids' : 'Assigned')),
      if (t.expectedPay != null) _line(Iconsax.money_4, 'Pay', '₹${t.expectedPay!.round()} per trip'),
    ]));
  }

  Widget _runTile(TemplateRun r) {
    final (label, color) = switch (r.status) {
      'created' => ('Trip created', AppPalette.green),
      'skipped' => ('Skipped', AppPalette.textFaint),
      'cancelled' => ('Trip cancelled', AppPalette.textFaint),
      'failed' => ('Failed', AppPalette.danger),
      'pending' => ('Creating…', AppPalette.blue),
      _ => ('Scheduled', AppPalette.blue),
    };
    final busy = _busyDate == r.date;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.bg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.border)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(formatRunDate(r), style: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: r.status == 'skipped' ? AppPalette.textFaint : AppPalette.textDark,
            decoration: r.status == 'skipped' ? TextDecoration.lineThrough : null)),
          const SizedBox(height: 4),
          Row(children: [
            statusPill(label, color),
            if (r.tripId != null && r.status == 'created') ...[
              const SizedBox(width: 6),
              Flexible(child: Text(r.tripId!, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontSize: 10, color: AppPalette.textGrey))),
            ],
          ]),
          if (r.error != null) ...[
            const SizedBox(height: 4),
            Text(r.error!, style: GoogleFonts.poppins(fontSize: 11, color: AppPalette.danger)),
          ],
        ])),
        if (busy)
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
        else if (r.status == 'skipped')
          TextButton(
            onPressed: _busy ? null : () => _run(() => _service.unskip(_t!.templateId, r.date),
              'Run restored', date: r.date),
            child: Text('Restore', style: GoogleFonts.poppins(
              fontSize: 12, fontWeight: FontWeight.w600, color: AppPalette.primary)))
        else if (r.status != 'pending')
          TextButton(
            onPressed: _busy ? null : () => _skip(r),
            child: Text('Skip', style: GoogleFonts.poppins(
              fontSize: 12, fontWeight: FontWeight.w600, color: AppPalette.danger))),
      ]),
    );
  }

  Widget _line(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 15, color: AppPalette.primary),
      const SizedBox(width: 8),
      SizedBox(width: 60, child: Text(label, style: GoogleFonts.poppins(fontSize: 12, color: AppPalette.textGrey))),
      Expanded(child: Text(value, style: GoogleFonts.poppins(fontSize: 12, color: AppPalette.textDark))),
    ]));

  Widget _card(String title, IconData icon, Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppPalette.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppPalette.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 16, color: AppPalette.primary),
        const SizedBox(width: 8),
        Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppPalette.textDark)),
      ]),
      const SizedBox(height: 12),
      child,
    ]));

  ButtonStyle _outlined(Color c) => OutlinedButton.styleFrom(
    foregroundColor: c, side: BorderSide(color: c),
    padding: const EdgeInsets.symmetric(vertical: 13),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)));
}
