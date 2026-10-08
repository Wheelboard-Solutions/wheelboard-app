import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';

import '../../controllers/Transport/add_trip_controller.dart';
import '../../core/auth/auth_service.dart';
import '../../utils/distance_service.dart';
import '../../utils/location_service.dart';
import '../../models/add_new_trip_model.dart';
import '../../utils/constants.dart';
import '../../utils/app_logger.dart';
import '../../widgets/custom_snackbar.dart';

// ── Design tokens (match Home & Fleet) ────────────────────────────────────────
const _amber    = Color(0xFFF59E0B);
const _bg       = Color(0xFFF9FAFB);
const _card     = Colors.white;
const _textDark = Color(0xFF111827);
const _textGrey = Color(0xFF6B7280);
const _border   = Color(0xFFE5E7EB);

const _noDriver = '__none__';

class EditTripScreen extends StatefulWidget {
  final Trip trip;
  const EditTripScreen({super.key, required this.trip});

  @override
  State<EditTripScreen> createState() => _EditTripScreenState();
}

class _EditTripScreenState extends State<EditTripScreen> {
  final TripController tripController = Get.put(TripController());

  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  final pickupController = TextEditingController();
  final deliveryController = TextEditingController();
  final specialInstructionsController = TextEditingController();
  final payRangeController = TextEditingController();

  final PlacesService placesService =
      PlacesService(apiKey: MapsConstants.googleMapsApiKey);

  List<Suggestion> pickupSuggestions = [];
  List<Suggestion> deliverySuggestions = [];

  DistanceResult? _distanceResult;
  bool _isCalculatingDistance = false;
  bool _isLoadingLocation = false;
  double? _pickupLat, _pickupLng, _deliveryLat, _deliveryLng;

  @override
  void initState() {
    super.initState();
    _prefill();
    _fetchVehicles();
    _fetchDrivers();
  }

  @override
  void dispose() {
    pickupController.dispose();
    deliveryController.dispose();
    specialInstructionsController.dispose();
    payRangeController.dispose();
    super.dispose();
  }

