import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

import '../../../models/trip_template_model.dart';
import '../../../services/trip_template_service.dart';
import '../../../theme/app_palette.dart';
import '../../../widgets/custom_snackbar.dart';
import 'recurring_trip_detail_screen.dart';
import 'recurring_trip_form_screen.dart';

/// Fleet owner's repeat trips: fixed routes that create trips automatically.
class RecurringTripsScreen extends StatefulWidget {
  const RecurringTripsScreen({super.key});

  @override
  State<RecurringTripsScreen> createState() => _RecurringTripsScreenState();
}

class _RecurringTripsScreenState extends State<RecurringTripsScreen> {
  final _service = TripTemplateService();
  List<TripTemplate> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _items.isEmpty;
      _error = null;
    });
    try {
      final items = await _service.list();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _togglePause(TripTemplate t) async {
    try {
      await _service.setPaused(t.templateId, !t.isPaused);
      SnackBarHelper.success(t.isPaused ? 'Repeat trip resumed' : 'Repeat trip paused');
      _load();
    } catch (e) {
      SnackBarHelper.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _open(Widget screen) async {
    await Get.to(() => screen);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.bg,
      appBar: AppBar(
        backgroundColor: AppPalette.card,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppPalette.primary, size: 20),
          onPressed: () => Get.back()),
        centerTitle: true,
        title: Text('Repeat Trips', style: GoogleFonts.poppins(
          fontSize: 17, fontWeight: FontWeight.w600, color: AppPalette.textDark)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppPalette.primary,
        foregroundColor: Colors.white,
        onPressed: () => _open(const RecurringTripFormScreen()),
        icon: const Icon(Iconsax.add),
        label: Text('New', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppPalette.primary))
          : RefreshIndicator(
              color: AppPalette.primary,
              onRefresh: _load,
              child: _error != null
                  ? _message(Iconsax.warning_2, _error!, retry: true)
                  : _items.isEmpty
                      ? _message(Iconsax.repeat,
                          'No repeat trips yet.\nSet up a fixed route once and trips are created for you every run.')
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (_, i) => _tile(_items[i]),
                        ),
            ),
    );
  }

  Widget _message(IconData icon, String text, {bool retry = false}) {
    return ListView(children: [
      const SizedBox(height: 120),
      Icon(icon, size: 40, color: AppPalette.textFaint),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(text, textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 13, color: AppPalette.textGrey))),
      if (retry) Center(child: TextButton(onPressed: _load, child: const Text('Retry'))),
    ]);
  }

  Widget _tile(TripTemplate t) {
    final next = t.upcoming.where((r) => r.status != 'skipped' && r.status != 'cancelled').firstOrNull;
    final failed = t.upcoming.where((r) => r.status == 'failed').length;
    return GestureDetector(
      onTap: () => _open(RecurringTripDetailScreen(templateId: t.templateId)),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppPalette.card, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppPalette.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppPalette.textDark))),
            statusPill(t.isPaused ? 'Paused' : 'Active', t.isPaused ? AppPalette.amber : AppPalette.green),
          ]),
          const SizedBox(height: 6),
          Text('${t.start.address} → ${t.end.address}', maxLines: 2, overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(fontSize: 12, color: AppPalette.textGrey)),
          const SizedBox(height: 10),
          Wrap(spacing: 14, runSpacing: 6, children: [
            _meta(Iconsax.repeat, '${t.repeatLabel} · ${t.startTime}'),
            if (t.vehicleNumber != null) _meta(Iconsax.truck, t.vehicleNumber!),
            if (t.driverName != null) _meta(Iconsax.user, t.driverName!),
          ]),
          const Divider(color: AppPalette.border, height: 22),
          Row(children: [
            Expanded(child: Text(
              t.isPaused ? 'Paused, no new trips'
                  : next == null ? 'No upcoming runs'
                  : 'Next: ${formatRunDate(next)}',
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppPalette.textDark))),
            if (failed > 0) ...[
              const Icon(Iconsax.warning_2, size: 14, color: AppPalette.danger),
              const SizedBox(width: 4),
              Text('$failed failed', style: GoogleFonts.poppins(fontSize: 11, color: AppPalette.danger)),
              const SizedBox(width: 8),
            ],
            GestureDetector(
              onTap: () => _togglePause(t),
              child: Text(t.isPaused ? 'Resume' : 'Pause', style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w700, color: AppPalette.primary))),
          ]),
        ]),
      ),
    );
  }

  Widget _meta(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 14, color: AppPalette.textGrey),
    const SizedBox(width: 4),
    Text(text, style: GoogleFonts.poppins(fontSize: 11, color: AppPalette.textMid)),
  ]);
}

/// Small coloured status label shared by the repeat-trip screens.
Widget statusPill(String label, Color color) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
  child: Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: color)));

const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Tue 14 Oct, 06:30" in device-local time.
String formatRunDate(TemplateRun r) {
  final d = r.startsAt ?? DateTime.tryParse(r.date);
  if (d == null) return r.date;
  final hm = r.startsAt == null ? ''
      : ', ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  return '${_weekdayNames[d.weekday - 1]} ${d.day} ${_monthNames[d.month - 1]}$hm';
}
