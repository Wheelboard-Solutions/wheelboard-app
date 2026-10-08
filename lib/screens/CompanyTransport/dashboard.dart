import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:get/get.dart';
import '../../controllers/Transport/dashboard_controller.dart';
import '../../models/dashboard_model.dart';
import '../../utils/format_utils.dart';
import '../../widgets/custom_loader.dart';
import 'job_screen.dart';
import 'job_form_screen.dart';
import 'job_application_screen.dart';
import 'trips_screen.dart';
import 'fleet_screen.dart';
import 'company_booking_detail_screen.dart';
import '../Professional/Expenses/professional_expenses_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(DashboardController());

    return Scaffold(
      backgroundColor: const Color(
        0xFFF5F7FA,
      ), // Light grey background for better contrast
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: const BackButton(color: Colors.black87),
        title: Text(
          "Dashboard",
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const CustomLoader(message: "Loading dashboard...");
        }

        if (controller.errorMessage.value.isNotEmpty &&
            controller.dashboardData.value == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    controller.errorMessage.value,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => controller.fetchDashboardData(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final data = controller.dashboardData.value;
        if (data == null) {
          return const Center(child: Text('No data available'));
        }

        return RefreshIndicator(
          onRefresh: controller.fetchDashboardData,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---------------- Metrics Section ----------------
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
                    // Provide more height for cards to prevent overflow
                    final double itemHeight = 130;
                    final double itemWidth =
                        (constraints.maxWidth - (crossAxisCount - 1) * 12) /
                        crossAxisCount;
                    final double childAspectRatio = itemWidth / itemHeight;

                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: childAspectRatio,
                      children: [
                        _statCard(
                          Icons.directions_car,
                          "Total Trips",
                          "${data.tripSummary.totalTrips} Trips",
                          // Surfaces completed alongside active so the app
                          // matches the web dashboard's trip counts.
                          "${data.tripSummary.activeTrips} Active · "
                              "${data.tripSummary.completedTrips} Completed",
                          Colors.green,
                        ),
                        GestureDetector(
                          onTap: () =>
                              Get.to(() => const FleetVehiclesScreen()),
                          child: _statCard(
                            Icons.local_shipping,
                            "Active Vehicles",
                            "${data.activeVehicles.activeVehicles} Vehicles",
                            "${data.vehicleAvailability.available} Available",
                            Colors.blue,
                          ),
                        ),
                        _statCard(
                          Icons.wallet,
                          "Monthly Expenses",
                          // 2-decimal currency to match the web card (₹470.66).
                          FormatUtils.formatMoney(
                              data.monthlyExpenses.totalExpenses),
                          data.monthlyExpenses.highestFuelAmount > 0
                              ? "Highest Fuel: ₹${_formatCurrency(data.monthlyExpenses.highestFuelAmount)}"
                              : "No expenses",
                          Colors.red,
                        ),
                        _statCard(
                          Icons.work,
                          "Jobs Posted",
                          "${data.jobsSummary.activeJobs} Active",
                          "${data.jobsSummary.unfilledJobs} Total",
                          Colors.purple,
                        ),
                        _statCard(
                          Icons.route,
                          // ₹/km — labelled as the cost metric it is.
                          "Cost per km",
                          data.tripEfficiency?.avgCostPerKm != null
                              ? "₹${data.tripEfficiency!.avgCostPerKm!.toStringAsFixed(2)}/km"
                              : "N/A",
                          data.tripEfficiency?.totalKmPerMonth != null
                              ? "${_formatNumber(data.tripEfficiency!.totalKmPerMonth!)} km/mo"
                              : "No data",
                          Colors.teal,
                        ),
                        _statCard(
                          Icons.car_rental,
                          "Vehicles on Lease",
                          data.vehiclesOnLease != null
                              ? "${data.vehiclesOnLease!.total}"
                              : "0",
                          data.vehiclesOnLease != null &&
                                  data.vehiclesOnLease!.leasedThisWeek > 0
                              ? "+${data.vehiclesOnLease!.leasedThisWeek} this week"
                              : "No new leases",
                          Colors.orange,
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 24),

                // ---------------- Trip Completion Trend ----------------
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _sectionTitle("Trip Completion Trend"),
                    // Range selector — same ranges the web dashboard offers.
                    // Backend regroups; the chart just renders.
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFCE7E7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Obx(
                        () => DropdownButton<String>(
                          value: controller.trendRange.value,
                          isDense: true,
                          underline: const SizedBox.shrink(),
                          borderRadius: BorderRadius.circular(12),
                          icon: const Icon(Icons.keyboard_arrow_down,
                              size: 16, color: Color(0xFFf36969)),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFf36969),
                            fontWeight: FontWeight.w600,
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: '7d', child: Text('Last 7 Days')),
                            DropdownMenuItem(
                                value: 'month', child: Text('Last Month')),
                            DropdownMenuItem(
                                value: '3month', child: Text('Last 3 Months')),
                            DropdownMenuItem(
                                value: 'all', child: Text('All Time')),
                          ],
                          onChanged: (v) {
                            if (v != null) controller.setTrendRange(v);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  height: 280,
                  padding: const EdgeInsets.fromLTRB(12, 24, 16, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Obx(
                    () => _buildRangedTrendChart(
                      controller.trendPoints,
                      controller.trendLoading.value,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ---------------- Vehicle Availability ----------------
                Card(
                  color: Colors.white,
                  elevation: 2,
                  shadowColor: Colors.black.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              "Vehicle Availability",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Icon(
                              Icons.access_time,
                              size: 16,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _availabilityItem(
                              "${data.vehicleAvailability.available}",
                              "Available",
                              Colors.green,
                              Icons.check_circle_outline,
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.grey[200],
                            ),
                            _availabilityItem(
                              "${data.vehicleAvailability.onTrip}",
                              "On Trip",
                              Colors.blue,
                              Icons.directions_car,
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.grey[200],
                            ),
                            _availabilityItem(
                              "${data.vehicleAvailability.onRent}",
                              "On Rent",
                              Colors.orange,
                              Icons.key,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ---------------- Top Rated Professionals ----------------
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _sectionTitle("Top Rated Professionals"),
                    if (data.topProfessionals.length > 3)
                      Obx(
                        () => TextButton(
                          onPressed: () =>
                              controller.showAllProfessionals.toggle(),
                          child: Text(
                            controller.showAllProfessionals.value
                                ? "Show Less"
                                : "View All",
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Obx(() {
                  // Get unique professional types from data
                  final Set<String> professionalTypes = {'All'};
                  for (var professional in data.topProfessionals) {
                    if (professional.professionalType.isNotEmpty) {
                      professionalTypes.add(professional.professionalType);
                    } else {
                      professionalTypes.add('Other');
                    }
                  }

                  final List<String> filterOptions = professionalTypes.toList()
                    ..sort();

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: filterOptions.map((filter) {
                        final isSelected =
                            controller.selectedProfessionalFilter.value ==
                            filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () =>
                                controller.setProfessionalFilter(filter),
                            child: _chip(filter, isSelected),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                Obx(() {
                  // Filter professionals based on selected filter
                  List<TopProfessional> filteredProfessionals =
                      data.topProfessionals;

                  if (controller.selectedProfessionalFilter.value != 'All') {
                    filteredProfessionals = data.topProfessionals.where((
                      professional,
                    ) {
                      if (controller.selectedProfessionalFilter.value ==
                          'Other') {
                        return professional.professionalType.isEmpty;
                      }
                      return professional.professionalType ==
                          controller.selectedProfessionalFilter.value;
                    }).toList();
                  }

                  final displayedList = controller.showAllProfessionals.value
                      ? filteredProfessionals
                      : filteredProfessionals.take(3).toList();

                  return filteredProfessionals.isNotEmpty
                      ? Column(
                          children: displayedList.map((professional) {
                            final role =
                                professional.professionalType.isNotEmpty
                                ? "${professional.professionalType} • ${professional.city}"
                                : professional.city;
                            // Fix image URL - replace backslashes with forward slashes
                            String imageUrl = professional.driverImagePath
                                .replaceAll('\\', '/');
                            return _professionalTile(
                              professional.fullName,
                              role,
                              imageUrl: imageUrl,
                            );
                          }).toList(),
                        )
                      : _emptyState(
                          "No professionals available for this filter",
                        );
                }),

                const SizedBox(height: 24),

                // ---------------- Jobs You Posted ----------------
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _sectionTitle("Jobs You Posted"),
                    TextButton(
                      onPressed: () => Get.to(() => const JobsScreen()),
                      child: const Text("View All"),
                    ),
                  ],
                ),
                ...(data.jobList.isNotEmpty
                    ? data.jobList.take(3).map((job) {
                        final jobTitle =
                            job.role ?? job.jobType ?? "Untitled Job";
                        return _jobCard(
                          jobTitle,
                          "${job.applicants ?? 0} Applicants",
                          "${job.likeCount ?? 0} Likes",
                          job.city ?? "",
                          job.salary ?? 0,
                          onView: () => Get.to(
                            () => JobApplicationsScreen(jobId: job.jobId),
                          ),
                          onEdit: () => Get.to(() => const JobsScreen()),
                        );
                      }).toList()
                    : [_emptyState("No jobs posted")]),
                const SizedBox(height: 12),
                _addButtonWithAction(
                  "+ Post New Job",
                  const Color(0xFFF44336),
                  () => Get.to(() => const PostJobScreen()),
                ),

                const SizedBox(height: 24),

                // ---------------- Expense Overview ----------------
                _sectionTitle("Expense Overview"),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _buildExpenseOverviewChart(data.recentTransactions),
                ),

                const SizedBox(height: 24),

                // ---------------- Recent Transactions ----------------
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _sectionTitle("Recent Transactions"),
                    TextButton(
                      onPressed: () => Get.to(() => const ProfessionalExpensesScreen(isProfessional: false)),
                      child: const Text("View All"),
                    ),
                  ],
                ),
                ...(data.recentTransactions.isNotEmpty
                    ? data.recentTransactions.take(5).map((transaction) {
                        IconData icon;
                        Color iconColor;
                        final expenseType =
                            transaction.expenseType?.toLowerCase() ?? '';
                        switch (expenseType) {
                          case 'fuel':
                            icon = Icons.local_gas_station;
                            iconColor = Colors.blue;
                            break;
                          case 'maintenance':
                            icon = Icons.build;
                            iconColor = Colors.orange;
                            break;
                          case 'challan':
                            icon = Icons.receipt;
                            iconColor = Colors.orangeAccent;
                            break;
                          case 'advance':
                            icon = Icons.account_balance_wallet;
                            iconColor = Colors.purple;
                            break;
                          case 'salary':
                            icon = Icons.payments;
                            iconColor = Colors.green;
                            break;
                          case 'food':
                            icon = Icons.restaurant;
                            iconColor = Colors.redAccent;
                            break;
                          default:
                            icon = Icons.receipt_long;
                            iconColor = Colors.grey;
                        }

                        // Format date
                        String formattedDate = "Unknown date";
                        if (transaction.dateEntered != null) {
                          try {
                            final date = DateTime.parse(
                              transaction.dateEntered!,
                            );
                            formattedDate =
                                "${date.day} ${_getMonthName(date.month)} • ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
                          } catch (e) {
                            formattedDate = transaction.dateEntered!;
                          }
                        }

                        return _transactionTile(
                          icon: icon,
                          iconColor: iconColor,
                          title: transaction.expenseType ?? "Transaction",
                          subtitle: formattedDate,
                          amount: transaction.amount != null
                              ? "₹${_formatCurrency(transaction.amount!)}"
                              : "₹0",
                        );
                      }).toList()
                    : [_emptyState("No recent transactions")]),
                const SizedBox(height: 12),
                _addButtonWithAction(
                  "+ Add Expense",
                  const Color(0xFF1A73E8),
                  () => Get.to(() => const ProfessionalExpensesScreen(isProfessional: false)),
                ),

                const SizedBox(height: 24),

                // ---------------- Assigned Services ----------------
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _sectionTitle("Assigned Services"),
                    if (data.assignedServices.length > 3)
                      Obx(
                        () => TextButton(
                          onPressed: () =>
                              controller.showAllAssignedServices.toggle(),
                          child: Text(
                            controller.showAllAssignedServices.value
                                ? "Show Less"
                                : "View All",
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Obx(() {
                  final displayedServices =
                      controller.showAllAssignedServices.value
                      ? data.assignedServices
                      : data.assignedServices.take(3).toList();

                  return data.assignedServices.isNotEmpty
                      ? Column(
                          children: displayedServices.map((service) {
                            // Format date
                            String formattedDate = "Unknown";
                            if (service.dateModified != null) {
                              try {
                                final date = DateTime.parse(
                                  service.dateModified!,
                                );
                                final now = DateTime.now();
                                final difference = now.difference(date);

                                if (difference.inDays == 0) {
                                  formattedDate = "Today";
                                } else if (difference.inDays == 1) {
                                  formattedDate = "Yesterday";
                                } else if (difference.inDays < 7) {
                                  formattedDate =
                                      "${difference.inDays} days ago";
                                } else if (difference.inDays < 30) {
                                  formattedDate =
                                      "${(difference.inDays / 7).floor()} weeks ago";
                                } else {
                                  formattedDate =
                                      "${(difference.inDays / 30).floor()} months ago";
                                }
                              } catch (e) {
                                formattedDate = service.dateModified!;
                              }
                            }

                            final bookingId = service.serviceId ?? '';
                            return _serviceTile(
                              title: service.serviceTitle ?? "Service",
                              desc: service.category?.isNotEmpty == true
                                  ? service.category!
                                  : "No category",
                              tag: service.category?.isNotEmpty == true
                                  ? service.category!
                                  : "General",
                              updatedAt: formattedDate,
                              // Open the booking instead of a dead delete icon.
                              onTap: bookingId.isEmpty
                                  ? null
                                  : () => Get.to(() => CompanyBookingDetailScreen(
                                      bookingId: bookingId)),
                            );
                          }).toList(),
                        )
                      : _emptyState("No assigned services");
                }),

                const SizedBox(height: 24),

                // ---------------- Upcoming Trips ----------------
                _sectionTitle("Upcoming Trips"),
                const SizedBox(height: 12),
                ...(data.upcomingTrips.isNotEmpty
                    ? data.upcomingTrips.take(3).map((trip) {
                        return _tripTile(
                          id: trip.tripCode ?? "N/A",
                          route:
                              "${trip.pickupLocation ?? 'N/A'} to ${trip.deliveryLocation ?? 'N/A'}",
                          time:
                              "${trip.pickupDate?.split('T')[0] ?? ''} ${trip.pickupTime ?? ''}",
                          driver: trip.driverName ?? "Driver not assigned",
                          onManage: () {
                            Get.to(() => const TripPage());
                          },
                        );
                      }).toList()
                    : [_emptyState("No upcoming trips")]),

                const SizedBox(height: 40),
                Center(
                  child: Column(
                    children: [
                      Text(
                        "App v1.3.2",
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Terms & Conditions  •  Privacy Policy",
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ---------------- Helper Methods ----------------
  static String _formatCurrency(double amount) {
    if (amount >= 10000000) {
      return "${(amount / 10000000).toStringAsFixed(2)}Cr";
    } else if (amount >= 100000) {
      return "${(amount / 100000).toStringAsFixed(1)}L";
    } else if (amount >= 1000) {
      return "${(amount / 1000).toStringAsFixed(1)}k";
    }
    return amount.toStringAsFixed(0);
  }

  static String _formatNumber(double number) {
    if (number >= 1000) {
      return "${(number / 1000).toStringAsFixed(1)}k";
    }
    return number.toStringAsFixed(0);
  }

  static String _getMonthName(int month) {
    const months = [
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
    return months[month - 1];
  }

  static Widget _emptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(color: Colors.grey[500], fontSize: 14),
        ),
      ),
    );
  }

  // ---------------- Reusable Widgets ----------------
  static Widget _statCard(
    IconData icon,
    String title,
    String value,
    String subtitle,
    Color accentColor, {
    Color backgroundColor = Colors.white,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accentColor, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    color: accentColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _availabilityItem(
    String value,
    String label,
    Color color,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, color: color.withValues(alpha: 0.8), size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  static Widget _chip(String text, bool selected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? Colors.blue : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? Colors.blue : Colors.grey.shade300,
          width: selected ? 2 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: selected ? Colors.white : Colors.grey[700],
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          fontSize: 13,
        ),
      ),
    );
  }

  static Widget _professionalTile(
    String name,
    String role, {
    String imageUrl = "https://via.placeholder.com/150",
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade200, width: 2),
              ),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey[100],
                backgroundImage: NetworkImage(imageUrl),
                onBackgroundImageError: (_, __) {},
                child: imageUrl.isEmpty
                    ? const Icon(Icons.person, color: Colors.grey)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    role,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _jobCard(
    String title,
    String applicants,
    String likes,
    String city,
    double salary, {
    VoidCallback? onView,
    VoidCallback? onEdit,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (city.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              city,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (salary > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          "₹${_formatCurrency(salary)}",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _pill(applicants, Colors.blue.shade50, Colors.blue),
                    const SizedBox(height: 6),
                    _pill(likes, Colors.red.shade50, Colors.red),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _outlinedButtonWithAction("View", Colors.blue, onView),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _outlinedButtonWithAction("Edit", Colors.grey, onEdit),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _pill(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  static Widget _outlinedButtonWithAction(
    String text,
    Color color,
    VoidCallback? onPressed,
  ) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
        visualDensity: VisualDensity.compact,
      ),
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }

  static Widget _transactionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String amount,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
        ),
        trailing: Text(
          amount,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: amount.startsWith('-') ? Colors.red : Colors.green,
          ),
        ),
      ),
    );
  }

  static Widget _addButtonWithAction(
    String text,
    Color color,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  static Widget _serviceTile({
    required String title,
    required String desc,
    required String tag,
    required String updatedAt,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              desc,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      updatedAt,
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    ),
                  ],
                ),
                Row(
                  children: const [
                    Text(
                      'View',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFFF36969),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        color: Color(0xFFF36969), size: 18),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  static Widget _tripTile({
    required String id,
    required String route,
    required String time,
    required String driver,
    required VoidCallback onManage,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.local_shipping,
                    color: Colors.teal,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Trip #$id",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        route,
                        style: const TextStyle(
                          color: Colors.teal,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Departure",
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        time,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Driver",
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        driver,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: OutlinedButton(
                onPressed: onManage,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.blue),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  "Manage Trip",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  // Ranged Trip Completion Trend chart (custom bars, any bucket count).
  // Renders the backend-grouped points for the selected range; matches the web.
  // Ranged Trip Completion Trend chart.
  //
  // Layout note: the bar area is an Expanded + FractionallySizedBox, so bar
  // heights are a FRACTION of whatever space remains after the value and axis
  // labels are laid out. An earlier version computed the bar height from
  // `constraints.maxHeight - 34` while the column actually needed ~45px of
  // chrome, which overflowed the card by ~12px. This structure cannot overflow.
  Widget _buildRangedTrendChart(List<TrendPoint> points, bool loading) {
    const valueRowHeight = 18.0;
    const labelRowHeight = 22.0;
    const accent = Color(0xFFf36969);

    if (loading && points.isEmpty) {
      return const Center(
        child: SizedBox(
          height: 22,
          width: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: accent),
        ),
      );
    }

    if (points.isEmpty || points.every((p) => p.count == 0)) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart_rounded, size: 30, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text(
              'No completed trips in this period',
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    final maxCount =
        points.map((p) => p.count).fold<int>(1, (a, b) => a > b ? a : b);

    Widget bar(TrendPoint p) {
      // Give a non-zero bucket a visible minimum so "1" never renders as a sliver.
      final factor = p.count <= 0
          ? 0.0
          : (p.count / maxCount).clamp(0.08, 1.0).toDouble();

      return Column(
        children: [
          SizedBox(
            height: valueRowHeight,
            child: p.count > 0
                ? Text(
                    '${p.count}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF374151),
                    ),
                  )
                : null,
          ),
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: factor,
                child: Container(
                  width: 18,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xFFF9A8A8), accent],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: labelRowHeight,
            child: Text(
              p.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Comfortable slot width; scroll horizontally when the range has many
        // buckets (30-day / all-time) instead of squeezing them together.
        const minSlot = 42.0;
        final fits = constraints.maxWidth / points.length >= minSlot;
        final slot = fits ? constraints.maxWidth / points.length : minSlot;

        final row = Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: points
              .map((p) => SizedBox(width: slot, child: bar(p)))
              .toList(),
        );

        // Subtle baseline under the bars for a cleaner, more finished look.
        final chart = Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: labelRowHeight + 8,
              child: Container(height: 1, color: Colors.grey.shade200),
            ),
            row,
          ],
        );

        return fits
            ? chart
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(width: slot * points.length, child: chart),
              );
      },
    );
  }

  // Expense Overview Chart (Donut Chart)
  static Widget _buildExpenseOverviewChart(
    List<RecentTransaction> transactions,
  ) {
    if (transactions.isEmpty) {
      return Center(
        child: Text(
          "No expense data available",
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }

    // Group transactions
    final Map<String, double> categoryTotals = {};
    final Map<String, Color> categoryColors = {
      'Advance': Colors.purpleAccent,
      'Fuel': Colors.redAccent,
      'Challan': Colors.orangeAccent,
      'Food': Colors.amber,
      'Salary': Colors.green,
      'Enroute': Colors.lightBlue,
      'Maintenance': Colors.blueGrey,
    };

    for (var transaction in transactions) {
      final category = transaction.expenseType ?? 'Other';
      final amount = transaction.amount ?? 0.0;
      categoryTotals[category] = (categoryTotals[category] ?? 0.0) + amount;
    }

    if (categoryTotals.isEmpty) {
      return Center(
        child: Text(
          "No expense data available",
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }

    final expenses = categoryTotals.entries.map((entry) {
      return {
        'category': entry.key,
        'amount': entry.value,
        'color': categoryColors[entry.key] ?? Colors.grey,
      };
    }).toList();

    // Sort by amount descending
    expenses.sort(
      (a, b) => (b['amount'] as double).compareTo(a['amount'] as double),
    );

    final totalAmount = expenses.fold<double>(
      0,
      (sum, item) => sum + (item['amount'] as double),
    );

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: Stack(
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 4,
                  centerSpaceRadius: 60,
                  sections: expenses.map((expense) {
                    final amount = expense['amount'] as double;
                    final isLarge = amount / totalAmount > 0.15;
                    return PieChartSectionData(
                      value: amount,
                      title: isLarge
                          ? "${(amount / totalAmount * 100).toStringAsFixed(0)}%"
                          : "",
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      color: expense['color'] as Color,
                      radius: isLarge ? 50 : 40,
                    );
                  }).toList(),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Total",
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    Text(
                      // 2-decimal currency, matching the web donut (₹470.66) —
                      // no rounded-to-integer or float artifact.
                      FormatUtils.formatMoney(totalAmount),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Legend
        Wrap(
          spacing: 16,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: expenses.map((expense) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: expense['color'] as Color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  expense['category'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}
