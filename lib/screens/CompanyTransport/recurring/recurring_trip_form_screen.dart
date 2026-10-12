import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

import '../../../controllers/Transport/add_trip_controller.dart';
import '../../../core/auth/auth_service.dart';
import '../../../models/trip_template_model.dart';
import '../../../services/trip_template_service.dart';
import '../../../theme/app_palette.dart';
import '../../../utils/app_logger.dart';
import '../../../utils/constants.dart';
import '../../../widgets/custom_snackbar.dart';
import '../newtripscreen.dart' show PlacesService, Suggestion;

const _primary = AppPalette.primary;
const _bg = AppPalette.bg;
const _card = AppPalette.card;
const _textDark = AppPalette.textDark;
const _textGrey = AppPalette.textGrey;
const _border = AppPalette.border;

/// Create or edit a repeat trip. Edits only change trips not yet created.
class RecurringTripFormScreen extends StatefulWidget {
  final TripTemplate? template;
  const RecurringTripFormScreen({super.key, this.template});

  @override
  State<RecurringTripFormScreen> createState() => _RecurringTripFormScreenState();
}

/// One editable location (pickup, drop or a stop) with its own suggestions.
class _Place {
  final TextEditingController ctrl;
  double? lat, lng;
  List<Suggestion> suggestions = [];

  /// Bumped on every keystroke/selection so late autocomplete replies are dropped.
  int query = 0;
  _Place([TripStop? s])
      : ctrl = TextEditingController(text: s?.address ?? ''),
        lat = s?.lat,
        lng = s?.lng;

  bool get resolved => lat != null && lng != null && ctrl.text.trim().isNotEmpty;
  TripStop toStop() => TripStop(address: ctrl.text.trim(), lat: lat!, lng: lng!);
}

class _RecurringTripFormScreenState extends State<RecurringTripFormScreen> {
  final _service = TripTemplateService();
  final TripController _fleet = Get.put(TripController());
  final _places = PlacesService(apiKey: MapsConstants.googleMapsApiKey);

  final _name = TextEditingController();
  final _pay = TextEditingController();
  late final _Place _pickup;
  late final _Place _drop;
  final List<_Place> _stops = [];

  String? _vehicleId;
  String? _driverId;
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  int _durationHours = 8;
  String _repeat = 'daily';
  final Set<int> _weekdays = {1, 2, 3, 4, 5};
  final List<DateTime> _dates = [];
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _saving = false;

  bool get _editing => widget.template != null;

  static const _dayLetters = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  static const _durations = [1, 2, 3, 4, 6, 8, 10, 12, 16, 24, 36, 48];

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    _pickup = _Place(t?.start);
    _drop = _Place(t?.end);
    if (t != null) {
      _name.text = t.name;
      _pay.text = t.expectedPay != null ? t.expectedPay!.round().toString() : '';
      _stops.addAll(t.stops.map(_Place.new));
      _vehicleId = t.vehicleId;
      _driverId = t.driverModel == 'Driver' ? t.driverId : null;
      final hm = t.startTime.split(':');
      _time = TimeOfDay(hour: int.tryParse(hm[0]) ?? 8, minute: int.tryParse(hm.length > 1 ? hm[1] : '0') ?? 0);
      _durationHours = (t.durationMinutes / 60).ceil().clamp(1, 48);
      if (!_durations.contains(_durationHours)) _durationHours = 8;
      _repeat = t.repeatType;
      if (t.weekdays.isNotEmpty) {
        _weekdays
          ..clear()
          ..addAll(t.weekdays);
      }
      _dates.addAll(t.dates.map(DateTime.parse));
      _startDate = DateTime.tryParse(t.startDate) ?? DateTime.now();
      if (_startDate.isBefore(_today)) _startDate = _today;
      _endDate = t.endDate != null ? DateTime.tryParse(t.endDate!) : null;
    }
    final uid = AuthService.to.userId;
    _fleet.fetchVehicles(uid);
    _fleet.fetchDrivers(uid).then((_) {
      // fetchDrivers preselects the first driver for other screens; ignore it here.
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _pay.dispose();
    for (final p in [_pickup, _drop, ..._stops]) {
      p.ctrl.dispose();
    }
    super.dispose();
  }

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  static String _dmy(DateTime d) => '${d.day}/${d.month}/${d.year}';
  static String _hm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // ── save ───────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    String? err;
    if (_name.text.trim().isEmpty) {
      err = 'Give this repeat trip a name';
    } else if (_vehicleId == null) {
      err = 'Select a vehicle';
    } else if (!_pickup.resolved || !_drop.resolved) {
      err = 'Pick pickup and drop locations from the suggestions';
    } else if (_stops.any((s) => !s.resolved)) {
      err = 'Pick each stop from the suggestions, or remove it';
    } else if (_repeat == 'weekdays' && _weekdays.isEmpty) {
      err = 'Choose at least one day';
    } else if (_repeat == 'dates' && _dates.isEmpty) {
      err = 'Add at least one date';
    } else if (_repeat != 'dates' && _endDate != null && _endDate!.isBefore(_startDate)) {
      err = 'End date must be after the start date';
    }
    if (err != null) {
      SnackBarHelper.error(err);
      return;
    }

    final pay = double.tryParse(_pay.text.trim());
    final sortedDates = [..._dates]..sort();
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'vehicleId': _vehicleId,
      'route': {
        'startLocation': _pickup.toStop().toJson(),
        'endLocation': _drop.toStop().toJson(),
        'stops': _stops.map((s) => s.toStop().toJson()).toList(),
      },
      'startTime': _hm(_time),
      'durationMinutes': _durationHours * 60,
      'repeatType': _repeat,
      if (_repeat == 'weekdays') 'weekdays': (_weekdays.toList()..sort()),
      if (_repeat == 'dates') 'dates': sortedDates.map(_ymd).toList(),
      'startDate': _repeat == 'dates' ? _ymd(sortedDates.first) : _ymd(_startDate),
      if (_repeat != 'dates' && _endDate != null) 'endDate': _ymd(_endDate!),
    };
    if (_driverId != null) {
      body['driverId'] = _driverId;
      body['driverModel'] = 'Driver';
    } else if (_editing) {
      body['driverId'] = null;
    }
    if (pay != null) {
      body['expectedPay'] = pay;
    } else if (_editing) {
      body['expectedPay'] = null;
    }
    if (_editing && _repeat != 'dates' && _endDate == null) body['endDate'] = null;

