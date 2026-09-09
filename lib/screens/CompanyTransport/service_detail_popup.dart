import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/Transport/company_booking_controller.dart';
import '../../controllers/Transport/fleet_controller.dart';
import '../../controllers/Transport/service_controller.dart';
import '../../models/service_model.dart';
import '../../models/get_vehicle_model.dart';
import 'package:wheelboard/core/auth/auth_service.dart';
import '../../widgets/custom_snackbar.dart';
import 'company_booking_detail_screen.dart';

class ServiceDetailsPopup extends StatefulWidget {
  const ServiceDetailsPopup({super.key, required this.service});

  final ServiceModel service;

  @override
  State<ServiceDetailsPopup> createState() => _ServiceDetailsPopupState();
}

class _ServiceDetailsPopupState extends State<ServiceDetailsPopup> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _dateController;
  late final TextEditingController _timeController;
  late final TextEditingController _vehicleController;
  late final TextEditingController _locationController;
  late final TextEditingController _descriptionController;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  // Vehicle dropdown state
  String? _selectedVehicleId;
  bool _isManualEntry = false;
  late final DriverController _fleetController;

  /// Where the Service Location field's contents came from, so the form can say
  /// so instead of leaving the company guessing whose address they are looking
  /// at. Flips to false the moment they type over it.
  bool _locationFromService = false;
  bool _fetchingLocation = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.service.serviceTitle.isNotEmpty
          ? widget.service.serviceTitle
          : 'Service',
    );
    _dateController = TextEditingController();
    _timeController = TextEditingController();
    _vehicleController = TextEditingController();
    _locationController = TextEditingController(text: _serviceAddress);
    _locationFromService = _locationController.text.isNotEmpty;
    _descriptionController = TextEditingController();

    // Initialize fleet controller and fetch vehicles
    _fleetController = DriverController.shared;
    _loadVehicles();
    _ensureServiceLocation();
  }

  /// The address the provider published for this service.
  ///
  /// `fullAddress` and `location` are the same value from the API; the city is
  /// the last resort, and an empty string means the listing genuinely has no
  /// address rather than that one failed to load.
  String get _serviceAddress {
    final address = (widget.service.location ?? widget.service.fullAddress).trim();
    if (address.isNotEmpty) return address;
    return widget.service.city.trim();
  }

  /// Fill Service Location from the service being assigned.
  ///
  /// The provider already gave Wheelboard this address when they published the
  /// listing, so making the company retype it is asking for data we hold — and
  /// whatever they type is where the provider is dispatched to. The popup is
  /// normally opened from the service detail screen, which has loaded the full
  /// listing; this covers the case where it was opened from a summary that
  /// carried no address, by fetching the listing once.
  ///
  /// Only ever fills a blank field: a company edit is never overwritten.
  Future<void> _ensureServiceLocation() async {
    if (_locationController.text.trim().isNotEmpty) return;

    final serviceId = widget.service.serviceId;
    if (serviceId.isEmpty) return;

    setState(() => _fetchingLocation = true);
    try {
      final controller = Get.isRegistered<ServiceController>()
          ? Get.find<ServiceController>()
          : Get.put(ServiceController());
      await controller.fetchServiceDetail(serviceId);
      final detail = controller.getServiceById(serviceId) ??
          controller.selectedService.value;
      final address = ((detail?.location ?? detail?.fullAddress ?? '').trim())
          .isNotEmpty
          ? (detail!.location ?? detail.fullAddress).trim()
          : (detail?.city ?? '').trim();

      if (!mounted) return;
      setState(() {
        // Re-checked after the await: the company may have typed while it was
        // in flight, and their answer wins.
        if (address.isNotEmpty && _locationController.text.trim().isEmpty) {
          _locationController.text = address;
          _locationFromService = true;
        }
        _fetchingLocation = false;
      });
    } catch (_) {
      // The field stays empty and required — the company can still type one.
      if (mounted) setState(() => _fetchingLocation = false);
    }
  }

  Future<void> _loadVehicles() async {
    final authService = AuthService.to;
    final userId = authService.currentUserId;
    final token = authService.currentToken;

    if (userId.isNotEmpty && token.isNotEmpty) {
      await _fleetController.fetchVehicles();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _vehicleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initialDate = _selectedDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = _formatDate(picked);
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _timeController.text = _formatTime(picked);
      });
    }
  }

  String _formatDate(DateTime date) {
    final monthNames = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${monthNames[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _formatTimeForRequest(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDate == null) {
      SnackBarHelper.error('Please select a schedule date.');
      return;
    }

    if (_selectedTime == null) {
      SnackBarHelper.error('Please select a schedule time.');
      return;
    }

    final assignedToUserId = AuthService.to.currentUserId;
    if (assignedToUserId.isEmpty) {
      SnackBarHelper.error('Unable to find user session. Please log in again.');
      return;
    }

    final scheduledDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    // Create the booking via the web-parity contract (POST /services/bookings),
    // then open the booking detail so the company can pay / track it.
    final bookingCtrl = Get.isRegistered<CompanyBookingController>()
        ? Get.find<CompanyBookingController>()
        : Get.put(CompanyBookingController());

    final location = _locationController.text.trim();

    final bookingId = await bookingCtrl.createBooking(
      service: widget.service,
      scheduledDate: scheduledDateTime,
      scheduledTime: _formatTimeForRequest(_selectedTime!),
      location: location,
      paymentMethod: 'Online',
      vehicleNumber: _vehicleController.text.trim(),
      description: _descriptionController.text.trim(),
    );

    if (!mounted) return;

    if (bookingId != null) {
      Get.back(); // close popup
      Get.to(() => CompanyBookingDetailScreen(bookingId: bookingId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingCtrl = Get.put(CompanyBookingController());

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.event_note, color: Color(0xFFF36969)),
                      SizedBox(width: 8),
                      Text(
                        "Service Details",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text("Service Title"),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  readOnly: true,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text("Service Date"),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _dateController,
                  readOnly: true,
                  onTap: _pickDate,
                  decoration: InputDecoration(
                    hintText: "Select Service Date",
                    suffixIcon: const Icon(Icons.calendar_month),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (_) {
                    if (_selectedDate == null) {
                      return 'Please pick a date';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const Text("Service Time"),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _timeController,
                  readOnly: true,
                  onTap: _pickTime,
                  decoration: InputDecoration(
                    hintText: "Select Service Time",
                    suffixIcon: const Icon(Icons.access_time),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (_) {
                    if (_selectedTime == null) {
                      return 'Please pick a time';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const Text("Vehicle Number"),
                const SizedBox(height: 8),

                // Vehicle Dropdown or Manual Entry Toggle
                Obx(() {
                  final vehicles = _fleetController.vehicles;
                  final isLoading = _fleetController.isVehicleLoading.value;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Toggle between dropdown and manual entry
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _isManualEntry = false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: !_isManualEntry
                                      ? const Color(0xFFF36969).withValues(alpha: 0.1)
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: !_isManualEntry
                                        ? const Color(0xFFF36969)
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    'Select Vehicle',
                                    style: TextStyle(
                                      color: !_isManualEntry
                                          ? const Color(0xFFF36969)
                                          : Colors.grey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _isManualEntry = true;
                                _selectedVehicleId = null;
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _isManualEntry
                                      ? const Color(0xFFF36969).withValues(alpha: 0.1)
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _isManualEntry
                                        ? const Color(0xFFF36969)
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    'Manual Entry',
                                    style: TextStyle(
                                      color: _isManualEntry
                                          ? const Color(0xFFF36969)
                                          : Colors.grey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Show dropdown or text field based on toggle
                      if (!_isManualEntry) ...[
                        if (isLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        else if (vehicles.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Text(
                                'No vehicles found. Use manual entry.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        else
                          DropdownButtonFormField<String>(
                            initialValue: _selectedVehicleId,
                            decoration: InputDecoration(
                              hintText: 'Select a vehicle',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            items: vehicles.map((Vehicle vehicle) {
                              final displayText =
                                  vehicle.vehicleNumber.isNotEmpty
                                  ? '${vehicle.vehicleNumber} - ${vehicle.vehicleType}'
                                  : vehicle.vehicleType;
                              return DropdownMenuItem<String>(
                                value: vehicle.vehicleId,
                                child: Text(
                                  displayText,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (String? value) {
                              setState(() {
                                _selectedVehicleId = value;
                                // Update text controller with selected vehicle number
                                final selectedVehicle = vehicles
                                    .firstWhereOrNull(
                                      (v) => v.vehicleId == value,
                                    );
                                if (selectedVehicle != null) {
                                  _vehicleController.text =
                                      selectedVehicle.vehicleNumber;
                                }
                              });
                            },
                            validator: (value) {
                              if (!_isManualEntry &&
                                  (value == null || value.isEmpty)) {
                                return 'Please select a vehicle';
                              }
                              return null;
                            },
                          ),
                      ] else ...[
                        // Manual entry text field
                        TextFormField(
                          controller: _vehicleController,
                          decoration: InputDecoration(
                            hintText: 'Enter Vehicle Number (e.g., MH12AB1234)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          textCapitalization: TextCapitalization.characters,
                          validator: (value) {
                            if (_isManualEntry &&
                                (value == null || value.trim().isEmpty)) {
                              return 'Vehicle number is required';
                            }
                            return null;
                          },
                        ),
                      ],
                    ],
                  );
                }),
                const SizedBox(height: 16),
                const Text(
                  "Service Location",
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _locationController,
                  onChanged: (_) {
                    // Typed over: it is the company's address now, not the
                    // provider's, and the note below must stop claiming
                    // otherwise.
                    if (_locationFromService) {
                      setState(() => _locationFromService = false);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: _fetchingLocation
                        ? "Fetching the service's address…"
                        : "e.g. Workshop, Highway milestone, etc.",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: _fetchingLocation
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter the location for the service'
                      : null,
                ),
                const SizedBox(height: 6),
                Text(
                  _locationFromService
                      ? 'Filled in from ${widget.service.businessName.isNotEmpty ? widget.service.businessName : "the provider"}\'s listed address. Change it if the service is needed elsewhere.'
                      : 'This provider has not listed an address, so enter where the service is needed.',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Service Description",
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: "Details about the service request...",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter description'
                      : null,
                ),
                const SizedBox(height: 16),
                // Payment Information (matches web ServiceAssignmentModal — the
                // payment-method toggle was replaced by this notice; payment is
                // collected after the provider completes the service).
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(Icons.info_outline,
                          size: 18, color: Color(0xFFB45309)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payment Information',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF92400E),
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Payment will be collected after service completion. The provider will confirm the final amount.',
                              style: TextStyle(
                                color: Color(0xFFB45309),
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Obx(() {
                  final isAssigning = bookingCtrl.isProcessing.value;
                  return SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isAssigning ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF36969),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isAssigning
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              "Save Details",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