  void _prefill() {
    final t = widget.trip;
    pickupController.text = t.pickupLocation;
    deliveryController.text = t.deliveryLocation;
    specialInstructionsController.text = t.specialInstructions;
    payRangeController.text = t.payRange;
    selectedDate = t.pickupDate;

    if (t.pickupTime.isNotEmpty) {
      final parts = t.pickupTime.split(':');
      if (parts.length >= 2) {
        selectedTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts[1]) ?? 0);
      }
    }
    if (t.vehicleId.isNotEmpty) tripController.selectedVehicle.value = t.vehicleId;
    tripController.selectedDriver.value =
        t.driverId.isNotEmpty ? t.driverId : _noDriver;

    _pickupLat = t.pickupLat;
    _pickupLng = t.pickupLng;
    _deliveryLat = t.latitude;
    _deliveryLng = t.longitude;
    if (t.distance != null && t.distance!.isNotEmpty) {
      _distanceResult = DistanceResult(
        distanceKm: double.tryParse(t.distance!.replaceAll(' km', '')) ?? 0,
        durationMinutes: 0,
        distanceText: t.distance!,
        durationText: '',
        truckDurationText: '');
    }
  }

  Future<void> _fetchVehicles() async {
    await tripController.fetchVehicles(AuthService.to.userId);
    if (widget.trip.vehicleId.isNotEmpty) {
      tripController.selectedVehicle.value = widget.trip.vehicleId;
    }
  }

  Future<void> _fetchDrivers() async {
    await tripController.fetchDrivers(AuthService.to.userId);
    tripController.selectedDriver.value =
        widget.trip.driverId.isNotEmpty ? widget.trip.driverId : _noDriver;
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
          icon: const Icon(Icons.arrow_back_ios_new, color: _amber, size: 20),
          onPressed: () => Get.back()),
        centerTitle: true,
        title: Text('Edit Trip', style: GoogleFonts.poppins(
          fontSize: 17, fontWeight: FontWeight.w600, color: _textDark)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _headerBanner(),
          const SizedBox(height: 14),
          _statusBanner(),
          const SizedBox(height: 14),

          _sectionCard(title: 'Assignment', icon: Iconsax.profile_2user, child: Column(children: [
            _fieldLabel('Vehicle'),
            const SizedBox(height: 6),
            _vehicleDropdown(),
            const SizedBox(height: 16),
            _fieldLabel('Driver (optional)'),
            const SizedBox(height: 6),
            _driverDropdown(),
          ])),
          const SizedBox(height: 14),

          _sectionCard(title: 'Route', icon: Iconsax.routing, child: Column(children: [
            _pickupField(),
            const SizedBox(height: 16),
            _deliveryField(),
            const SizedBox(height: 14),
            _distanceWidget(),
          ])),
          const SizedBox(height: 14),

          _sectionCard(title: 'Schedule', icon: Iconsax.calendar_1, child: Row(children: [
            Expanded(child: _pickerField(
              label: 'Date',
              value: selectedDate == null
                  ? null
                  : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}',
              hint: 'Choose date', icon: Iconsax.calendar, onTap: _pickDate)),
            const SizedBox(width: 12),
            Expanded(child: _pickerField(
              label: 'Time', value: selectedTime?.format(context),
              hint: 'Choose time', icon: Iconsax.clock, onTap: _pickTime)),
          ])),
          const SizedBox(height: 14),

          _sectionCard(title: 'Details', icon: Iconsax.document_text, child: Column(children: [
            _fieldLabel('Special Instructions'),
            const SizedBox(height: 6),
            _input(specialInstructionsController, 'Enter special instructions', maxLines: 3),
            const SizedBox(height: 16),
            _fieldLabel('Pay Range (₹)'),
            const SizedBox(height: 6),
            _input(payRangeController, 'e.g. 5000 - 7000'),
          ])),
          const SizedBox(height: 24),

          Obx(() => SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: tripController.isLoading.value ? null : _save,
              icon: tripController.isLoading.value
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Iconsax.tick_square, size: 18),
              label: Text(tripController.isLoading.value ? 'Saving…' : 'Save Changes',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _amber, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0),
            ),
          )),
        ]),
      ),
    );
  }

  // ── actions ──────────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = selectedDate ?? now;
    final first = (selectedDate != null && selectedDate!.isBefore(now)) ? selectedDate! : now;
    final date = await showDatePicker(
      context: context, initialDate: initial, firstDate: first, lastDate: DateTime(2100));
    if (date != null) setState(() => selectedDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context, initialTime: selectedTime ?? TimeOfDay.now());
    if (time != null) setState(() => selectedTime = time);
  }

  Future<void> _save() async {
    final driverSel = tripController.selectedDriver.value;
    final driverId = (driverSel == null || driverSel == _noDriver) ? '' : driverSel;

    final updated = Trip(
      id: widget.trip.id,
      tripId: widget.trip.tripId,
      userId: AuthService.to.userId,
      vehicleId: tripController.selectedVehicle.value ?? widget.trip.vehicleId,
      driverId: driverId,
      pickupLocation: pickupController.text.trim(),
      deliveryLocation: deliveryController.text.trim(),
      pickupDate: selectedDate,
      pickupTime: selectedTime != null ? _formatTimeOfDay(selectedTime!) : widget.trip.pickupTime,
      specialInstructions: specialInstructionsController.text.trim(),
      payRange: payRangeController.text.trim(),
      tripCode: widget.trip.tripCode,
      tripStatus: widget.trip.tripStatus,
      isScheduledTrip: widget.trip.isScheduledTrip,
      pickupLat: _pickupLat,
      pickupLng: _pickupLng,
      latitude: _deliveryLat,
      longitude: _deliveryLng,
      distance: _distanceResult != null
          ? '${_distanceResult!.distanceKm.toStringAsFixed(2)} km'
          : widget.trip.distance,
    );
    await tripController.updateTrip(updated);
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:00';
  }

  Future<void> _getCurrentLocation(TextEditingController controller) async {
    setState(() => _isLoadingLocation = true);
    try {
      final position = await LocationService.getCurrentPosition();
      final address = position != null
          ? await LocationService.getAddressFromCoordinates(
              position.latitude, position.longitude)
          : null;
      if (address != null && address.isNotEmpty) {
        setState(() {
          controller.text = address;
          if (controller == pickupController) {
            _pickupLat = position?.latitude;
            _pickupLng = position?.longitude;
          }
        });
        _autoCalculateDistance();
      } else {
        SnackBarHelper.error(
          'Could not get current location. Check permissions.',
        );
      }
    } catch (e) {
      SnackBarHelper.error('Failed to get location');
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _calculateDistance() async {
    if (pickupController.text.isEmpty || deliveryController.text.isEmpty) return;
    setState(() => _isCalculatingDistance = true);
    try {
      final result = await distanceService.calculateDistance(
        origin: pickupController.text, destination: deliveryController.text);
      if (mounted) setState(() { _distanceResult = result; _isCalculatingDistance = false; });
    } catch (e) {
      if (mounted) setState(() => _isCalculatingDistance = false);
    }
  }

  void _autoCalculateDistance() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (pickupController.text.isNotEmpty && deliveryController.text.isNotEmpty) {
        _calculateDistance();
      }
    });
  }

  // ── shared UI pieces ───────────────────────────────────────────────────────
  Widget _headerBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_amber, Color(0xFFF97316)]),
        borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Iconsax.edit, color: Colors.white, size: 26)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Edit Trip', style: GoogleFonts.poppins(
            fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          Text('Trip ID: ${widget.trip.tripCode.isNotEmpty ? widget.trip.tripCode : widget.trip.tripId}',
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 12, color: Colors.white.withValues(alpha: 0.85))),
        ])),
      ]),
    );
  }

  Widget _statusBanner() {
    final s = widget.trip.tripStatus.toLowerCase();
    final warn = s.contains('progress') || s.contains('complete');
    final bg = warn ? const Color(0xFFFFFBEB) : const Color(0xFFEFF6FF);
    final fg = warn ? const Color(0xFF92400E) : const Color(0xFF1D4ED8);
    final msg = s.contains('complete')
        ? 'Trip is completed. Only limited changes are recommended.'
        : s.contains('progress')
            ? 'Trip is in progress. Be careful when making changes.'
            : s.contains('draft')
                ? 'Trip is in draft state. You can make any changes.'
                : 'Updates will be saved immediately.';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.2))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(warn ? Iconsax.warning_2 : Iconsax.info_circle, size: 18, color: fg),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Status: ${widget.trip.tripStatus.isEmpty ? "Upcoming" : widget.trip.tripStatus}',
            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
          Text(msg, style: GoogleFonts.poppins(fontSize: 11, color: fg.withValues(alpha: 0.85))),
        ])),
      ]),
    );
  }

  Widget _sectionCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 16, color: _amber),
          const SizedBox(width: 8),
          Text(title, style: GoogleFonts.poppins(
            fontSize: 14, fontWeight: FontWeight.w700, color: _textDark)),
        ]),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }

  Widget _fieldLabel(String label) => Align(
    alignment: Alignment.centerLeft,
    child: Text(label, style: GoogleFonts.poppins(
      fontSize: 12, fontWeight: FontWeight.w500, color: _textGrey)));

  Widget _input(TextEditingController c, String hint,
      {int maxLines = 1, void Function(String)? onChanged}) {
    return TextField(
      controller: c, maxLines: maxLines, onChanged: onChanged,
      style: GoogleFonts.poppins(fontSize: 14, color: _textDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(fontSize: 13, color: _textGrey),
        filled: true, fillColor: _bg, isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: _ob(_border), enabledBorder: _ob(_border), focusedBorder: _ob(_amber, w: 1.5)),
    );
  }

  OutlineInputBorder _ob(Color c, {double w = 1}) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c, width: w));

  InputDecoration _dropdownDecoration() => InputDecoration(
    filled: true, fillColor: _bg, isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: _ob(_border), enabledBorder: _ob(_border), focusedBorder: _ob(_amber, w: 1.5));

  Widget _vehicleDropdown() {
    return Obx(() {
      if (tripController.isVehicleLoading.value) {
        return const Padding(padding: EdgeInsets.symmetric(vertical: 8),
          child: Center(child: CircularProgressIndicator(color: _amber)));
      }
      if (tripController.vehicles.isEmpty) {
        return _emptyHint('No vehicles available.');
      }
      final current = tripController.vehicles.any(
              (v) => v.vehicleId == tripController.selectedVehicle.value)
          ? tripController.selectedVehicle.value
          : null;
      return DropdownButtonFormField<String>(
        initialValue: current,
        isExpanded: true,
        hint: Text('Select vehicle', style: GoogleFonts.poppins(fontSize: 13, color: _textGrey)),
        decoration: _dropdownDecoration(),
        icon: const Icon(Iconsax.arrow_down_1, color: _amber, size: 16),
        items: tripController.vehicles
            .map((v) => DropdownMenuItem(value: v.vehicleId,
                child: Text(v.vehicleModel,
                  style: GoogleFonts.poppins(fontSize: 14, color: _textDark))))
            .toList(),
        onChanged: (val) { if (val != null) tripController.selectedVehicle.value = val; });
    });
  }

  Widget _driverDropdown() {
    return Obx(() {
      if (tripController.isLoading.value && tripController.drivers.isEmpty) {
        return const Padding(padding: EdgeInsets.symmetric(vertical: 8),
          child: Center(child: CircularProgressIndicator(color: _amber)));
      }
      final items = <DropdownMenuItem<String>>[
        DropdownMenuItem(value: _noDriver,
          child: Text('No Driver', style: GoogleFonts.poppins(fontSize: 14, color: _textGrey))),
        ...tripController.drivers.map((d) => DropdownMenuItem(value: d.driverId,
          child: Text(d.fullName, style: GoogleFonts.poppins(fontSize: 14, color: _textDark)))),
      ];
      final sel = tripController.selectedDriver.value;
      final current = items.any((i) => i.value == sel) ? sel : _noDriver;
      return DropdownButtonFormField<String>(
        initialValue: current,
        isExpanded: true,
        decoration: _dropdownDecoration(),
        icon: const Icon(Iconsax.arrow_down_1, color: _amber, size: 16),
        items: items,
        onChanged: (val) { if (val != null) tripController.selectedDriver.value = val; });
    });
  }

  Widget _emptyHint(String text) => Row(children: [
    const Icon(Iconsax.info_circle, size: 16, color: _textGrey),
    const SizedBox(width: 8),
    Expanded(child: Text(text, style: GoogleFonts.poppins(fontSize: 13, color: _textGrey))),
  ]);

  Widget _pickerField({
    required String label, required String? value,
    required String hint, required IconData icon, required VoidCallback onTap,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _fieldLabel(label),
      const SizedBox(height: 6),
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: _bg, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border)),
          child: Row(children: [
            Expanded(child: Text(value ?? hint, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: value == null ? _textGrey : _textDark,
                fontWeight: value == null ? FontWeight.w400 : FontWeight.w600))),
            Icon(icon, size: 18, color: _amber),
          ]),
        ),
      ),
    ]);
  }

  Widget _pickupField() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _fieldLabel('Pickup Location'),
      const SizedBox(height: 6),
      _input(pickupController, 'Enter pickup location', onChanged: (value) async {
        if (value.isNotEmpty) {
          final r = await placesService.fetchSuggestions(value);
          if (mounted) setState(() => pickupSuggestions = r);
        } else {
          setState(() => pickupSuggestions = []);
        }
      }),
      if (pickupSuggestions.isNotEmpty) _suggestionList(pickupSuggestions, isPickup: true),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _isLoadingLocation ? null : () => _getCurrentLocation(pickupController),
          icon: _isLoadingLocation
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Iconsax.gps, size: 16),
          label: Text(_isLoadingLocation ? 'Getting location…' : 'Use Current Location',
            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            foregroundColor: _amber, side: const BorderSide(color: _amber),
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        ),
      ),
    ]);
  }

  Widget _deliveryField() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _fieldLabel('Delivery Location'),
      const SizedBox(height: 6),
      _input(deliveryController, 'Enter delivery location', onChanged: (value) async {
        if (value.isNotEmpty) {
          final r = await placesService.fetchSuggestions(value);
          if (mounted) setState(() => deliverySuggestions = r);
        } else {
          setState(() => deliverySuggestions = []);
        }
      }),
      if (deliverySuggestions.isNotEmpty) _suggestionList(deliverySuggestions, isPickup: false),
    ]);
  }

  Widget _suggestionList(List<Suggestion> list, {required bool isPickup}) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: _card, border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(10)),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: list.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: _border),
        itemBuilder: (context, index) {
          final s = list[index];
          return ListTile(
            dense: true,
            title: Text(s.description, style: GoogleFonts.poppins(fontSize: 13, color: _textDark)),
            subtitle: Text(s.subTitle, style: GoogleFonts.poppins(fontSize: 11, color: _textGrey)),
            onTap: () async {
              setState(() {
                if (isPickup) {
                  pickupController.text = s.description;
                  pickupSuggestions.clear();
                } else {
                  deliveryController.text = s.description;
                  deliverySuggestions.clear();
                }
              });
              try {
                final loc = await placesService.fetchPlaceLocation(s.placeId);
                if (loc != null) {
                  setState(() {
                    if (isPickup) { _pickupLat = loc['lat']; _pickupLng = loc['lng']; }
                    else { _deliveryLat = loc['lat']; _deliveryLng = loc['lng']; }
                  });
                }
              } catch (e) {
                AppLogger.e('Error fetching place location: $e');
              }
              _autoCalculateDistance();
            },
          );
        },
      ),
    );
  }

  Widget _distanceWidget() {
    final hasLocations =
        pickupController.text.isNotEmpty && deliveryController.text.isNotEmpty;
    final hasDistance = _distanceResult != null && _distanceResult!.distanceKm > 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Iconsax.routing, color: _amber, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text('Estimated Distance',
            style: GoogleFonts.poppins(
              fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF92400E)))),
          if (_isCalculatingDistance)
            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
        ]),
        const SizedBox(height: 6),
        Text(
          _isCalculatingDistance ? 'Calculating…'
              : hasDistance ? '${_distanceResult!.distanceKm.toStringAsFixed(2)} km'
              : hasLocations ? 'Tap below to calculate'
              : 'Enter both locations',
          style: GoogleFonts.poppins(
            fontSize: 18, fontWeight: FontWeight.w700,
            color: hasDistance ? _amber : _textGrey)),
        if (hasLocations && !hasDistance) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _calculateDistance,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: _amber, borderRadius: BorderRadius.circular(16)),
              child: Text('Calculate Distance', style: GoogleFonts.poppins(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
          ),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Google Places suggestion model + service
// ─────────────────────────────────────────────────────────────────────────────
class Suggestion {
  final String placeId;
  final String description;
  final String subTitle;

  Suggestion({required this.placeId, required this.description, required this.subTitle});

  factory Suggestion.fromJson(Map<String, dynamic> json) {
    final terms = json['terms'] as List<dynamic>? ?? [];
    return Suggestion(
      placeId: json['place_id'] ?? '',
      description: json['description'] ?? '',
      subTitle: _getTerm(terms, 1));
  }

  static String _getTerm(List<dynamic> terms, int indexFromEnd) {
    if (terms.isEmpty) return '';
    final index = terms.length - 1 - indexFromEnd;
    if (index < 0 || index >= terms.length) return '';
    return terms[index]['value'] ?? '';
  }
}

class PlacesService {
  final String apiKey;
  PlacesService({required this.apiKey});

  Future<List<Suggestion>> fetchSuggestions(String input) async {
    if (input.isEmpty) return [];
    final url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeQueryComponent(input)}'
        '&components=country:in'
        '&key=$apiKey';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final predictions = data['predictions'] as List<dynamic>? ?? [];
        return predictions.map((p) => Suggestion.fromJson(p)).toList();
      }
    } catch (e) {
      AppLogger.d('Places API error: $e');
    }
    return [];
  }

  Future<Map<String, double>?> fetchPlaceLocation(String placeId) async {
    final url =
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=${Uri.encodeQueryComponent(placeId)}'
        '&fields=geometry'
        '&key=$apiKey';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final location = data['result']?['geometry']?['location'];
        if (location != null) {
          return {
            'lat': (location['lat'] as num?)?.toDouble() ?? 0.0,
            'lng': (location['lng'] as num?)?.toDouble() ?? 0.0,
          };
        }
      }
    } catch (e) {
      AppLogger.d('Place Details API error: $e');
    }
    return null;
  }
}