    setState(() => _saving = true);
    try {
      final saved = _editing
          ? await _service.update(widget.template!.templateId, body)
          : await _service.create(body);
      SnackBarHelper.success(_editing
          ? 'Repeat trip updated. Trips already created are unchanged.'
          : 'Repeat trip created');
      Get.back(result: saved);
    } catch (e) {
      SnackBarHelper.error(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _card,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _primary, size: 20),
          onPressed: () => Get.back()),
        centerTitle: true,
        title: Text(_editing ? 'Edit Repeat Trip' : 'New Repeat Trip', style: GoogleFonts.poppins(
          fontSize: 17, fontWeight: FontWeight.w600, color: _textDark)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_editing) ...[
            _banner('Changes apply to upcoming trips that are not created yet.'),
            const SizedBox(height: 14),
          ],
          _section('Name', Iconsax.edit_2, _input(_name, 'e.g. Pune → Mumbai morning run')),
          const SizedBox(height: 14),
          _section('Route', Iconsax.routing, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _placeField('Pickup', _pickup),
            const SizedBox(height: 12),
            for (var i = 0; i < _stops.length; i++) ...[
              _placeField('Stop ${i + 1}', _stops[i], onRemove: () => setState(() {
                _stops.removeAt(i).ctrl.dispose();
              })),
              const SizedBox(height: 12),
            ],
            _placeField('Drop', _drop),
            if (_stops.length < 5)
              TextButton.icon(
                onPressed: () => setState(() => _stops.add(_Place())),
                icon: const Icon(Iconsax.add_circle, size: 18, color: _primary),
                label: Text('Add stop', style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600, color: _primary))),
          ])),
          const SizedBox(height: 14),
          _section('Vehicle & driver', Iconsax.truck, Column(children: [
            _vehicleDropdown(),
            const SizedBox(height: 12),
            _driverDropdown(),
          ])),
          const SizedBox(height: 14),
          _section('Repeats', Iconsax.repeat, _repeatSection()),
          const SizedBox(height: 14),
          _section('Timing', Iconsax.clock, Row(children: [
            Expanded(child: _pickerField('Start time', _time.format(context), Iconsax.clock, _pickTime)),
            const SizedBox(width: 12),
            Expanded(child: _durationDropdown()),
          ])),
          const SizedBox(height: 14),
          _section('Driver pay (₹ per trip)', Iconsax.money_4,
            _input(_pay, 'Optional', keyboard: TextInputType.number)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Iconsax.repeat, size: 18),
              label: Text(_saving ? 'Saving…' : (_editing ? 'Save Changes' : 'Create Repeat Trip'),
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0),
            ),
          ),
          const SizedBox(height: 10),
          Text('Trips are created automatically up to 2 days before each run and '
              'assigned to the same vehicle and driver.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 11, color: _textGrey)),
        ]),
      ),
    );
  }

  Widget _repeatSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        _choice('Daily', 'daily'),
        const SizedBox(width: 8),
        _choice('Weekdays', 'weekdays'),
        const SizedBox(width: 8),
        _choice('Custom dates', 'dates'),
      ]),
      const SizedBox(height: 14),
      if (_repeat == 'weekdays') ...[
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (final d in [1, 2, 3, 4, 5, 6, 0])
            GestureDetector(
              onTap: () => setState(() => _weekdays.contains(d) ? _weekdays.remove(d) : _weekdays.add(d)),
              child: Container(
                width: 38, height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _weekdays.contains(d) ? _primary : _bg,
                  border: Border.all(color: _weekdays.contains(d) ? _primary : _border)),
                child: Text(_dayLetters[d], style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: _weekdays.contains(d) ? Colors.white : _textDark)),
              ),
            ),
        ]),
        const SizedBox(height: 14),
      ],
      if (_repeat == 'dates') ...[
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final d in ([..._dates]..sort()))
            Chip(
              label: Text(_dmy(d), style: GoogleFonts.poppins(fontSize: 12)),
              backgroundColor: AppPalette.primaryLight,
              side: BorderSide.none,
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: () => setState(() => _dates.remove(d))),
          ActionChip(
            avatar: const Icon(Iconsax.add, size: 16, color: _primary),
            label: Text('Add date', style: GoogleFonts.poppins(fontSize: 12, color: _primary)),
            backgroundColor: _card,
            side: const BorderSide(color: _primary),
            onPressed: _addDate),
        ]),
      ] else
        Row(children: [
          Expanded(child: _pickerField('Starts', _dmy(_startDate), Iconsax.calendar, _pickStart)),
          const SizedBox(width: 12),
          Expanded(child: _pickerField('Ends', _endDate == null ? 'No end date' : _dmy(_endDate!),
            Iconsax.calendar_remove, _pickEnd,
            onClear: _endDate == null ? null : () => setState(() => _endDate = null))),
        ]),
    ]);
  }

  Widget _choice(String label, String value) {
    final on = _repeat == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _repeat = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? AppPalette.primaryLight : _bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: on ? _primary : _border, width: on ? 1.5 : 1)),
          child: Text(label, style: GoogleFonts.poppins(
            fontSize: 12, fontWeight: FontWeight.w600, color: on ? _primary : _textDark)),
        ),
      ),
    );
  }

  // ── pickers ────────────────────────────────────────────────────────────────
  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  Future<void> _pickStart() async {
    final d = await showDatePicker(
      context: context, initialDate: _startDate, firstDate: _today, lastDate: DateTime(2100));
    if (d != null) setState(() => _startDate = d);
  }

  Future<void> _pickEnd() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 30)),
      firstDate: _startDate,
      lastDate: DateTime(2100));
    if (d != null) setState(() => _endDate = d);
  }

  Future<void> _addDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dates.isEmpty ? _today : (([..._dates]..sort()).last.add(const Duration(days: 1))),
      firstDate: _today,
      lastDate: DateTime(2100));
    if (d != null && !_dates.any((x) => _ymd(x) == _ymd(d))) setState(() => _dates.add(d));
  }

  // ── pieces ─────────────────────────────────────────────────────────────────
  Widget _placeField(String label, _Place place, {VoidCallback? onRemove}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: _label(label)),
        if (onRemove != null)
          GestureDetector(onTap: onRemove,
            child: const Icon(Iconsax.close_circle, size: 18, color: AppPalette.danger)),
      ]),
      const SizedBox(height: 6),
      _input(place.ctrl, 'Search location',
        suffix: place.resolved ? const Icon(Iconsax.tick_circle, size: 18, color: AppPalette.green) : null,
        autocorrect: false,
        onChanged: (v) async {
          final q = ++place.query;
          place.lat = null;
          place.lng = null;
          if (v.trim().length < 2) {
            setState(() => place.suggestions = []);
            return;
          }
          try {
            final r = await _places.fetchSuggestions(v);
            if (mounted && q == place.query) setState(() => place.suggestions = r);
          } catch (_) {}
        }),
      if (place.suggestions.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            color: _card, border: Border.all(color: _border), borderRadius: BorderRadius.circular(10)),
          child: Column(children: [
            for (final s in place.suggestions)
              ListTile(
                dense: true,
                title: Text(s.description, style: GoogleFonts.poppins(fontSize: 13, color: _textDark)),
                subtitle: s.subTitle.isEmpty ? null
                    : Text(s.subTitle, style: GoogleFonts.poppins(fontSize: 11, color: _textGrey)),
                onTap: () async {
                  final q = ++place.query;
                  setState(() {
                    place.ctrl.text = s.description;
                    place.suggestions = [];
                  });
                  try {
                    final loc = await _places.fetchPlaceLocation(s.placeId);
                    if (mounted && q == place.query) {
                      setState(() { place.lat = loc['lat']; place.lng = loc['lng']; });
                    }
                  } catch (e) {
                    AppLogger.e('Error fetching place location: $e');
                    SnackBarHelper.error('Could not locate that place, try another');
                  }
                },
              ),
          ]),
        ),
    ]);
  }

  Widget _vehicleDropdown() {
    return Obx(() {
      if (_fleet.isVehicleLoading.value) {
        return const Center(child: Padding(padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(color: _primary)));
      }
      final items = _fleet.vehicles
          .map((v) => DropdownMenuItem(value: v.vehicleId, child: Text(
            [v.vehicleNumber, v.vehicleModel].where((s) => s.isNotEmpty).join(' · '),
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(fontSize: 14, color: _textDark))))
          .toList();
      final value = items.any((i) => i.value == _vehicleId) ? _vehicleId : null;
      return _dropdown<String>('Vehicle', value, items, (v) => setState(() => _vehicleId = v),
        hint: items.isEmpty ? 'No vehicles. Add one first.' : 'Select vehicle');
    });
  }

  Widget _driverDropdown() {
    return Obx(() {
      final items = <DropdownMenuItem<String?>>[
        DropdownMenuItem(value: null, child: Text('No driver (open for bids)',
          style: GoogleFonts.poppins(fontSize: 14, color: _textGrey))),
        ..._fleet.drivers.map((d) => DropdownMenuItem(value: d.driverId, child: Text(
          d.fullName, overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(fontSize: 14, color: _textDark)))),
      ];
      final value = _fleet.drivers.any((d) => d.driverId == _driverId) ? _driverId : null;
      return _dropdown<String?>('Driver', value, items, (v) => setState(() => _driverId = v));
    });
  }

  Widget _durationDropdown() => _dropdown<int>(
    'Trip length', _durationHours,
    _durations.map((h) => DropdownMenuItem(value: h, child: Text('$h h',
      style: GoogleFonts.poppins(fontSize: 14, color: _textDark)))).toList(),
    (v) => setState(() => _durationHours = v ?? 8));

  Widget _dropdown<T>(String label, T? value, List<DropdownMenuItem<T>> items,
      ValueChanged<T?> onChanged, {String? hint}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(label),
      const SizedBox(height: 6),
      DropdownButtonFormField<T>(
        key: ValueKey('$label-$value-${items.length}'),
        initialValue: value,
        isExpanded: true,
        hint: hint == null ? null : Text(hint, style: GoogleFonts.poppins(fontSize: 13, color: _textGrey)),
        decoration: _decoration(),
        icon: const Icon(Iconsax.arrow_down_1, color: _primary, size: 16),
        items: items,
        onChanged: onChanged),
    ]);
  }

  Widget _pickerField(String label, String value, IconData icon, VoidCallback onTap,
      {VoidCallback? onClear}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(label),
      const SizedBox(height: 6),
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: _bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
          child: Row(children: [
            Expanded(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: _textDark))),
            if (onClear != null)
              GestureDetector(onTap: onClear, child: const Icon(Icons.close, size: 16, color: _textGrey))
            else
              Icon(icon, size: 18, color: _primary),
          ]),
        ),
      ),
    ]);
  }

  Widget _section(String title, IconData icon, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 16, color: _primary),
          const SizedBox(width: 8),
          Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: _textDark)),
        ]),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }

  Widget _banner(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AppPalette.blueBg, borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      const Icon(Iconsax.info_circle, size: 18, color: AppPalette.blue),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF1E40AF)))),
    ]));

  Widget _label(String t) => Text(t, style: GoogleFonts.poppins(
    fontSize: 12, fontWeight: FontWeight.w500, color: _textGrey));

  Widget _input(TextEditingController c, String hint,
      {TextInputType keyboard = TextInputType.text, Widget? suffix, bool autocorrect = true,
      void Function(String)? onChanged}) {
    return TextField(
      controller: c, keyboardType: keyboard, onChanged: onChanged, autocorrect: autocorrect,
      style: GoogleFonts.poppins(fontSize: 14, color: _textDark),
      decoration: _decoration(hint: hint, suffix: suffix));
  }

  InputDecoration _decoration({String? hint, Widget? suffix}) => InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.poppins(fontSize: 13, color: _textGrey),
    suffixIcon: suffix,
    filled: true, fillColor: _bg, isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: _ob(_border), enabledBorder: _ob(_border), focusedBorder: _ob(_primary, w: 1.5));

  OutlineInputBorder _ob(Color c, {double w = 1}) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c, width: w));
}
