import 'dart:io';
import 'package:dio/dio.dart' as dio;
import 'package:get/get.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_exception.dart';
import '../../models/get_driver_model.dart';
import '../../models/get_vehicle_model.dart';
import '../../services/fleet_payment_service.dart';
import '../../services/profile_service.dart';
import '../../services/verification_service.dart';
import '../../utils/app_logger.dart';
import '../../widgets/custom_snackbar.dart';

/// Outcome of an automatic RC verification attempt, as the Add-Vehicle UI sees
/// it.
///
/// A thin adapter over [VerificationResult] so existing fleet widgets keep
/// working while the verification contract itself lives in one place
/// ([VerificationService]) and matches Web exactly.
class RcVerifyResult {
  final VerificationState state;

  /// User-safe copy authored by the backend. Safe to display verbatim — it
  /// never contains a status code, exception name or provider string.
  final String message;

  /// Normalized vehicle details for auto-fill; only present when verified.
  final VehicleRcData? rc;

  const RcVerifyResult({
    required this.state,
    required this.message,
    this.rc,
  });

  factory RcVerifyResult.from(VerificationResult<VehicleRcData> result) =>
      RcVerifyResult(
        state: result.state,
        message: result.message,
        rc: result.data,
      );

  bool get isVerified => state == VerificationState.verified;

  /// True when automatic verification could not be completed — the user should
  /// be offered manual verification and must never be blocked.
  bool get needsManual => !isVerified;

  /// Distinguishes "we could not reach the provider" from "the RC could not be
  /// matched", so the UI never accuses the user of an invalid RC during an
  /// outage.
  bool get isProviderIssue =>
      state == VerificationState.temporarilyUnavailable;
}

/// One page of a list endpoint, plus whether more remain.
class _PageResult<T> {
  final List<T> items;
  final bool hasMore;

  const _PageResult({required this.items, required this.hasMore});
}

class DriverController extends GetxController {
  /// The single shared fleet controller.
  ///
  /// `Get.put(DriverController())` eagerly CONSTRUCTS a controller before
  /// registering it, and replaces whatever was registered before. Two screens
  /// doing that (the fleet screen and the service-detail sheet) meant a fresh
  /// controller — and therefore a fresh `onInit()` → `refresh()` → a duplicate
  /// round of list requests — every time either was opened, while widgets
  /// holding the previous instance kept observing an orphaned, empty list.
  ///
  /// Reusing the registered instance keeps one source of truth for fleet state
  /// and stops the duplicate fetches.
  static DriverController get shared => Get.isRegistered<DriverController>()
      ? Get.find<DriverController>()
      : Get.put(DriverController());

  // ── State ──────────────────────────────────────────────────────────────────
  final drivers = <Driver>[].obs;
  final vehicles = <Vehicle>[].obs;
  final isLoading = false.obs;
  final isVehicleLoading = false.obs;
  final vehicleLoadError = ''.obs;

  /// Last driver-load failure. Mirrors [vehicleLoadError] so the drivers tab
  /// can offer Retry instead of silently showing "no drivers".
  final driverLoadError = ''.obs;

  /// True once a first load has completed (successfully or not).
  ///
  /// Lets the UI tell "we have not looked yet" apart from "we looked and there
  /// really are none" — the difference between a skeleton and an empty state,
  /// and the reason a user should never see "0 Vehicles" mid-request.
  final hasLoadedVehicles = false.obs;
  final hasLoadedDrivers = false.obs;

  // ── Vehicle detail (kept for backward compat with vehicle_detail_screen) ──
  final vehicleDetails = Rxn<Map<String, dynamic>>();
  final isVehicleDetailsLoading = false.obs;

  // ── Razorpay — fleet payment service instances ─────────────────────────────
  // Each is created on-demand when a 402 is received and disposed after use.
  FleetPaymentService? _driverPaymentService;
  FleetPaymentService? _vehiclePaymentService;

  // ── Verification ───────────────────────────────────────────────────────────
  final _verification = VerificationService();

  /// In-flight verification requests, used to collapse duplicates.
  ///
  /// Verification hits a paid, rate-limited external provider, so five rapid
  /// taps must produce ONE request. Holding the future (rather than a bool)
  /// means every caller still receives the same real result.
  Future<RcVerifyResult>? _rcVerifyInFlight;
  Future<VerificationResult<DrivingLicenceData>>? _dlVerifyInFlight;

  // ── List loading ───────────────────────────────────────────────────────────

  /// Rows per page request.
  ///
  /// Deliberately modest: the backend enriches every vehicle with trip metrics
  /// and GPS, so a smaller page means a materially faster first paint on a slow
  /// mobile connection. Later pages arrive as the user scrolls, so a large
  /// fleet costs nothing up front.
  static const int _listPageSize = 30;

  /// The in-flight list loads, used to collapse duplicate refreshes into one
  /// request, and monotonic ids so only the newest load may write state.
  Future<void>? _vehiclesInFlight;
  Future<void>? _driversInFlight;
  Future<void>? _vehiclesMoreInFlight;
  Future<void>? _driversMoreInFlight;
  int _vehiclesRequestId = 0;
  int _driversRequestId = 0;

