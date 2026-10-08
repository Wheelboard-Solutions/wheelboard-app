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
const _primary  = Color(0xFFF36969);
const _bg       = Color(0xFFF9FAFB);
const _card     = Colors.white;
const _textDark = Color(0xFF111827);
const _textGrey = Color(0xFF6B7280);
const _border   = Color(0xFFE5E7EB);
const _purple   = Color(0xFF8B5CF6);

class ScheduleTripScreen extends StatefulWidget {
  const ScheduleTripScreen({super.key});

  @override
  State<ScheduleTripScreen> createState() => _ScheduleTripScreenState();
}

class _ScheduleTripScreenState extends State<ScheduleTripScreen> {
  final TripController tripController = Get.put(TripController());

  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  final pickupController = TextEditingController();
  final deliveryController = TextEditingController();
  final specialInstructionsController = TextEditingController();

  final PlacesService placesService =
      PlacesService(apiKey: MapsConstants.googleMapsApiKey);

  List<Suggestion> pickupSuggestions = [];
  List<Suggestion> deliverySuggestions = [];

  DistanceResult? _distanceResult;
  bool _isCalculatingDistance = false;
  bool _isLoadingLocation = false;
  double? _pickupLat, _pickupLng;
  double? _deliveryLat, _deliveryLng;

  @override
  void initState() {
    super.initState();
    _fetchDrivers();
    _fetchVehicles();
  }

  @override
  void dispose() {
    pickupController.dispose();
    deliveryController.dispose();
    specialInstructionsController.dispose();
    super.dispose();
  }

  Future<void> _fetchDrivers() async =>
      tripController.fetchDrivers(AuthService.to.userId);
  Future<void> _fetchVehicles() async =>
      tripController.fetchVehicles(AuthService.to.userId);

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
        title: Text('Schedule a Trip', style: GoogleFonts.poppins(
          fontSize: 17, fontWeight: FontWeight.w600, color: _textDark)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _headerBanner(),
          const SizedBox(height: 16),

          _sectionCard(title: 'Assignment', icon: Iconsax.profile_2user, child: Column(children: [
            _fieldLabel('Vehicle'),
            const SizedBox(height: 6),
            _vehicleDropdown(),
            const SizedBox(height: 16),
            _fieldLabel('Driver'),
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
          ])),
          const SizedBox(height: 24),

          Obx(() => SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: tripController.isLoading.value ? null : _scheduleTrip,
              icon: tripController.isLoading.value
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Iconsax.calendar_tick, size: 18),
              label: Text(tripController.isLoading.value ? 'Scheduling…' : 'Schedule Trip',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary, foregroundColor: Colors.white,
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
    final date = await showDatePicker(
      context: context, initialDate: DateTime.now(),
      firstDate: DateTime.now(), lastDate: DateTime(2100));
    if (date != null) setState(() => selectedDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time != null) setState(() => selectedTime = time);
  }

  void _err(String msg) => SnackBarHelper.error(msg);

  Future<void> _scheduleTrip() async {
    final userId = AuthService.to.userId;

    if ((tripController.selectedVehicle.value ?? '').isEmpty) {
      return _err('Please select a vehicle');
    }
    if ((tripController.selectedDriver.value ?? '').isEmpty) {
      return _err('Please select a driver');
    }
    if (pickupController.text.trim().isEmpty) return _err('Please enter a pickup location');
    if (deliveryController.text.trim().isEmpty) return _err('Please enter a delivery location');
    if (selectedDate == null) return _err('Please select a pickup date');
    if (selectedTime == null) return _err('Please select a pickup time');
    if (userId.isEmpty) {
      SnackBarHelper.error('User not logged in');
      return;
    }

    final trip = Trip(
      tripId: '',
      userId: userId,
      vehicleId: tripController.selectedVehicle.value ?? '',
      driverId: tripController.selectedDriver.value ?? '',
      pickupLocation: pickupController.text,
      deliveryLocation: deliveryController.text,
      pickupDate: selectedDate,
      pickupTime: selectedTime != null ? _formatTimeOfDay(selectedTime!) : '00:00:00',
      specialInstructions: specialInstructionsController.text.trim(),
      payRange: '',
      tripCode: 'TRIP-${DateTime.now().millisecondsSinceEpoch}',
      tripStatus: 'Pending',
      isScheduledTrip: true,
      pickupLat: _pickupLat,
      pickupLng: _pickupLng,
      latitude: _deliveryLat,
      longitude: _deliveryLng,
      distance: _distanceResult != null
          ? '${_distanceResult!.distanceKm.toStringAsFixed(2)} km'
          : '',
    );
    await tripController.addTrip(trip);
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
            _pickupLat = position!.latitude;
            _pickupLng = position.longitude;
          } else {
            _deliveryLat = position!.latitude;
            _deliveryLng = position.longitude;
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
      // Prefer the exact resolved coordinates (from a tapped suggestion or
      // "Use Current Location") over the free-text address whenever they're
      // known. Google's Distance Matrix API re-geocodes address text
      // independently, which can resolve to a slightly different point than
      // the coordinates that actually get saved/routed by the backend —
      // that mismatch is what causes the live estimate here to disagree with
      // the distance shown later on Trip Details.
      final origin = (_pickupLat != null && _pickupLng != null)
          ? '$_pickupLat,$_pickupLng'
          : pickupController.text;
      final destination = (_deliveryLat != null && _deliveryLng != null)
          ? '$_deliveryLat,$_deliveryLng'
          : deliveryController.text;
      final result = await distanceService.calculateDistance(
        origin: origin, destination: destination);
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
        gradient: const LinearGradient(colors: [_purple, Color(0xFF7C3AED)]),
        borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Iconsax.calendar_1, color: Colors.white, size: 26)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Schedule a Trip', style: GoogleFonts.poppins(
            fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          Text('Pre-assign a driver and share the live navigation link.',
            style: GoogleFonts.poppins(
              fontSize: 12, color: Colors.white.withValues(alpha: 0.85))),
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
          Icon(icon, size: 16, color: _primary),
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
      {int maxLines = 1, TextInputType keyboard = TextInputType.text, void Function(String)? onChanged}) {
    return TextField(
      controller: c, maxLines: maxLines, keyboardType: keyboard, onChanged: onChanged,
      style: GoogleFonts.poppins(fontSize: 14, color: _textDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(fontSize: 13, color: _textGrey),
        filled: true, fillColor: _bg, isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: _ob(_border), enabledBorder: _ob(_border), focusedBorder: _ob(_primary, w: 1.5)),
    );
  }

