import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';

import '../../controllers/Transport/fleet_controller.dart';
import '../../controllers/Transport/lease_controller.dart';
import '../../models/get_driver_model.dart';
import '../../models/get_vehicle_model.dart';
import '../../services/verification_service.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/smart_image.dart';
import 'Lease/lease_listings_screen.dart';
import 'Lease/incoming_bookings_screen.dart';
import 'Lease/my_booked_leases_screen.dart';
import 'Lease/create_lease_wizard.dart';
import 'Lease/marketplace_screen.dart';
import 'vehicle_detail_screen.dart';
import 'driver_profile.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _primary = Color(0xFFF36969);
const _primaryLight = Color(0xFFFFF1F1);
const _bg = Color(0xFFF9FAFB);
const _card = Colors.white;
const _textDark = Color(0xFF111827);
const _textGrey = Color(0xFF6B7280);
const _border = Color(0xFFE5E7EB);

class FleetVehiclesScreen extends StatefulWidget {
  const FleetVehiclesScreen({super.key});

  @override
  State<FleetVehiclesScreen> createState() => _FleetVehiclesScreenState();
}

class _FleetVehiclesScreenState extends State<FleetVehiclesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final DriverController _ctrl = DriverController.shared;

  String _vehicleQuery = '';
  String _vehicleFilter = 'All';
  String _driverQuery = '';
  String _driverFilter = 'All';

  @override
  void initState() {
    super.initState();
    Get.put(LeaseController());
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildLeaseBar(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _VehiclesTab(
                  ctrl: _ctrl,
                  query: _vehicleQuery,
                  filter: _vehicleFilter,
                  onQueryChanged: (q) => setState(() => _vehicleQuery = q),
                  onFilterChanged: (f) => setState(() => _vehicleFilter = f),
                  onAdd: () => _showVehicleModal(context),
                ),
                _DriversTab(
                  ctrl: _ctrl,
                  query: _driverQuery,
                  filter: _driverFilter,
                  onQueryChanged: (q) => setState(() => _driverQuery = q),
                  onFilterChanged: (f) => setState(() => _driverFilter = f),
                  onAdd: () => _showDriverModal(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _card,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: _border,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 20,
          color: _textDark,
        ),
        onPressed: () => Get.back(),
      ),
      title: const Text(
        'Fleet Management',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: _textDark,
          fontFamily: 'Poppins',
        ),
      ),
      actions: [
        Obx(() {
          final busy = _ctrl.isLoading.value || _ctrl.isVehicleLoading.value;
          return busy
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _primary,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Iconsax.refresh, size: 20, color: _textGrey),
                  onPressed: _ctrl.refresh,
                );
        }),
      ],
    );
  }

  // ── Lease quick-access bar ─────────────────────────────────────────────────

  Widget _buildLeaseBar() {
    return Container(
      color: _card,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lease Marketplace',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _textGrey,
              fontFamily: 'Poppins',
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _leaseChip(
                  Iconsax.receipt_text,
                  'My Listings',
                  const Color(0xFF3B82F6),
                  () => Get.to(() => const LeaseListingsScreen()),
                ),
                const SizedBox(width: 8),
                _leaseChip(
                  Iconsax.add_circle,
                  'List Vehicle',
                  _primary,
                  () => Get.to(() => const CreateLeaseWizard()),
                ),
                const SizedBox(width: 8),
                _leaseChip(
                  Iconsax.document_download,
                  'Incoming',
                  const Color(0xFF22C55E),
                  () => Get.to(() => const IncomingBookingsScreen()),
                ),
                const SizedBox(width: 8),
                _leaseChip(
                  Iconsax.shop,
                  'Marketplace',
                  const Color(0xFF10B981),
                  () => Get.to(() => const MarketplaceScreen()),
                ),
                const SizedBox(width: 8),
                _leaseChip(
                  Iconsax.shopping_cart,
                  'My Leases',
                  const Color(0xFF8B5CF6),
                  () => Get.to(() => const MyBookedLeasesScreen()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _leaseChip(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab bar ────────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      color: _card,
      child: TabBar(
        controller: _tabCtrl,
        labelColor: _primary,
        unselectedLabelColor: _textGrey,
        indicatorColor: _primary,
        indicatorWeight: 2,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          fontFamily: 'Poppins',
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          fontFamily: 'Poppins',
        ),
        tabs: [
          Tab(
            child: Obx(
              () => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Iconsax.truck, size: 16),
                  const SizedBox(width: 6),
                  Text('Vehicles (${_ctrl.vehicles.length})'),
                ],
              ),
            ),
          ),
          Tab(
            child: Obx(
              () => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Iconsax.people, size: 16),
                  const SizedBox(width: 6),
                  Text('Drivers (${_ctrl.drivers.length})'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Add/Edit modals ────────────────────────────────────────────────────────

  void _showVehicleModal(BuildContext context, [Vehicle? vehicle]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VehicleModal(ctrl: _ctrl, vehicle: vehicle),
    );
  }

  void _showDriverModal(BuildContext context, [Driver? driver]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DriverModal(ctrl: _ctrl, driver: driver),
    );
  }
}

// ── Vehicles tab ──────────────────────────────────────────────────────────────

class _VehiclesTab extends StatelessWidget {
  final DriverController ctrl;
  final String query;
  final String filter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onAdd;

  const _VehiclesTab({
    required this.ctrl,
    required this.query,
    required this.filter,
    required this.onQueryChanged,
    required this.onFilterChanged,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SearchFilterBar(
          query: query,
          onQueryChanged: onQueryChanged,
          filter: filter,
          filters: const [
            'All',
            'Available',
            'In-Transit',
            'Assigned',
            'Owned',
            'Attached',
          ],
          onFilterChanged: onFilterChanged,
          onAdd: onAdd,
          addLabel: 'Add Vehicle',
        ),
        Expanded(
          child: Obx(() {
            // Until a first load has COMPLETED we show a skeleton, never an
            // empty state. Telling a company they have no vehicles while the
            // request is still running is the exact failure being fixed here.
            if (!ctrl.hasLoadedVehicles.value && ctrl.vehicles.isEmpty) {
              return const SkeletonListView();
            }
            if (ctrl.vehicleLoadError.value.isNotEmpty &&
                ctrl.vehicles.isEmpty) {
              return _EmptyState(
                icon: Iconsax.warning_2,
                title: 'Could not load vehicles',
                subtitle: ctrl.vehicleLoadError.value,
                action: 'Retry',
                onAction: ctrl.fetchVehicles,
              );
            }

            final list = ctrl.filteredVehicles(query, filter);
            if (list.isEmpty) {
              // "No results" and "no vehicles at all" are different situations;
              // offering "Add your first vehicle" to someone whose SEARCH found
              // nothing is misleading.
              final isFiltered = query.isNotEmpty || filter != 'All';
              if (isFiltered) {
                return const _EmptyState(
                  icon: Iconsax.search_normal,
                  title: 'No matching vehicles',
                  subtitle: 'Try a different search or filter.',
                );
              }
              return _EmptyState(
                icon: Iconsax.truck,
                title: 'No vehicles yet',
                subtitle: 'Add your first vehicle to get started',
                action: 'Add Vehicle',
                onAction: onAdd,
              );
            }
            // Paging applies to the UNFILTERED list. A local search only
            // narrows what has been loaded, so asking for more pages while
            // filtering would silently fetch rows the user cannot see.
            final isFiltered = query.isNotEmpty || filter != 'All';

            return RefreshIndicator(
              color: _primary,
              onRefresh: ctrl.fetchVehicles,
              child: _PagedListView(
                itemCount: list.length,
                // ListView.builder already lazily builds only what is on
                // screen, so a fleet of thousands costs the same as a fleet of
                // thirty to render.
                itemBuilder: (_, i) =>
                    _VehicleCard(vehicle: list[i], ctrl: ctrl),
                canLoadMore: !isFiltered && ctrl.hasMoreVehicles.value,
                isLoadingMore: ctrl.isLoadingMoreVehicles.value,
                loadMoreError: ctrl.vehicleLoadMoreError.value,
                onLoadMore: ctrl.loadMoreVehicles,
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  final DriverController ctrl;
  const _VehicleCard({required this.vehicle, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final statusColor = _vehicleStatusColor(vehicle.status);
    final gpsStatus = _gpsStatus(vehicle);
    // The stored value may be a hosted URL, a relative path, or a base64
    // `data:` URI (this app persists vehicle images as base64). SmartImage
    // renders all three — raw `Image.network` could not render data URIs,
    // which is why the photo fell through to the placeholder icon.
    final rawImage = vehicle.imageUrls.isNotEmpty
        ? vehicle.imageUrls.first
        : null;

    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Get.to(() => VehicleDetailScreen(vehicle: vehicle)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Hero image — a real photo when one was uploaded while adding
                // the vehicle, otherwise a branded placeholder (mirrors the
                // web fleet list's prominent vehicle photo).
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(18),
                  ),
                  child: SizedBox(
                    width: 104,
                    child: SmartImage(
                      source: rawImage,
                      fit: BoxFit.cover,
                      placeholder: _VehiclePlaceholder(),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                vehicle.vehicleModel,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _textDark,
                                  fontFamily: 'Poppins',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                vehicle.status.isEmpty
                                    ? 'Unknown'
                                    : vehicle.status,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          vehicle.vehicleNumber,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _textGrey,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _tag(vehicle.vehicleType, const Color(0xFF8B5CF6)),
                            _tag(
                              vehicle.ownershipType,
                              const Color(0xFF3B82F6),
                            ),
                            _tag(gpsStatus.$1, gpsStatus.$2),
                            if (vehicle.manufacturingYear > 0)
                              _tag(
                                '${vehicle.manufacturingYear}',
                                const Color(0xFF6B7280),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    right: 10,
                    top: 10,
                    bottom: 10,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _IconBtn(
                        Iconsax.edit,
                        const Color(0xFF3B82F6),
                        () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) =>
                              _VehicleModal(ctrl: ctrl, vehicle: vehicle),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _IconBtn(
                        Iconsax.trash,
                        const Color(0xFFEF4444),
                        () => _confirmDelete(
                          context,
                          'vehicle',
                          vehicle.vehicleModel,
                          () => ctrl.deleteVehicle(vehicle.vehicleId),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _vehicleStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return const Color(0xFF22C55E);
      case 'in-transit':
      case 'in transit':
        return const Color(0xFF3B82F6);
      case 'assigned':
        return const Color(0xFFF59E0B);
      case 'maintenance':
        return const Color(0xFFEF4444);
      default:
        return _textGrey;
    }
  }

  (String, Color) _gpsStatus(Vehicle vehicle) {
    final gps = vehicle.gpsLastKnown;
    if (gps == null) return ('GPS: Not connected', _textGrey);
    if (gps.stale) return ('GPS: Stale', const Color(0xFFF59E0B));
    return ('GPS: Live', const Color(0xFF22C55E));
  }
}

// ── Drivers tab ───────────────────────────────────────────────────────────────

class _DriversTab extends StatelessWidget {
  final DriverController ctrl;
  final String query;
  final String filter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onAdd;

  const _DriversTab({
    required this.ctrl,
    required this.query,
    required this.filter,
    required this.onQueryChanged,
    required this.onFilterChanged,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SearchFilterBar(
          query: query,
          onQueryChanged: onQueryChanged,
          filter: filter,
          filters: const ['All', 'Available', 'On Trip', 'Hired'],
          onFilterChanged: onFilterChanged,
          onAdd: onAdd,
          addLabel: 'Add Driver',
        ),
        Expanded(
          child: Obx(() {
            // Skeleton until a first load completes — never an empty state
            // while the request is still running.
            if (!ctrl.hasLoadedDrivers.value && ctrl.drivers.isEmpty) {
              return const SkeletonListView();
            }
            if (ctrl.driverLoadError.value.isNotEmpty && ctrl.drivers.isEmpty) {
              return _EmptyState(
                icon: Iconsax.warning_2,
                title: 'Could not load drivers',
                subtitle: ctrl.driverLoadError.value,
                action: 'Retry',
                onAction: ctrl.fetchDrivers,
              );
            }

            final list = ctrl.filteredDrivers(query, filter);
            if (list.isEmpty) {
              final isFiltered = query.isNotEmpty || filter != 'All';
              if (isFiltered) {
                return const _EmptyState(
                  icon: Iconsax.search_normal,
                  title: 'No matching drivers',
                  subtitle: 'Try a different search or filter.',
                );
              }
              return _EmptyState(
                icon: Iconsax.people,
                title: 'No drivers yet',
                subtitle: 'Add your first driver to get started',
                action: 'Add Driver',
                onAction: onAdd,
              );
            }
            return RefreshIndicator(
              color: _primary,
              onRefresh: ctrl.fetchDrivers,
              child: _PagedListView(
                itemCount: list.length,
                itemBuilder: (_, i) => _DriverCard(driver: list[i], ctrl: ctrl),
                // Paging applies to the unfiltered list — see the vehicles tab.
                canLoadMore:
                    query.isEmpty && filter == 'All' && ctrl.hasMoreDrivers.value,
                isLoadingMore: ctrl.isLoadingMoreDrivers.value,
                loadMoreError: ctrl.driverLoadMoreError.value,
                onLoadMore: ctrl.loadMoreDrivers,
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _DriverCard extends StatelessWidget {
  final Driver driver;
  final DriverController ctrl;
  const _DriverCard({required this.driver, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final rawImage = driver.driverImagePath;
    final statusColor = _statusColor(driver.status);

    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () =>
            Get.to(() => DriverProfileScreen(driverId: driver.driverId)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Avatar — a real photo when one was uploaded while adding the
                // driver, otherwise initials on a branded placeholder. The
                // colored ring mirrors the web card's status badge color.
                Container(
                  width: 76,
                  height: 76,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.55),
                      width: 2.5,
                    ),
                  ),
                  child: ClipOval(
                    child: SmartImage(
                      source: rawImage,
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                      placeholder: _DriverPlaceholder(driver.fullName),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              driver.fullName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _textDark,
                                fontFamily: 'Poppins',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (driver.status.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor(
                                  driver.status,
                                ).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                driver.status,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _statusColor(driver.status),
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        driver.contactNumber.isNotEmpty
                            ? driver.contactNumber
                            : '—',
                        style: const TextStyle(
                          fontSize: 12,
                          color: _textGrey,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Iconsax.star1,
                            size: 12,
                            color: Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 3),
                          const Text(
                            '4.7',
                            style: TextStyle(
                              fontSize: 11,
                              color: _textGrey,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (driver.vehicleType.isNotEmpty)
                            _tag(driver.vehicleType, const Color(0xFF8B5CF6)),
                          if (driver.experience.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            _tag(
                              '${driver.experience} yrs',
                              const Color(0xFF3B82F6),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    _IconBtn(
                      Iconsax.edit,
                      const Color(0xFF3B82F6),
                      () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) =>
                            _DriverModal(ctrl: ctrl, driver: driver),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _IconBtn(
                      Iconsax.trash,
                      const Color(0xFFEF4444),
                      () => _confirmDelete(
                        context,
                        'driver',
                        driver.fullName,
                        () => ctrl.deleteDriver(driver.driverId),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return const Color(0xFF22C55E);
      case 'on trip':
      case 'hired':
        return const Color(0xFF3B82F6);
      default:
        return _textGrey;
    }
  }
}

// ── Vehicle Add/Edit Modal ─────────────────────────────────────────────────────

class _VehicleModal extends StatefulWidget {
  final DriverController ctrl;
  final Vehicle? vehicle;
  const _VehicleModal({required this.ctrl, this.vehicle});

  @override
  State<_VehicleModal> createState() => _VehicleModalState();
}

class _VehicleModalState extends State<_VehicleModal> {
  final _nameCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _regCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  final _mileageCtrl = TextEditingController();
  final _categoryDetailCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  String _ownership = 'Owned';
  String _category = 'Shipment';
  String _fuelType = 'Diesel';
  bool _saving = false;
  bool _verifying = false;
  bool _confirmed = false;
  File? _image;
  final Set<String> _lockedFields = {};

  /// Last RC verification outcome — drives the persistent inline banner.
  RcVerifyResult? _rcResult;

  static const _fuelTypes = ['Diesel', 'Petrol', 'Electric', 'CNG'];
  static const _categories = ['Shipment', 'Construction', 'Mining', 'Others'];

  bool get _isEdit => widget.vehicle != null;
  bool _isLocked(String key) => !_isEdit && _lockedFields.contains(key);

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    if (v != null) {
      _nameCtrl.text = v.vehicleName.isNotEmpty
          ? v.vehicleName
          : v.vehicleModel;
      _modelCtrl.text = v.vehicleModel;
      _regCtrl.text = v.vehicleNumber;
      _yearCtrl.text = v.manufacturingYear > 0 ? '${v.manufacturingYear}' : '';
      _locationCtrl.text = v.description;
      _categoryDetailCtrl.text = v.categoryDetail;
      _capacityCtrl.text = v.capacity;
      _mileageCtrl.text = v.mileage;
      _fuelType = _fuelTypes.contains(v.fuelType) ? v.fuelType : 'Diesel';
      _ownership = v.ownershipType.isEmpty ? 'Owned' : v.ownershipType;
      _category = _categories.contains(v.vehicleType)
          ? v.vehicleType
          : 'Shipment';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _modelCtrl.dispose();
    _regCtrl.dispose();
    _yearCtrl.dispose();
    _capacityCtrl.dispose();
    _mileageCtrl.dispose();
    _categoryDetailCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  /// RC verification (add mode only) — mirrors web `handleFetchVehicleDetails`:
  /// auto-fills + locks registrationNumber/model/name/year/fuelType/capacity.
  Future<void> _verify() async {
    // Guarding here as well as in the controller keeps the loading state
    // honest: without it, a second tap would flip the spinner back on for a
    // request that is really the first one still finishing.
    if (_verifying) return;

    final registration = _regCtrl.text.trim();
    if (registration.isEmpty) {
      SnackBarHelper.warning('Enter registration number first');
      return;
    }

    setState(() {
      _verifying = true;
      _rcResult = null; // clear any previous banner
    });

    RcVerifyResult result;
    try {
      result = await widget.ctrl.verifyVehicleRegistration(registration);
    } finally {
      // Released whatever happens, so a failure can never leave a permanent
      // spinner on the Add Vehicle sheet.
      if (mounted) setState(() => _verifying = false);
    }
    if (!mounted) return;

    setState(() {
      // Persist the outcome so the form can render an inline banner. A snackbar
      // alone was not reliably visible above this sheet, so the user never saw
      // why verification failed or that they could continue manually.
      _rcResult = result;
    });

    // Only a backend-confirmed `verified` populates the form. Nothing here
    // decides verification, and no field is filled optimistically.
    final rc = result.rc;
    if (!result.isVerified || rc == null) return;

    final locked = <String>{};
    final reg = rc.registrationNumber?.trim();
    if (reg != null && reg.isNotEmpty) {
      _regCtrl.text = reg;
      locked.add('reg');
    }
    final model = (rc.model ?? rc.manufacturer)?.trim();
    if (model != null && model.isNotEmpty) {
      _modelCtrl.text = model;
      locked.add('model');
      if (_nameCtrl.text.trim().isEmpty) _nameCtrl.text = model;
      locked.add('name');
    }
    if (rc.year != null && rc.year! > 0) {
      _yearCtrl.text = '${rc.year}';
      locked.add('year');
    }
    final fuel = rc.fuelType;
    if (fuel != null && _fuelTypes.contains(fuel)) {
      _fuelType = fuel;
      locked.add('fuelType');
    }
    final capacity = rc.seatingCapacity?.trim();
    if (capacity != null && capacity.isNotEmpty) {
      _capacityCtrl.text = capacity;
      locked.add('capacity');
    }

    setState(() => _lockedFields.addAll(locked));
  }

  /// Inline RC verification result.
  ///
  /// Green on success; amber (never a red "invalid") when automatic
  /// verification could not be completed, with an explicit note that the
  /// vehicle can still be added and the RC submitted for manual verification.
  Widget _rcBanner(RcVerifyResult r) {
    final ok = r.isVerified;
    final bg = ok ? const Color(0xFFECFDF5) : const Color(0xFFFFF7ED);
    final fg = ok ? const Color(0xFF047857) : const Color(0xFF9A3412);
    final border = ok ? const Color(0xFFA7F3D0) : const Color(0xFFFED7AA);
    final icon = ok ? Iconsax.tick_circle : Iconsax.info_circle;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.message,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: fg,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Poppins',
                  ),
                ),
                if (r.needsManual) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Tip: attach the RC photo below — our team will verify it.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: fg.withValues(alpha: 0.85),
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (picked != null) setState(() => _image = File(picked.path));
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty ||
        _modelCtrl.text.trim().isEmpty ||
        _regCtrl.text.trim().isEmpty) {
      SnackBarHelper.warning('Name, model, and registration are required');
      return;
    }
    if (_category == 'Others' && _categoryDetailCtrl.text.trim().isEmpty) {
      SnackBarHelper.warning('Please specify the category');
      return;
    }
    if (!_confirmed) {
      SnackBarHelper.warning(
        'Please confirm the information provided is correct',
      );
      return;
    }
    setState(() => _saving = true);
    // avgRun / tripEfficiency / monthlyUsage are no longer captured here.
    // They are derived by the backend from the vehicle's actual trips; letting
    // an operator type them in produced numbers that looked authoritative but
    // were never reconciled against any trip.
    bool ok;
    if (widget.vehicle != null) {
      ok = await widget.ctrl.updateVehicle(
        vehicleId: widget.vehicle!.vehicleId,
        name: _nameCtrl.text.trim(),
        model: _modelCtrl.text.trim(),
        registrationNumber: _regCtrl.text.trim(),
        year: int.tryParse(_yearCtrl.text) ?? 0,
        ownership: _ownership,
        category: _category,
        categoryDetail: _categoryDetailCtrl.text.trim(),
        fuelType: _fuelType,
        capacity: _capacityCtrl.text.trim(),
        mileage: _mileageCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        statusBadge: widget.vehicle!.status.isNotEmpty
            ? widget.vehicle!.status
            : 'Available',
        image: _image,
      );
    } else {
      ok = await widget.ctrl.createVehicle(
        name: _nameCtrl.text.trim(),
        model: _modelCtrl.text.trim(),
        registrationNumber: _regCtrl.text.trim(),
        year: int.tryParse(_yearCtrl.text) ?? 0,
        ownership: _ownership,
        category: _category,
        categoryDetail: _categoryDetailCtrl.text.trim(),
        fuelType: _fuelType,
        capacity: _capacityCtrl.text.trim(),
        mileage: _mileageCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        image: _image,
      );
    }
    setState(() => _saving = false);
    if (ok) Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.vehicle != null;
    return _ModalSheet(
      title: isEdit ? 'Edit Vehicle' : 'Add Vehicle',
      child: Column(
        children: [
          if (!isEdit)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🚗 Quick Vehicle Verification',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _textDark,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _ModalField(
                          'Registration No.',
                          _regCtrl,
                          hint: 'MH01AB1234',
                          required: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: (_verifying || _regCtrl.text.trim().isEmpty)
                            ? null
                            : _verify,
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: _verifying ? _border : _primaryLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: _verifying
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _primary,
                                  ),
                                )
                              : Text(
                                  // After a failed attempt the action is a
                                  // retry, so the label says so rather than
                                  // looking like nothing happened.
                                  _rcResult != null && !_rcResult!.isVerified
                                      ? 'Try Again'
                                      : 'Verify',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: _primary,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  // Persistent RC verification result. Shown inline (not as a
                  // snackbar, which the sheet could obscure) so the user always
                  // sees the outcome and knows they can continue manually.
                  if (_rcResult != null) ...[
                    const SizedBox(height: 10),
                    _rcBanner(_rcResult!),
                  ],
                ],
              ),
            )
          else
            _ModalField(
              'Registration No.',
              _regCtrl,
              hint: 'MH01AB1234',
              required: true,
            ),
          const SizedBox(height: 12),
          _ModalField(
            'Vehicle Name',
            _nameCtrl,
            hint: 'e.g. Tata Ace',
            required: true,
            enabled: !_isLocked('name'),
          ),
          const SizedBox(height: 12),
          _ModalField(
            'Model',
            _modelCtrl,
            hint: 'e.g. Tata 407',
            required: true,
            enabled: !_isLocked('model'),
          ),
          const SizedBox(height: 12),
          _ModalField(
            'Year',
            _yearCtrl,
            hint: '2022',
            keyboard: TextInputType.number,
            enabled: !_isLocked('year'),
          ),
          const SizedBox(height: 12),
          _ModalDropdown(
            'Fuel Type',
            _fuelType,
            _fuelTypes,
            (v) => setState(() => _fuelType = v!),
            required: true,
          ),
          const SizedBox(height: 12),
          _ModalField(
            'Capacity',
            _capacityCtrl,
            hint: 'e.g. 5 Tons',
            enabled: !_isLocked('capacity'),
          ),
          const SizedBox(height: 12),
          _ModalField('Mileage (km)', _mileageCtrl, hint: 'e.g. 50000'),
          const SizedBox(height: 12),
          _ModalDropdown(
            'Category',
            _category,
            _categories,
            (v) => setState(() => _category = v!),
            required: true,
          ),
          if (_category == 'Others') ...[
            const SizedBox(height: 12),
            _ModalField(
              'Specify Category',
              _categoryDetailCtrl,
              hint: 'e.g. Refrigerated',
              required: true,
            ),
          ],
          const SizedBox(height: 12),
          _ModalDropdown(
            'Ownership',
            _ownership,
            const ['Owned', 'Attached', 'Rented'],
            (v) => setState(() => _ownership = v!),
            required: true,
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'VEHICLE METRICS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _textGrey,
                    letterSpacing: 0.6,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 12),
                // Odometer / Trip Efficiency / Monthly Usage inputs removed.
                //
                // These were REQUIRED free-text fields — an operator typed a
                // "Trip Efficiency (Rs/KM)" that was stored verbatim and shown
                // on Vehicle Details as though it were measured. All three are
                // now derived by the backend from the vehicle's actual trips.
                const Text(
                  'Distance, cost per km and monthly usage are calculated automatically from this vehicle’s completed trips.',
                  style: TextStyle(
                    fontSize: 12,
                    color: _textGrey,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ModalField(
            'Current Location / Description',
            _locationCtrl,
            hint: 'Current location or notes',
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border, style: BorderStyle.solid),
              ),
              child: Column(
                children: [
                  Icon(
                    _image != null ? Iconsax.tick_circle : Iconsax.gallery_add,
                    color: _image != null ? const Color(0xFF22C55E) : _textGrey,
                    size: 22,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _image == null
                        ? 'Tap to add vehicle image'
                        : 'Image selected',
                    style: TextStyle(
                      fontSize: 12,
                      color: _image != null
                          ? const Color(0xFF22C55E)
                          : _textGrey,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _ConfirmCheckbox(
            value: _confirmed,
            label:
                'I confirm that all the information provided above is correct and accurate to the best of my knowledge.',
            onChanged: (v) => setState(() => _confirmed = v ?? false),
          ),
          const SizedBox(height: 16),
          _SaveButton(saving: _saving, onSave: _save),
        ],
      ),
    );
  }
}

// ── Driver Add/Edit Modal ──────────────────────────────────────────────────────

class _DriverModal extends StatefulWidget {
  final DriverController ctrl;
  final Driver? driver;
  const _DriverModal({required this.ctrl, this.driver});

  @override
  State<_DriverModal> createState() => _DriverModalState();
}

class _DriverModalState extends State<_DriverModal> {
  final _nameCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _expCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _categoryDetailCtrl = TextEditingController();
  DateTime? _dob;
  DateTime? _licenseExpiry;
  String _category = 'Shipment';
  String _status = 'Available';
  File? _image;
  bool _saving = false;
  bool _verifying = false;
  bool _confirmed = false;
  final Set<String> _lockedFields = {};

  static const _statusOptions = ['Available', 'On Trip', 'Off Duty'];
  static const _categories = ['Shipment', 'Construction', 'Mining', 'Others'];

  bool get _isEdit => widget.driver != null;
  bool _isLocked(String key) => !_isEdit && _lockedFields.contains(key);

  @override
  void initState() {
    super.initState();
    final d = widget.driver;
    if (d != null) {
      _nameCtrl.text = d.fullName;
      _licenseCtrl.text = d.dlNo;
      _phoneCtrl.text = d.contactNumber;
      _expCtrl.text = d.experience;
      _locationCtrl.text = d.location;
      _addressCtrl.text = d.address;
      _categoryDetailCtrl.text = d.vehicleCategoryDetail;
      _dob = d.dateOfBirth;
      _licenseExpiry = d.licenseExpiryDate;
      _category = _categories.contains(d.vehicleType)
          ? d.vehicleType
          : 'Shipment';
      // Normalize status to a valid enum value
      final rawStatus = d.status;
      _status = _statusOptions.contains(rawStatus) ? rawStatus : 'Available';
    }
    // Rebuilds the Verify button's enabled state live as the user types,
    // mirroring the web form's `disabled={!licenseNumber.trim() || !dob}`.
    _licenseCtrl.addListener(_onVerifyInputsChanged);
  }

  void _onVerifyInputsChanged() => setState(() {});

  @override
  void dispose() {
    _licenseCtrl.removeListener(_onVerifyInputsChanged);
    _nameCtrl.dispose();
    _licenseCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _expCtrl.dispose();
    _locationCtrl.dispose();
    _addressCtrl.dispose();
    _categoryDetailCtrl.dispose();
    super.dispose();
  }

  /// Driving Licence verification from a photo of the licence.
  ///
  /// The provider's only Driving Licence product reads the licence out of the
  /// image, so the company photographs the driver's licence (or picks it from
  /// the gallery) instead of typing a number and date of birth. On success it
  /// auto-fills and locks name / licence / DOB / address / category-detail /
  /// licence-expiry.
  ///
  /// Verification is a convenience here — a failure never blocks adding the
  /// driver, and the form is left fully editable.
  Future<void> _verify() async {
    if (_verifying) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Iconsax.camera, color: _primary),
              title: const Text(
                'Take a photo of the licence',
                style: TextStyle(fontSize: 14, fontFamily: 'Poppins'),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Iconsax.gallery, color: _primary),
              title: const Text(
                'Choose from gallery',
                style: TextStyle(fontSize: 14, fontFamily: 'Poppins'),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    // Downscaled before upload: the OCR endpoint caps a document at 5MB, and a
    // modern phone camera clears that on its own.
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (picked == null || !mounted) return;

    setState(() => _verifying = true);

    VerificationResult<DrivingLicenceData> result;
    try {
      result = await widget.ctrl.verifyDriverLicenceDocument(File(picked.path));
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
    if (!mounted) return;

    final dl = result.data;
    if (!result.verified || dl == null) {
      // The backend authors this copy and it is always user-safe — no status
      // code, exception name or provider string ever reaches the screen.
      SnackBarHelper.warning(result.message);
      return;
    }

    final locked = <String>{};
    final name = dl.name?.trim();
    if (name != null && name.isNotEmpty) {
      _nameCtrl.text = name;
      locked.add('name');
    }
    final lic = dl.licenseNumber?.trim();
    if (lic != null && lic.isNotEmpty) {
      _licenseCtrl.text = lic;
      locked.add('license');
    }
    final address = dl.address?.trim();
    if (address != null && address.isNotEmpty) {
      _addressCtrl.text = address;
      locked.add('address');
    }
    final classes = dl.vehicleClasses;
    if (classes != null && classes.isNotEmpty) {
      _categoryDetailCtrl.text = classes.join(', ');
      locked.add('categoryDetail');
    }
    // The provider gives dates as DD/MM/YYYY; parsed explicitly so
    // 10/02/2030 is never read as 2 October.
    final resolvedDob = _parseDDMMYYYY(dl.dateOfBirth?.trim() ?? '');
    if (resolvedDob != null) {
      _dob = resolvedDob;
      locked.add('dob');
    }
    final expiry = _parseDDMMYYYY(dl.expiryDate?.trim() ?? '');
    if (expiry != null) {
      _licenseExpiry = expiry;
      locked.add('licenseExpiry');
    }

    setState(() => _lockedFields.addAll(locked));
    // The backend authors this copy and it is always user-safe, so it is shown
    // verbatim. A hardcoded 'Driving Licence verified' used to discard it —
    // which hid the case where the licence verifies but some fields could not
    // be read, leaving the form filled with almost nothing and no reason given.
    SnackBarHelper.success(result.message);
  }

  DateTime? _parseDDMMYYYY(String value) {
    final parts = value.split('/');
    if (parts.length != 3) return DateTime.tryParse(value);
    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (d == null || m == null || y == null) return null;
    return DateTime(y, m, d);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (picked != null) setState(() => _image = File(picked.path));
  }

  Future<void> _pickDob() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      builder: (c, child) => Theme(
        data: Theme.of(
          c,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _primary)),
        child: child!,
      ),
    );
    if (d != null) setState(() => _dob = d);
  }

  Future<void> _pickLicenseExpiry() async {
    final d = await showDatePicker(
      context: context,
      initialDate:
          _licenseExpiry ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 20)),
      builder: (c, child) => Theme(
        data: Theme.of(
          c,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _primary)),
        child: child!,
      ),
    );
    if (d != null) setState(() => _licenseExpiry = d);
  }

  Future<void> _save() async {
    // Only the driver's name is required. License number, DOB and expiry are
    // optional — DL verification is unavailable for now, so a company can add a
    // driver by entering (or skipping) these details manually and still save.
    if (_nameCtrl.text.trim().isEmpty) {
      SnackBarHelper.warning('Driver name is required');
      return;
    }
    if (_category == 'Others' && _categoryDetailCtrl.text.trim().isEmpty) {
      SnackBarHelper.warning('Please specify the category');
      return;
    }
    setState(() => _saving = true);
    final dobIso = _dob?.toIso8601String() ?? '';
    final expiryIso = _licenseExpiry?.toIso8601String() ?? '';
    bool ok;
    if (widget.driver != null) {
      ok = await widget.ctrl.updateDriver(
        driverId: widget.driver!.driverId,
        name: _nameCtrl.text.trim(),
        licenseNumber: _licenseCtrl.text.trim(),
        dateOfBirth: dobIso,
        phoneNumber: _phoneCtrl.text.trim(),
        vehicleType: _category,
        experience: _expCtrl.text.trim(),
        status: _status,
        email: _emailCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        licenseExpiryDate: expiryIso,
        vehicleCategoryDetail: _categoryDetailCtrl.text.trim(),
        image: _image,
      );
    } else {
      ok = await widget.ctrl.createDriver(
        name: _nameCtrl.text.trim(),
        licenseNumber: _licenseCtrl.text.trim(),
        dateOfBirth: dobIso,
        phoneNumber: _phoneCtrl.text.trim(),
        vehicleType: _category,
        experience: _expCtrl.text.trim(),
        status: _status,
        email: _emailCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        licenseExpiryDate: expiryIso,
        vehicleCategoryDetail: _categoryDetailCtrl.text.trim(),
        image: _image,
      );
    }
    setState(() => _saving = false);
    if (ok) Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.driver != null;
    return _ModalSheet(
      title: isEdit ? 'Edit Driver' : 'Add Driver',
      child: Column(
        children: [
          if (!isEdit)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🪪 Quick License Verification',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _textDark,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Optional — enter the licence number and date of birth to '
                    'auto-fill the details, or just fill the form in below.',
                    style: TextStyle(
                      fontSize: 11,
                      color: _textGrey,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 10),
                  // The two inputs the lookup runs on. They live here rather
                  // than further down the form so the whole verification step
                  // reads as one block: type these two, tap Verify, the rest
                  // fills itself in.
                  _ModalField(
                    'License Number',
                    _licenseCtrl,
                    hint: 'DL1234567890',
                    enabled: !_isLocked('license'),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _isLocked('dob') ? null : _pickDob,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: _isLocked('dob')
                            ? const Color(0xFFF3F4F6)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _border),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Iconsax.calendar,
                            size: 18,
                            color: _textGrey,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _dob == null
                                ? 'Date of Birth'
                                : _fmtDate(_dob!),
                            style: TextStyle(
                              fontSize: 14,
                              color: _dob == null
                                  ? const Color(0xFF9CA3AF)
                                  : _textDark,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      // Always available: the licence photo IS the input, so
                      // there is nothing to fill in first.
                      onTap: _verifying ? null : _verify,
                      child: Container(
                        // 44dp keeps this a comfortable touch target.
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          // Greyed only while a licence is being read.
                          color: _verifying ? _border : _primaryLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: _verifying
                            ? const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _primary,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Reading the licence...',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _textGrey,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ],
                              )
                            : const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Iconsax.camera,
                                    size: 16,
                                    color: _primary,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Scan Licence to Auto-fill',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _primary,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            _ModalField('License Number', _licenseCtrl, hint: 'DL1234567890'),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickDob,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  children: [
                    const Icon(Iconsax.calendar, size: 18, color: _textGrey),
                    const SizedBox(width: 10),
                    Text(
                      _dob == null
                          ? 'Date of Birth (optional)'
                          : _fmtDate(_dob!),
                      style: TextStyle(
                        fontSize: 14,
                        color: _dob == null
                            ? const Color(0xFF9CA3AF)
                            : _textDark,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _ModalField(
            'Full Name',
            _nameCtrl,
            hint: 'e.g. Rajesh Kumar',
            required: true,
            enabled: !_isLocked('name'),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickLicenseExpiry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: _isLocked('licenseExpiry')
                    ? const Color(0xFFF3F4F6)
                    : _bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.calendar_1, size: 18, color: _textGrey),
                  const SizedBox(width: 10),
                  Text(
                    _licenseExpiry == null
                        ? 'License Expiry Date (optional)'
                        : _fmtDate(_licenseExpiry!),
                    style: TextStyle(
                      fontSize: 14,
                      color: _licenseExpiry == null
                          ? const Color(0xFF9CA3AF)
                          : _textDark,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _ModalField(
            'Phone Number',
            _phoneCtrl,
            hint: '+91 9876543210',
            keyboard: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          _ModalField(
            'Email',
            _emailCtrl,
            hint: 'driver@example.com',
            keyboard: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          _ModalField(
            'Experience (years)',
            _expCtrl,
            hint: '5',
            keyboard: TextInputType.number,
          ),
          const SizedBox(height: 12),
          _ModalDropdown(
            'Status',
            _status,
            _statusOptions,
            (v) => setState(() => _status = v!),
            required: true,
          ),
          const SizedBox(height: 12),
          _ModalDropdown(
            'Vehicle Category',
            _category,
            _categories,
            (v) => setState(() => _category = v!),
            required: true,
          ),
          if (_category == 'Others') ...[
            const SizedBox(height: 12),
            _ModalField(
              'Specify',
              _categoryDetailCtrl,
              hint: 'e.g. Tanker',
              required: true,
              enabled: !_isLocked('categoryDetail'),
            ),
          ],
          const SizedBox(height: 12),
          _ModalField(
            'Current Location',
            _locationCtrl,
            hint: 'e.g. Mumbai',
            enabled: !_isLocked('location'),
          ),
          const SizedBox(height: 12),
          _ModalField(
            'Address',
            _addressCtrl,
            hint: 'Full address',
            maxLines: 2,
            enabled: !_isLocked('address'),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _image != null ? Iconsax.tick_circle : Iconsax.camera,
                    size: 18,
                    color: _image != null ? const Color(0xFF22C55E) : _textGrey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _image != null ? 'Photo selected' : 'Add driver photo',
                    style: TextStyle(
                      fontSize: 13,
                      color: _image != null
                          ? const Color(0xFF22C55E)
                          : _textGrey,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _ConfirmCheckbox(
            value: _confirmed,
            label: 'I confirm the information provided is correct.',
            onChanged: (v) => setState(() => _confirmed = v ?? false),
          ),
          const SizedBox(height: 16),
          _SaveButton(saving: _saving, onSave: _save),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ── Shared small widgets ───────────────────────────────────────────────────────

class _SearchFilterBar extends StatelessWidget {
  final String query;
  final ValueChanged<String> onQueryChanged;
  final String filter;
  final List<String> filters;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onAdd;
  final String addLabel;

  const _SearchFilterBar({
    required this.query,
    required this.onQueryChanged,
    required this.filter,
    required this.filters,
    required this.onFilterChanged,
    required this.onAdd,
    required this.addLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _card,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border),
                  ),
                  child: TextField(
                    onChanged: onQueryChanged,
                    decoration: const InputDecoration(
                      hintText: 'Search…',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: _textGrey,
                        fontFamily: 'Poppins',
                      ),
                      prefixIcon: Icon(
                        Iconsax.search_normal,
                        size: 16,
                        color: _textGrey,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      color: _textDark,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: _primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        addLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 30,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final f = filters[i];
                final active = filter == f;
                return GestureDetector(
                  onTap: () => onFilterChanged(f),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: active ? _primary : _bg,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: active ? _primary : _border),
                    ),
                    child: Text(
                      f,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active ? Colors.white : _textGrey,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A lazily-built list that appends pages as the user approaches the end.
///
/// Built on `ListView.builder`, so only the rows actually on screen are ever
/// constructed — a fleet of thousands costs the same to render as a fleet of
/// thirty, and memory stays flat because off-screen rows are recycled.
///
/// Paging is triggered from a scroll notification rather than from `build`:
/// firing requests out of a build method is how a list ends up issuing one
/// request per frame.
class _PagedListView extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final bool canLoadMore;
  final bool isLoadingMore;
  final String loadMoreError;
  final VoidCallback onLoadMore;

  const _PagedListView({
    required this.itemCount,
    required this.itemBuilder,
    required this.canLoadMore,
    required this.isLoadingMore,
    required this.loadMoreError,
    required this.onLoadMore,
  });

  /// How close to the bottom (in pixels) the next page starts loading.
  /// Roughly two cards, so the rows are usually ready before they are reached.
  static const double _loadMoreThreshold = 320;

  @override
  Widget build(BuildContext context) {
    // A footer row is appended for the loading / retry / end-of-list state.
    final showFooter = canLoadMore || isLoadingMore || loadMoreError.isNotEmpty;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (!canLoadMore || isLoadingMore) return false;

        final metrics = notification.metrics;
        // `hasContentDimensions` guards against the first frame, where extents
        // are not yet known and the check would read as "at the bottom".
        if (!metrics.hasContentDimensions) return false;

        if (metrics.pixels >= metrics.maxScrollExtent - _loadMoreThreshold) {
          // The controller collapses duplicate calls, so a fast fling cannot
          // turn into a burst of page requests.
          onLoadMore();
        }
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        // Always scrollable so pull-to-refresh works even on a short list.
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: itemCount + (showFooter ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index < itemCount) return itemBuilder(context, index);
          return _PagingFooter(
            isLoading: isLoadingMore,
            error: loadMoreError,
            onRetry: onLoadMore,
          );
        },
      ),
    );
  }
}

/// The last row of a paged list: a spinner, a retry, or nothing.
class _PagingFooter extends StatelessWidget {
  final bool isLoading;
  final String error;
  final VoidCallback onRetry;

  const _PagingFooter({
    required this.isLoading,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (error.isNotEmpty) {
      // A failed append never disturbs the rows already on screen — it offers
      // a retry in place.
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                color: _textGrey,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: _primary,
                minimumSize: const Size(0, 44),
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
          ),
        ),
      );
    }

    // More pages exist but loading has not started yet — reserve the space so
    // the list does not jump when the spinner appears.
    return const SizedBox(height: 44);
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  /// Optional: some empty states are purely informational (a search that
  /// matched nothing has no sensible call to action).
  final String? action;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: _primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _textDark,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: _textGrey,
                fontFamily: 'Poppins',
              ),
            ),
            if (action != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(action!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  // A comfortable touch target on smaller Android screens.
                  minimumSize: const Size(0, 44),
                  textStyle: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModalSheet extends StatelessWidget {
  final String title;
  final Widget child;
  const _ModalSheet({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _textDark,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: _textGrey),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
            ),
            const Divider(color: _border),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(20),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModalField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String? hint;
  final TextInputType? keyboard;
  final int maxLines;
  final bool required;
  final bool enabled;

  const _ModalField(
    this.label,
    this.ctrl, {
    this.hint,
    this.keyboard,
    this.maxLines = 1,
    this.required = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _textGrey,
                fontFamily: 'Poppins',
              ),
            ),
            if (required)
              const Text(' *', style: TextStyle(color: _primary, fontSize: 12)),
            if (!enabled) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.lock_rounded,
                size: 11,
                color: Color(0xFF22C55E),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboard,
          maxLines: maxLines,
          enabled: enabled,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontSize: 14,
              color: Color(0xFF9CA3AF),
              fontFamily: 'Poppins',
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            counterText: '',
            filled: true,
            fillColor: enabled ? _bg : const Color(0xFFF3F4F6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _primary, width: 1.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _border),
            ),
          ),
          style: const TextStyle(
            fontSize: 14,
            color: _textDark,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }
}

class _ModalDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final bool required;

  const _ModalDropdown(
    this.label,
    this.value,
    this.items,
    this.onChanged, {
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _textGrey,
                fontFamily: 'Poppins',
              ),
            ),
            if (required)
              const Text(' *', style: TextStyle(color: _primary, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border),
          ),
          child: DropdownButton<String>(
            value: items.contains(value) ? value : items.first,
            isExpanded: true,
            underline: const SizedBox(),
            items: items
                .map(
                  (i) => DropdownMenuItem(
                    value: i,
                    child: Text(
                      i,
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _ConfirmCheckbox extends StatelessWidget {
  final bool value;
  final String label;
  final ValueChanged<bool?> onChanged;
  const _ConfirmCheckbox({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: _primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: _textGrey,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final bool saving;
  final VoidCallback onSave;
  const _SaveButton({required this.saving, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: saving ? null : onSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          disabledBackgroundColor: _primary.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: saving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Save Changes',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontFamily: 'Poppins',
                ),
              ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _IconBtn(this.icon, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

class _VehiclePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 72,
    height: 72,
    color: const Color(0xFFF3F4F6),
    child: const Icon(Iconsax.truck, size: 28, color: _textGrey),
  );
}

class _DriverPlaceholder extends StatelessWidget {
  final String name;
  const _DriverPlaceholder(this.name);

  @override
  Widget build(BuildContext context) {
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'D';
    return Container(
      color: _primaryLight,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: _primary,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }
}

// ── Pure helpers ──────────────────────────────────────────────────────────────

Widget _tag(String label, Color color) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
  decoration: BoxDecoration(
    color: color.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(6),
  ),
  child: Text(
    label,
    style: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: color,
      fontFamily: 'Poppins',
    ),
  ),
);

Future<void> _confirmDelete(
  BuildContext context,
  String type,
  String name,
  Future<bool> Function() onDelete,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Remove $type',
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Text(
        'Are you sure you want to remove "$name"?',
        style: const TextStyle(fontFamily: 'Poppins'),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(result: false),
          child: const Text('Cancel', style: TextStyle(color: _textGrey)),
        ),
        ElevatedButton(
          onPressed: () => Get.back(result: true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('Remove', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
  if (confirmed == true) await onDelete();
}