  /// Highest page currently held in each list.
  int _vehiclesPage = 0;
  int _driversPage = 0;

  /// Whether the server has more rows beyond what is loaded.
  final hasMoreVehicles = false.obs;
  final hasMoreDrivers = false.obs;

  /// A page-append is running. Distinct from [isVehicleLoading], which means a
  /// first load or a refresh — appending must never blank the list.
  final isLoadingMoreVehicles = false.obs;
  final isLoadingMoreDrivers = false.obs;

  /// A failed page-append. Shown as a retryable footer, never as a screen-level
  /// error, because the rows already on screen are still valid.
  final vehicleLoadMoreError = ''.obs;
  final driverLoadMoreError = ''.obs;

  @override
  void onInit() {
    super.onInit();
    refresh();
  }

  @override
  void onClose() {
    _driverPaymentService?.dispose();
    _vehiclePaymentService?.dispose();
    super.onClose();
  }

  /// Reload drivers and vehicles together.
  ///
  /// Returns a future that completes when BOTH have finished, so pull-to-refresh
  /// keeps its indicator up for the real duration of the work instead of
  /// snapping shut immediately. Duplicate calls collapse onto the in-flight
  /// loads rather than issuing a second round of requests.
  @override
  Future<void> refresh() {
    return Future.wait([fetchDrivers(), fetchVehicles()]);
  }

  // ── Drivers ────────────────────────────────────────────────────────────────

  /// Load the company's drivers — same pagination and concurrency rules as
  /// [fetchVehicles], which see for the reasoning.
  Future<void> fetchDrivers() {
    final inFlight = _driversInFlight;
    if (inFlight != null) return inFlight;

    final future = _loadDrivers();
    _driversInFlight = future;
    return future.whenComplete(() => _driversInFlight = null);
  }

  Future<void> _loadDrivers() async {
    final requestId = ++_driversRequestId;
    isLoading.value = true;
    driverLoadError.value = '';

    try {
      final page = await _fetchPage(
        ApiEndpoints.fleet.drivers,
        page: 1,
        parse: Driver.fromJson,
      );

      if (requestId != _driversRequestId) return;
      drivers.value = page.items;
      _driversPage = 1;
      hasMoreDrivers.value = page.hasMore;
    } on dio.DioException catch (e) {
      if (requestId != _driversRequestId) return;
      final msg = e.error is ApiException
          ? (e.error as ApiException).message
          : 'Failed to load drivers';
      driverLoadError.value = msg;
      // Existing drivers are kept — see fetchVehicles.
      AppLogger.e('❌ fetchDrivers: $e');
    } catch (e) {
      if (requestId != _driversRequestId) return;
      driverLoadError.value = 'Failed to load drivers';
      AppLogger.e('❌ fetchDrivers: $e');
    } finally {
      if (requestId == _driversRequestId) {
        isLoading.value = false;
        hasLoadedDrivers.value = true;
      }
    }
  }

  /// Append the next page of drivers — same rules as [loadMoreVehicles].
  Future<void> loadMoreDrivers() {
    final inFlight = _driversMoreInFlight;
    if (inFlight != null) return inFlight;
    if (!hasMoreDrivers.value || isLoading.value) return Future.value();

    final future = _loadMoreDrivers();
    _driversMoreInFlight = future;
    return future.whenComplete(() => _driversMoreInFlight = null);
  }

  Future<void> _loadMoreDrivers() async {
    final requestId = _driversRequestId;
    isLoadingMoreDrivers.value = true;
    driverLoadMoreError.value = '';

    try {
      final next = _driversPage + 1;
      final page = await _fetchPage(
        ApiEndpoints.fleet.drivers,
        page: next,
        parse: Driver.fromJson,
      );

      if (requestId != _driversRequestId) return;

      final seen = drivers.map((d) => d.driverId).toSet();
      drivers.addAll(page.items.where((d) => seen.add(d.driverId)));
      _driversPage = next;
      hasMoreDrivers.value = page.hasMore;
    } catch (e) {
      if (requestId != _driversRequestId) return;
      driverLoadMoreError.value = 'Could not load more drivers.';
      AppLogger.e('❌ loadMoreDrivers: $e');
    } finally {
      isLoadingMoreDrivers.value = false;
    }
  }