  OutlineInputBorder _ob(Color c, {double w = 1}) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c, width: w));

  Widget _vehicleDropdown() {
    return Obx(() {
      if (tripController.isVehicleLoading.value) {
        return const Padding(padding: EdgeInsets.symmetric(vertical: 8),
          child: Center(child: CircularProgressIndicator(color: _primary)));
      }
      if (tripController.vehicles.isEmpty) {
        return _emptyHint('No vehicles available. Add a vehicle first.');
      }
      return DropdownButtonFormField<String>(
        initialValue: tripController.selectedVehicle.value,
        isExpanded: true,
        hint: Text('Select vehicle', style: GoogleFonts.poppins(fontSize: 13, color: _textGrey)),
        decoration: _dropdownDecoration(),
        icon: const Icon(Iconsax.arrow_down_1, color: _primary, size: 16),
        items: tripController.vehicles
            .map((v) => DropdownMenuItem(value: v.vehicleId,
                child: Text(v.vehicleModel,
                  style: GoogleFonts.poppins(fontSize: 14, color: _textDark))))
            .toList(),
        onChanged: (val) => tripController.selectedVehicle.value = val);
    });
  }

  Widget _driverDropdown() {
    return Obx(() {
      if (tripController.isLoading.value && tripController.drivers.isEmpty) {
        return const Padding(padding: EdgeInsets.symmetric(vertical: 8),
          child: Center(child: CircularProgressIndicator(color: _primary)));
      }
      if (tripController.drivers.isEmpty) {
        return _emptyHint('No drivers available. Add a driver first.');
      }
      return DropdownButtonFormField<String>(
        initialValue: tripController.selectedDriver.value,
        isExpanded: true,
        hint: Text('Select driver', style: GoogleFonts.poppins(fontSize: 13, color: _textGrey)),
        decoration: _dropdownDecoration(),
        icon: const Icon(Iconsax.arrow_down_1, color: _primary, size: 16),
        items: tripController.drivers
            .map((d) => DropdownMenuItem(value: d.driverId,
                child: Text(d.fullName,
                  style: GoogleFonts.poppins(fontSize: 14, color: _textDark))))
            .toList(),
        onChanged: (val) => tripController.selectedDriver.value = val);
    });
  }

  InputDecoration _dropdownDecoration() => InputDecoration(
    filled: true, fillColor: _bg, isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: _ob(_border), enabledBorder: _ob(_border), focusedBorder: _ob(_primary, w: 1.5));

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
            Icon(icon, size: 18, color: _primary),
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
          try {
            final r = await placesService.fetchSuggestions(value);
            if (mounted) setState(() => pickupSuggestions = r);
          } catch (_) {}
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
            foregroundColor: _primary, side: const BorderSide(color: _primary),
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
          try {
            final r = await placesService.fetchSuggestions(value);
            if (mounted) setState(() => deliverySuggestions = r);
          } catch (_) {}
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
                if (isPickup) {
                  setState(() { _pickupLat = loc['lat']; _pickupLng = loc['lng']; });
                } else {
                  setState(() { _deliveryLat = loc['lat']; _deliveryLng = loc['lng']; });
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
          const Icon(Iconsax.routing, color: Color(0xFFF59E0B), size: 18),
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
            color: hasDistance ? const Color(0xFFF59E0B) : _textGrey)),
        if (hasDistance && _distanceResult!.durationMinutes > 0) ...[
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Iconsax.truck, size: 14, color: Color(0xFF0288D1)),
            const SizedBox(width: 6),
            Text('Truck travel: ${_distanceResult!.truckDurationText}',
              style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF0288D1))),
          ]),
        ],
        if (hasLocations && !hasDistance) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _calculateDistance,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(16)),
              child: Text('Calculate Distance', style: GoogleFonts.poppins(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
          ),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Google Places suggestion model + service (unchanged logic)
// ─────────────────────────────────────────────────────────────────────────────
class Suggestion {
  final String placeId;
  final String description;
  final String sector;
  final String city;
  final String state;
  final String country;
  final String subTitle;

  Suggestion({
    required this.placeId,
    required this.description,
    required this.sector,
    required this.city,
    required this.state,
    required this.country,
    required this.subTitle,
  });

  factory Suggestion.fromPrediction(Map<String, dynamic> p) {
    final terms = (p['terms'] as List<dynamic>?) ?? [];
    final sector = _getTerm(terms, 4);
    final city = _getTerm(terms, 3);
    final state = _getTerm(terms, 2);
    final country = _getTerm(terms, 1);

    final parts = [
      if (sector.isNotEmpty) sector,
      if (city.isNotEmpty) city,
      if (state.isNotEmpty) state,
    ];
    final subTitle =
        (parts.join(', ') + (country.isNotEmpty ? ', $country' : '')).trim();

    return Suggestion(
      placeId: p['place_id'] as String? ?? '',
      description: (p['description'] as String? ?? '').trim(),
      sector: sector,
      city: city,
      state: state,
      country: country,
      subTitle: subTitle,
    );
  }

  static String _getTerm(List<dynamic> terms, int indexFromEnd) {
    final index = terms.length - indexFromEnd;
    if (index >= 0 && index < terms.length) {
      final val = terms[index];
      if (val is Map && val['value'] != null) return val['value'] as String;
    }
    return '';
  }
}

class PlacesService {
  final String apiKey;
  final http.Client client;

  PlacesService({required this.apiKey, http.Client? client})
      : client = client ?? http.Client();

  Future<List<Suggestion>> fetchSuggestions(String input) async {
    final encoded = Uri.encodeQueryComponent(input);
    final url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=$encoded'
        '&types=establishment|geocode'
        '&language=en'
        '&components=country:in'
        '&key=$apiKey';

    final resp = await client.get(Uri.parse(url));
    if (resp.statusCode != 200) {
      throw Exception('Failed: ${resp.statusCode}');
    }

    final result = json.decode(resp.body) as Map<String, dynamic>;
    final status = result['status'] as String? ?? 'UNKNOWN';

    if (status == 'OK') {
      final preds = result['predictions'] as List<dynamic>;
      return preds
          .map((p) => Suggestion.fromPrediction(p as Map<String, dynamic>))
          .toList();
    } else if (status == 'ZERO_RESULTS') {
      return [];
    } else {
      throw Exception(result['error_message'] ?? 'Places API error: $status');
    }
  }

  Future<Map<String, double>> fetchPlaceLocation(String placeId) async {
    final url =
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=${Uri.encodeQueryComponent(placeId)}'
        '&fields=geometry'
        '&key=$apiKey';

    final resp = await client.get(Uri.parse(url));
    if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
    final body = json.decode(resp.body) as Map<String, dynamic>;
    final status = body['status'] as String?;
    if (status == 'OK') {
      final loc =
          body['result']['geometry']['location'] as Map<String, dynamic>;
      return {
        'lat': (loc['lat'] as num).toDouble(),
        'lng': (loc['lng'] as num).toDouble(),
      };
    } else {
      throw Exception(body['error_message'] ?? 'Details error: $status');
    }
  }
}