  /// Creates a driver.
  ///
  /// If the backend returns 402 (plan limit exceeded):
  ///   - `upgradeRequired` → shows upgrade dialog, navigates to subscriptions.
  ///   - per-driver charge   → opens Razorpay checkout; on payment success the
  ///     create call is retried automatically with the payment proof attached.
  ///
  /// Returns `true` if the driver was created (either directly or after payment).
  /// Returns `false` on error or if payment flow was opened (result arrives async).
  Future<bool> createDriver({
    required String name,
    required String licenseNumber,
    required String dateOfBirth, // ISO-8601
    required String phoneNumber,
    required String vehicleType,
    String description = '',
    String experience = '',
    String status = 'Available',
    String email = '',
    String location = '',
    String address = '',
    String licenseExpiryDate = '',
    String vehicleCategoryDetail = '',
    File? image,
    // Payment proof — populated on the Razorpay-retry path only.
    Map<String, dynamic>? payment,
  }) async {
    try {
      final formData = await _buildDriverFormData(
        name: name,
        licenseNumber: licenseNumber,
        dateOfBirth: dateOfBirth,
        phoneNumber: phoneNumber,
        vehicleType: vehicleType,
        description: description,
        experience: experience,
        status: status,
        email: email,
        location: location,
        address: address,
        licenseExpiryDate: licenseExpiryDate,
        vehicleCategoryDetail: vehicleCategoryDetail,
        image: image,
        payment: payment,
      );

      await ApiClient.instance.upload<dynamic>(
        ApiEndpoints.fleet.addDriver,
        formData: formData,
      );
      SnackBarHelper.success('Driver added successfully');
      await fetchDrivers();
      return true;
    } on dio.DioException catch (e) {
      if (e.response?.statusCode == 402) {
        _handle402Driver(e, {
          'name': name,
          'licenseNumber': licenseNumber,
          'dateOfBirth': dateOfBirth,
          'phoneNumber': phoneNumber,
          'vehicleType': vehicleType,
          'description': description,
          'experience': experience,
          'status': status,
          'email': email,
          'location': location,
          'address': address,
          'licenseExpiryDate': licenseExpiryDate,
          'vehicleCategoryDetail': vehicleCategoryDetail,
          // image cannot be re-passed directly; user would need to re-select.
          // We capture image path to re-attach on retry.
          '_imagePath': image?.path,
        });
        return false; // result arrives asynchronously via Razorpay callbacks
      }
      SnackBarHelper.error(_actionError(e, 'Failed to add driver'));
      AppLogger.e('❌ createDriver: $e');
      return false;
    } catch (e) {
      SnackBarHelper.error('Failed to add driver');
      AppLogger.e('❌ createDriver: $e');
      return false;
    }
  }

  /// Handles a 402 response for driver creation.
  /// Matches web app's `handleSaveDriver` 402 block exactly.
  void _handle402Driver(
    dio.DioException e,
    Map<String, dynamic> originalParams,
  ) {
    final responseData = _extract402Data(e);
    final upgradeRequired =
        responseData['upgradeRequired'] == true ||
        responseData['feeType'] == 'upgrade_required';

    AppLogger.d(
      '[Fleet 402] driver | upgradeRequired=$upgradeRequired | data=$responseData',
    );

    if (upgradeRequired) {
      final limit = (responseData['limit'] as num?)?.toInt() ?? 0;
      showFleetUpgradeLimitDialog(resourceType: 'driver', limit: limit);
      return;
    }

    // Per-driver charge — open Razorpay.
    _driverPaymentService?.dispose();
    _driverPaymentService = FleetPaymentService(
      onPaymentSuccess: (orderId, paymentId, signature) async {
        AppLogger.d('[Fleet] Driver payment success, retrying create…');
        final imagePath = originalParams['_imagePath'] as String?;
        final ok = await createDriver(
          name: originalParams['name'] as String,
          licenseNumber: originalParams['licenseNumber'] as String,
          dateOfBirth: originalParams['dateOfBirth'] as String,
          phoneNumber: originalParams['phoneNumber'] as String,
          vehicleType: originalParams['vehicleType'] as String,
          description: (originalParams['description'] as String?) ?? '',
          experience: (originalParams['experience'] as String?) ?? '',
          status: (originalParams['status'] as String?) ?? 'Available',
          email: (originalParams['email'] as String?) ?? '',
          location: (originalParams['location'] as String?) ?? '',
          address: (originalParams['address'] as String?) ?? '',
          licenseExpiryDate:
              (originalParams['licenseExpiryDate'] as String?) ?? '',
          vehicleCategoryDetail:
              (originalParams['vehicleCategoryDetail'] as String?) ?? '',
          image: imagePath != null ? File(imagePath) : null,
          payment: {
            'orderId': orderId,
            'paymentId': paymentId,
            'signature': signature,
          },
        );
        if (ok) {
          _driverPaymentService?.dispose();
          _driverPaymentService = null;
        }
      },
      onPaymentError: (message) {
        SnackBarHelper.error(message);
        _driverPaymentService?.dispose();
        _driverPaymentService = null;
      },
    );

    _driverPaymentService!.openCheckout(
      orderData: responseData,
      description:
          'Extra Driver Charge — ₹${(responseData['amount'] as num?)?.toStringAsFixed(0) ?? '0'}',
    );
  }

  Future<bool> updateDriver({
    required String driverId,
    required String name,
    required String licenseNumber,
    required String dateOfBirth,
    required String phoneNumber,
    required String vehicleType,
    String description = '',
    String experience = '',
    String status = 'Available',
    String email = '',
    String location = '',
    String address = '',
    String licenseExpiryDate = '',
    String vehicleCategoryDetail = '',
    File? image,
  }) async {
    try {
      final formData = await _buildDriverFormData(
        name: name,
        licenseNumber: licenseNumber,
        dateOfBirth: dateOfBirth,
        phoneNumber: phoneNumber,
        vehicleType: vehicleType,
        description: description,
        experience: experience,
        status: status,
        email: email,
        location: location,
        address: address,
        licenseExpiryDate: licenseExpiryDate,
        vehicleCategoryDetail: vehicleCategoryDetail,
        image: image,
      );
      await ApiClient.instance.upload<dynamic>(
        ApiEndpoints.fleet.updateDriver(driverId),
        formData: formData,
        method: 'PUT',
      );
      SnackBarHelper.success('Driver updated successfully');
      await fetchDrivers();
      return true;
    } on dio.DioException catch (e) {
      SnackBarHelper.error(_actionError(e, 'Failed to update driver'));
      AppLogger.e('❌ updateDriver: $e');
      return false;
    } catch (e) {
      SnackBarHelper.error('Failed to update driver');
      AppLogger.e('❌ updateDriver: $e');
      return false;
    }
  }

  Future<bool> deleteDriver(String driverId, [String? _, String? __]) async {
    try {
      await ApiClient.instance.delete(
        ApiEndpoints.fleet.deleteDriver(driverId),
      );
      drivers.removeWhere((d) => d.driverId == driverId);
      SnackBarHelper.success('Driver removed');
      return true;
    } catch (e) {
      SnackBarHelper.error('Failed to remove driver');
      AppLogger.e('❌ deleteDriver: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> fetchDriverDetail(String driverId) async {
    try {
      final data = await ApiClient.instance.get<Map<String, dynamic>>(
        ApiEndpoints.fleet.driverDetails(driverId),
      );
      return data;
    } catch (e) {
      AppLogger.e('❌ fetchDriverDetail: $e');
      return null;
    }
  }

  Future<bool> updateDriverPerformance(
    String driverId,
    Map<String, dynamic> fields,
  ) async {
    try {
      await ApiClient.instance.put(
        ApiEndpoints.fleet.updateDriver(driverId),
        data: fields,
      );
      SnackBarHelper.success('Performance updated');
      return true;
    } catch (e) {
      SnackBarHelper.error('Failed to update performance');
      return false;
    }
  }

  // ── Vehicles ───────────────────────────────────────────────────────────────

  /// Load the FIRST page of the company's vehicles.
  ///
  /// Only one page is fetched, so the list paints as soon as the first
  /// response lands rather than after the whole fleet has been downloaded.
  /// Further pages arrive through [loadMoreVehicles] as the user scrolls.
  ///
  /// Concurrency: one load at a time, and only the newest may write state.
  /// Two overlapping loads (pull-to-refresh during the initial load, a retry
  /// tap, a re-entered screen) previously resolved in arbitrary order, so a
  /// slower EARLIER response could overwrite a newer, correct one — which
  /// looks exactly like the fleet emptying itself.
  Future<void> fetchVehicles() {
    final inFlight = _vehiclesInFlight;
    if (inFlight != null) return inFlight;

    final future = _loadVehiclesFirstPage();
    _vehiclesInFlight = future;
    return future.whenComplete(() => _vehiclesInFlight = null);
  }

  Future<void> _loadVehiclesFirstPage() async {
    final requestId = ++_vehiclesRequestId;
    isVehicleLoading.value = true;
    vehicleLoadError.value = '';

    try {
      final page = await _fetchPage(
        ApiEndpoints.fleet.vehicles,
        page: 1,
        parse: Vehicle.fromJson,
      );

      // A newer load started while this one was in flight — drop this result
      // rather than letting stale data win.
      if (requestId != _vehiclesRequestId) return;

      vehicles.value = page.items;
      _vehiclesPage = 1;
      hasMoreVehicles.value = page.hasMore;
    } on dio.DioException catch (e) {
      if (requestId != _vehiclesRequestId) return;
      vehicleLoadError.value = e.error is ApiException
          ? (e.error as ApiException).message
          : 'Failed to load vehicles';
      // Existing vehicles are deliberately NOT cleared: a failed refresh must
      // never replace a fleet the user can currently see with an empty list.
      AppLogger.e('❌ fetchVehicles: $e');
    } catch (e) {
      if (requestId != _vehiclesRequestId) return;
      vehicleLoadError.value = 'Failed to load vehicles';
      AppLogger.e('❌ fetchVehicles: $e');
    } finally {
      if (requestId == _vehiclesRequestId) {
        isVehicleLoading.value = false;
        hasLoadedVehicles.value = true;
      }
    }
  }

  /// Append the next page of vehicles.
  ///
  /// Called as the list approaches its end. Silent by design: a failed
  /// load-more must not disturb the rows already on screen, so it surfaces as
  /// a retryable footer rather than an error state or a snackbar.
  ///
  /// Safe to call repeatedly — scroll events fire far faster than the network,
  /// so the in-flight guard is what stops a fling from queuing ten requests.
  Future<void> loadMoreVehicles() {
    final inFlight = _vehiclesMoreInFlight;
    if (inFlight != null) return inFlight;
    if (!hasMoreVehicles.value || isVehicleLoading.value) {
      return Future.value();
    }

    final future = _loadMoreVehicles();
    _vehiclesMoreInFlight = future;
    return future.whenComplete(() => _vehiclesMoreInFlight = null);
  }

  Future<void> _loadMoreVehicles() async {
    final requestId = _vehiclesRequestId;
    isLoadingMoreVehicles.value = true;
    vehicleLoadMoreError.value = '';

    try {
      final next = _vehiclesPage + 1;
      final page = await _fetchPage(
        ApiEndpoints.fleet.vehicles,
        page: next,
        parse: Vehicle.fromJson,
      );

      // A refresh happened while this page was in flight. Appending now would
      // splice page N of the OLD list onto page 1 of the new one.
      if (requestId != _vehiclesRequestId) return;

      // De-duplicated on id: a vehicle created between two page requests
      // shifts every later row down by one, which would otherwise re-deliver a
      // row that is already on screen and crash the list on duplicate keys.
      final seen = vehicles.map((v) => v.vehicleId).toSet();
      vehicles.addAll(
        page.items.where((v) => seen.add(v.vehicleId)),
      );
      _vehiclesPage = next;
      hasMoreVehicles.value = page.hasMore;
    } catch (e) {
      if (requestId != _vehiclesRequestId) return;
      vehicleLoadMoreError.value = 'Could not load more vehicles.';
      AppLogger.e('❌ loadMoreVehicles: $e');
    } finally {
      isLoadingMoreVehicles.value = false;
    }
  }

  /// Read ONE page of a paginated list endpoint.
  ///
  /// Tolerates both the paginated envelope `{data, pagination}` and a bare
  /// array, so the client keeps working across a backend rollout. An
  /// unreadable payload throws rather than yielding an empty list — silently
  /// returning `[]` is how a broken response becomes "you have no vehicles".
  Future<_PageResult<T>> _fetchPage<T>(
    String path, {
    required int page,
    required T Function(Map<String, dynamic>) parse,
    int pageSize = _listPageSize,
  }) async {
    final raw = await ApiClient.instance.get<dynamic>(
      path,
      queryParameters: {'page': page, 'limit': pageSize},
    );

    final List<dynamic> items;
    bool hasMore;

    if (raw is List) {
      // Legacy unpaginated response — everything arrived at once.
      items = raw;
      hasMore = false;
    } else if (raw is Map<String, dynamic> && raw['data'] is List) {
      items = raw['data'] as List;
      final meta = raw['pagination'];
      final totalPages = meta is Map ? meta['totalPages'] : null;
      hasMore = totalPages is int
          ? page < totalPages
          // No usable metadata: a full page implies there may be more.
          : items.length >= pageSize;
    } else {
      throw const FormatException('Unexpected list response');
    }

    // Parsed row by row, so one malformed record cannot take the page down
    // with it. Mapping in a single pass meant one odd row threw, the page was
    // discarded, and a company with real vehicles saw an empty fleet.
    final parsed = <T>[];
    for (final item in items.whereType<Map<String, dynamic>>()) {
      try {
        parsed.add(parse(item));
      } catch (e) {
        AppLogger.e('⚠️ Skipped an unreadable row from $path: $e');
      }
    }

    return _PageResult<T>(items: parsed, hasMore: hasMore);
  }


  /// Creates a vehicle.
  ///
  /// 1:1 with the web `VehicleFormModal`/`handleSaveVehicle`: sends a plain JSON
  /// body matching `CreateVehicleDto` (the backend route has no file
  /// interceptor, so multipart was silently rejected by the strict
  /// `ValidationPipe` — this is why vehicles never actually saved before).
  ///
  /// 402 handling mirrors the web app:
  ///   - `upgradeRequired` → upgrade dialog.
  ///   - per-vehicle charge → Razorpay checkout → retry with payment proof.
  Future<bool> createVehicle({
    required String name,
    required String model,
    required String registrationNumber,
    required int year,
    required String ownership,
    required String category,
    String categoryDetail = '',
    String fuelType = 'Diesel',
    String capacity = '',
    String mileage = '',
    String location = '',
    File? image,
    // Payment proof — populated on the Razorpay-retry path only.
    Map<String, dynamic>? payment,
  }) async {
    try {
      final data = await _buildVehiclePayload(
        name: name,
        model: model,
        registrationNumber: registrationNumber,
        year: year,
        ownership: ownership,
        category: category,
        categoryDetail: categoryDetail,
        fuelType: fuelType,
        capacity: capacity,
        mileage: mileage,
        location: location,
        statusBadge: 'Available',
        image: image,
        payment: payment,
      );
      await ApiClient.instance.post<dynamic>(
        ApiEndpoints.fleet.addVehicle,
        data: data,
      );
      SnackBarHelper.success('Vehicle added successfully');
      await fetchVehicles();
      return true;
    } on dio.DioException catch (e) {
      if (e.response?.statusCode == 402) {
        _handle402Vehicle(e, {
          'name': name,
          'model': model,
          'registrationNumber': registrationNumber,
          'year': year,
          'ownership': ownership,
          'category': category,
          'categoryDetail': categoryDetail,
          'fuelType': fuelType,
          'capacity': capacity,
          'mileage': mileage,
          'location': location,
          '_imagePath': image?.path,
        });
        return false;
      }
      SnackBarHelper.error(_actionError(e, 'Failed to add vehicle'));
      AppLogger.e('❌ createVehicle: $e');
      return false;
    } catch (e) {
      SnackBarHelper.error('Failed to add vehicle');
      AppLogger.e('❌ createVehicle: $e');
      return false;
    }
  }

  /// Handles a 402 response for vehicle creation.
  /// Mirrors web app's `handleSaveVehicle` 402 block exactly.
  void _handle402Vehicle(
    dio.DioException e,
    Map<String, dynamic> originalParams,
  ) {
    final responseData = _extract402Data(e);
    final upgradeRequired =
        responseData['upgradeRequired'] == true ||
        responseData['feeType'] == 'upgrade_required';

    AppLogger.d(
      '[Fleet 402] vehicle | upgradeRequired=$upgradeRequired | data=$responseData',
    );

    if (upgradeRequired) {
      final limit = (responseData['limit'] as num?)?.toInt() ?? 0;
      showFleetUpgradeLimitDialog(resourceType: 'vehicle', limit: limit);
      return;
    }

    // Per-vehicle charge — open Razorpay.
    _vehiclePaymentService?.dispose();
    _vehiclePaymentService = FleetPaymentService(
      onPaymentSuccess: (orderId, paymentId, signature) async {
        AppLogger.d('[Fleet] Vehicle payment success, retrying create…');
        final imagePath = originalParams['_imagePath'] as String?;
        final ok = await createVehicle(
          name: originalParams['name'] as String,
          model: originalParams['model'] as String,
          registrationNumber: originalParams['registrationNumber'] as String,
          year: originalParams['year'] as int,
          ownership: originalParams['ownership'] as String,
          category: originalParams['category'] as String,
          categoryDetail: (originalParams['categoryDetail'] as String?) ?? '',
          fuelType: (originalParams['fuelType'] as String?) ?? 'Diesel',
          capacity: (originalParams['capacity'] as String?) ?? '',
          mileage: (originalParams['mileage'] as String?) ?? '',
          location: (originalParams['location'] as String?) ?? '',
          image: imagePath != null ? File(imagePath) : null,
          payment: {
            'orderId': orderId,
            'paymentId': paymentId,
            'signature': signature,
          },
        );
        if (ok) {
          _vehiclePaymentService?.dispose();
          _vehiclePaymentService = null;
        }
      },
      onPaymentError: (message) {
        SnackBarHelper.error(message);
        _vehiclePaymentService?.dispose();
        _vehiclePaymentService = null;
      },
    );

    _vehiclePaymentService!.openCheckout(
      orderData: responseData,
      description:
          'Extra Vehicle Charge — ₹${(responseData['amount'] as num?)?.toStringAsFixed(0) ?? '0'}',
    );
  }

  Future<bool> updateVehicle({
    required String vehicleId,
    required String name,
    required String model,
    required String registrationNumber,
    required int year,
    required String ownership,
    required String category,
    String categoryDetail = '',
    String fuelType = 'Diesel',
    String capacity = '',
    String mileage = '',
    String location = '',
    String? statusBadge,
    File? image,
  }) async {
    try {
      final data = await _buildVehiclePayload(
        name: name,
        model: model,
        registrationNumber: registrationNumber,
        year: year,
        ownership: ownership,
        category: category,
        categoryDetail: categoryDetail,
        fuelType: fuelType,
        capacity: capacity,
        mileage: mileage,
        location: location,
        statusBadge: statusBadge ?? 'Available',
        image: image,
      );
      await ApiClient.instance.put<dynamic>(
        ApiEndpoints.fleet.updateVehicle(vehicleId),
        data: data,
      );
      SnackBarHelper.success('Vehicle updated successfully');
      await fetchVehicles();
      return true;
    } on dio.DioException catch (e) {
      SnackBarHelper.error(_actionError(e, 'Failed to update vehicle'));
      AppLogger.e('❌ updateVehicle: $e');
      return false;
    } catch (e) {
      SnackBarHelper.error('Failed to update vehicle');
      AppLogger.e('❌ updateVehicle: $e');
      return false;
    }
  }

  Future<bool> deleteVehicle(String vehicleId, [String? _, String? __]) async {
    try {
      await ApiClient.instance.delete(
        ApiEndpoints.fleet.deleteVehicle(vehicleId),
      );
      vehicles.removeWhere((v) => v.vehicleId == vehicleId);
      SnackBarHelper.success('Vehicle removed');
      return true;
    } catch (e) {
      SnackBarHelper.error('Failed to remove vehicle');
      AppLogger.e('❌ deleteVehicle: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> fetchVehicleDetails(
    String vehicleId, [
    String? _,
  ]) async {
    try {
      isVehicleDetailsLoading.value = true;
      final data = await ApiClient.instance.get<Map<String, dynamic>>(
        ApiEndpoints.fleet.vehicleDetails(vehicleId),
      );
      vehicleDetails.value = data;
      return data;
    } catch (e) {
      AppLogger.e('❌ fetchVehicleDetails: $e');
      return null;
    } finally {
      isVehicleDetailsLoading.value = false;
    }
  }

  Future<List<VehicleGpsPoint>> fetchVehicleGpsHistory(
    String vehicleId, {
    int limit = 500,
  }) async {
    try {
      final data = await ApiClient.instance.get<dynamic>(
        ApiEndpoints.fleet.vehicleGpsHistory(vehicleId),
        queryParameters: {'limit': limit},
      );
      final list = data is List ? data : const [];
      return list
          .whereType<Map>()
          .map((item) => VehicleGpsPoint.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      AppLogger.e('❌ fetchVehicleGpsHistory: $e');
      return const [];
    }
  }

  /// RC verification through the backend, which calls the provider server-side.
  ///
  /// The backend answers with the normalized verification contract rather than
  /// throwing, so the UI can render a persistent inline message and offer
  /// manual verification:
  ///   verified                 → normalized vehicle details for auto-fill
  ///   not_verified             → the provider answered and could not match it
  ///   temporarily_unavailable  → timeout / outage / auth / config on our side
  ///
  /// A failure NEVER blocks vehicle creation, and a provider outage is never
  /// reported to the user as an invalid RC.
  ///
  /// Concurrency: only one RC verification runs at a time. Rapid taps on Verify
  /// return the in-flight future instead of starting another backend request
  /// and another paid provider call.
  Future<RcVerifyResult> verifyVehicleRegistration(String regNumber) {
    final inFlight = _rcVerifyInFlight;
    if (inFlight != null) return inFlight;

    final future = _runRcVerification(regNumber);
    _rcVerifyInFlight = future;
    return future.whenComplete(() => _rcVerifyInFlight = null);
  }

  Future<RcVerifyResult> _runRcVerification(String regNumber) async {
    // Cheap local check first, so obviously-unusable input never spends a paid
    // provider call.
    if (!isPlausibleRegistration(regNumber)) {
      return const RcVerifyResult(
        state: VerificationState.notVerified,
        message:
            'Enter a valid registration number, for example GJ07AH4682.',
      );
    }

    final result = await _verification.verifyRegistration(regNumber);
    return RcVerifyResult.from(result);
  }

  /// Read a saved vehicle's stored RC state. Never calls the provider — this is
  /// what Vehicle Details uses on open, so reopening a screen costs a database
  /// read rather than provider quota.
  Future<RcVerifyResult> fetchVehicleRcStatus(String vehicleId) async {
    final result = await _verification.getVehicleRcStatus(vehicleId);
    return RcVerifyResult.from(result);
  }

  /// Verify a saved vehicle's RC and persist the result.
  Future<RcVerifyResult> verifySavedVehicleRc(String vehicleId) async {
    final result = await _verification.verifyVehicleRc(vehicleId);
    return RcVerifyResult.from(result);
  }

  /// Manual RC fallback — moves the vehicle to Pending for admin review.
  Future<RcVerifyResult> submitVehicleRcManually(
    String vehicleId, {
    required String documentUrl,
    String? notes,
  }) async {
    final result = await _verification.submitVehicleRcManually(
      vehicleId,
      documentUrl: documentUrl,
      notes: notes,
    );
    return RcVerifyResult.from(result);
  }

  /// Verify a driver's licence from a photo of the licence.
  ///
  /// The ONLY automatic licence path — the provider reads the licence out of
  /// the image and sells no number + date-of-birth lookup. Used by both KYC
  /// (the holder's own licence) and the Add Driver form.
  Future<VerificationResult<DrivingLicenceData>> verifyDriverLicenceDocument(
    File document,
  ) {
    final inFlight = _dlVerifyInFlight;
    if (inFlight != null) return inFlight;

    final future = _verification.verifyDriverLicence(document);
    _dlVerifyInFlight = future;
    return future.whenComplete(() => _dlVerifyInFlight = null);
  }

  /// Surfaces the backend's real validation/error message instead of a
  /// generic fallback (`ApiException` is never actually attached to
  /// `DioException.error` by the interceptor, so `e.error is ApiException`
  /// is always false — read straight from the response body instead).
  String _actionError(dio.DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      final m = data['message'];
      return m is List ? m.join(', ') : m.toString();
    }
    return fallback;
  }

  // ── Filtered views ─────────────────────────────────────────────────────────

  List<Vehicle> filteredVehicles(String query, String filter) {
    var list = vehicles.toList();
    if (filter != 'All' && filter.isNotEmpty) {
      list = list.where((v) {
        final s = v.status.toLowerCase();
        final f = filter.toLowerCase();
        if (f == 'owned') return v.ownershipType.toLowerCase() == 'owned';
        if (f == 'attached') return v.ownershipType.toLowerCase() == 'attached';
        return s == f;
      }).toList();
    }
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      list = list
          .where(
            (v) =>
                v.vehicleModel.toLowerCase().contains(q) ||
                v.vehicleNumber.toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
  }

  List<Driver> filteredDrivers(String query, String filter) {
    var list = drivers.toList();
    if (filter != 'All' && filter.isNotEmpty) {
      list = list.where((d) {
        final s = d.status.toLowerCase();
        final f = filter.toLowerCase();
        return s == f || d.vehicleType.toLowerCase().contains(f);
      }).toList();
    }
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      list = list
          .where(
            (d) =>
                d.fullName.toLowerCase().contains(q) ||
                d.vehicleNumber.toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Extracts the inner data map from a 402 DioException response.
  /// Backend wraps data as: `{ status: 402, data: { orderId, razorpayKey, ... } }`
  Map<String, dynamic> _extract402Data(dio.DioException e) {
    final raw = e.response?.data;
    if (raw is Map<String, dynamic>) {
      final inner = raw['data'];
      if (inner is Map<String, dynamic>) return inner;
      return raw;
    }
    return {};
  }

  /// Builds the driver FormData, optionally embedding a Razorpay payment proof.
  Future<dio.FormData> _buildDriverFormData({
    required String name,
    required String licenseNumber,
    required String dateOfBirth,
    required String phoneNumber,
    required String vehicleType,
    String description = '',
    String experience = '',
    String status = 'Available',
    String email = '',
    String location = '',
    String address = '',
    String licenseExpiryDate = '',
    String vehicleCategoryDetail = '',
    File? image,
    Map<String, dynamic>? payment,
  }) async {
    final fields = <String, dynamic>{
      'name': name,
      // License number & DOB are optional (DL verification is unavailable for
      // now). Omit them entirely when blank so the backend's duplicate-license
      // check treats them as absent instead of matching on an empty string.
      if (licenseNumber.trim().isNotEmpty)
        'licenseNumber': licenseNumber.trim(),
      if (dateOfBirth.trim().isNotEmpty) 'dateOfBirth': dateOfBirth.trim(),
      'phoneNumber': phoneNumber,
      'vehicleCategoryExpertise': vehicleType,
      'description': description,
      'experience': experience,
      'status': status,
      'isDeclarationAccepted': true,
      if (email.isNotEmpty) 'email': email,
      if (location.isNotEmpty) 'location': location,
      if (address.isNotEmpty) 'address': address,
      if (licenseExpiryDate.isNotEmpty) 'licenseExpiryDate': licenseExpiryDate,
      if (vehicleCategoryDetail.isNotEmpty)
        'vehicleCategoryExpertiseDetail': vehicleCategoryDetail,
      // Attach payment proof so backend can verify and allow resource creation.
      if (payment != null) 'payment[orderId]': payment['orderId'],
      if (payment != null) 'payment[paymentId]': payment['paymentId'],
      if (payment != null) 'payment[signature]': payment['signature'],
    };

    final formData = dio.FormData.fromMap(fields);
    if (image != null) {
      formData.files.add(
        MapEntry('image', await dio.MultipartFile.fromFile(image.path)),
      );
    }
    return formData;
  }

  /// Builds the vehicle JSON payload — 1:1 with the web `handleSaveVehicle`
  /// (`CreateVehicleDto`/`UpdateVehicleDto`): `status` mirrors `ownership`
  /// (the web form reuses the same value for both), `metrics` is always sent
  /// as a full object (defaults to 0, matching the web form's pre-filled
  /// zeros), and the image — if any — is inlined as a base64 data-URL exactly
  /// like the web's `FileReader.readAsDataURL` (no separate upload endpoint).
  Future<Map<String, dynamic>> _buildVehiclePayload({
    required String name,
    required String model,
    required String registrationNumber,
    required int year,
    required String ownership,
    required String category,
    required String statusBadge,
    String categoryDetail = '',
    String fuelType = 'Diesel',
    String capacity = '',
    String mileage = '',
    String location = '',
    File? image,
    Map<String, dynamic>? payment,
  }) async {
    String? imageDataUrl;
    if (image != null) {
      imageDataUrl = await ProfileService.fileToBase64DataUrl(image);
    }
    return {
      'name': name,
      'model': model,
      'year': year,
      'registrationNumber': registrationNumber,
      'status': ownership,
      'fuelType': fuelType,
      'capacity': capacity,
      'mileage': mileage,
      'location': location.trim().isEmpty ? 'Not Specified' : location.trim(),
      if (imageDataUrl != null) 'image': imageDataUrl,
      'statusBadge': statusBadge,
      'ownership': ownership,
      // NOTE: `metrics` is deliberately NOT sent.
      //
      // avgRun / tripEfficiency / monthlyUsage are derived by the backend from
      // the vehicle's actual trips. Sending them here persisted the client's
      // default (0) into the vehicle record, which was then displayed forever
      // as the vehicle's "Trip Efficiency" — the static-efficiency bug.
      // A client must not author a canonical backend metric.
      'category': category,
      if (category == 'Others' && categoryDetail.trim().isNotEmpty)
        'categoryDetail': categoryDetail.trim(),
      if (payment != null) 'payment': payment,
    };
  }
}
