import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/Transport/professional_list_controller.dart';
import '../../models/professional_profile_model.dart';
import '../../utils/media_url.dart';
import '../../widgets/custom_loader.dart';

class ProfessionalListScreen extends StatefulWidget {
  const ProfessionalListScreen({super.key});

  @override
  State<ProfessionalListScreen> createState() => _ProfessionalListScreenState();
}

class _ProfessionalListScreenState extends State<ProfessionalListScreen> {
  final ProfessionalListController controller = Get.put(
    ProfessionalListController(),
  );
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4E3E3),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Image.asset('assets/logobg.png', height: 40, width: 40),
            const SizedBox(width: 12),
            const Text(
              'WHEELBOARD',
              style: TextStyle(
                color: Color(0xFF1E1E1E),
                fontWeight: FontWeight.w600,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterRow(),
          const SizedBox(height: 16),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const CustomLoader(message: "Loading professionals...");
              }

              final professionals = controller.filteredProfessionals;

              return RefreshIndicator(
                onRefresh: controller.fetchProfessionalList,
                child: professionals.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: const [
                          SizedBox(height: 120),
                          Center(
                            child: Icon(
                              Icons.person_search,
                              size: 48,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: 16),
                          Center(
                            child: Text(
                              'No professionals found for this filter.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: professionals.length,
                        itemBuilder: (context, index) {
                          final professional = professionals[index];
                          final isFavorite =
                              controller.favoriteStatus[professional
                                  .driverId] ??
                              false;
                          return _ProfessionalCard(
                            professional: professional,
                            isFavorite: isFavorite,
                            onTap: () => _openProfessionalDetails(professional),
                            onToggleFavorite: () => controller.toggleFavorite(
                              professional.driverId,
                            ),
                            status: controller.selectedFilter.value,
                          );
                        },
                      ),
              );
            }),
          ),
        ],
      ),
      // floatingActionButton: FloatingActionButton.extended(
      //   onPressed: () {
      //     
      //   },
      //   backgroundColor: const Color(0xFFE83B4F),
      //   icon: const Icon(Icons.add, color: Colors.white),
      //   label: const Text(
      //     'Add New',
      //     style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      //   ),
      // ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: controller.updateSearchQuery,
                decoration: InputDecoration(
                  hintText: 'Search name, location...',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    const filters = ['ONBOARD', 'HIRED'];

    return Obx(() {
      final selectedFilter = controller.selectedFilter.value;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: filters.map((status) {
            final isSelected = selectedFilter == status;
            final isLast = status == filters.last;

            return Padding(
              padding: EdgeInsets.only(right: isLast ? 0 : 12),
              child: GestureDetector(
                onTap: () => controller.updateFilter(status),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFE83B4F)
                        : const Color(0xFFF3F3F4),
                    borderRadius: BorderRadius.circular(30),
                    border: isSelected
                        ? null
                        : Border.all(color: const Color(0xFFE83B4F), width: 1),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFFE83B4F),
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
    });
  }

  Future<void> _openProfessionalDetails(ProfessionalProfile summary) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CustomLoader.small()),
    );

    final details = await controller.fetchProfessionalDetails(summary.driverId);

    if (!mounted) return;

    Navigator.of(context).pop(); // close loader

    if (details == null) {
      return;
    }

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (_) => _ProfessionalDetailsSheet(profile: details),
    );
  }
}

class _ProfessionalCard extends StatelessWidget {
  final ProfessionalProfile professional;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final String status;

  const _ProfessionalCard({
    required this.professional,
    required this.isFavorite,
    required this.onTap,
    required this.onToggleFavorite,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _resolveImageUrl(professional.driverImagePath);
    final initials = _getInitials(professional.fullName);

    final isVerified =
        professional.fullName.hashCode % 2 ==
        0; // Keeping for now or remove if requested

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFFFFE6E6),
                    backgroundImage: avatarUrl != null
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: avatarUrl == null
                        ? Text(
                            initials,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF25C5C),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    professional.fullName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      color: Color(0xFF232325),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  // Show professional type (Driver, Helper, Technician)
                                  if (professional.professionalType.isNotEmpty)
                                    Text(
                                      professional.professionalType,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (isVerified)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE7F9EF),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.verified,
                                      color: Color(0xFF1AD07D),
                                      size: 14,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Verified',
                                      style: TextStyle(
                                        color: Color(0xFF1AD07D),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (professional.city.isNotEmpty)
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: Color(0xFFE83B4F),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                professional.city == "string"
                                    ? "Location not specified"
                                    : professional.city,
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _StatusChip(
                    label: status == 'ONBOARD' ? 'Onboard' : status,
                    isSelected: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool isSelected;

  const _StatusChip({required this.label, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFF3F3F4) : const Color(0x1AE83B4F),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFE83B4F),
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _ProfessionalDetailsSheet extends StatelessWidget {
  final ProfessionalProfile profile;

  const _ProfessionalDetailsSheet({required this.profile});

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _resolveImageUrl(profile.driverImagePath);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: CircleAvatar(
              radius: 45,
              backgroundColor: const Color(0xFFFFE6E6),
              backgroundImage: avatarUrl != null
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl == null
                  ? Text(
                      _getInitials(profile.fullName),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF25C5C),
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              profile.fullName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              profile.driverType,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 16),
          _detailsTile('Contact Number', profile.contactNumber),
          _detailsTile('Vehicle Number', profile.vehicleNumber),
          _detailsTile(
            'Description',
            profile.description.isNotEmpty
                ? profile.description
                : 'Not provided',
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF25C5C),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            label: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailsTile(String title, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

String? _resolveImageUrl(String? imagePath) => MediaUrl.resolveOrNull(imagePath);

String _getInitials(String name) {
  final parts = name
      .trim()
      .split(' ')
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'P';

  String first = parts.first;
  String last = parts.length > 1 ? parts.last : '';

  final firstChar = first.isNotEmpty ? first[0] : 'P';
  final lastChar = last.isNotEmpty ? last[0] : '';
  return (firstChar + lastChar).toUpperCase();
}
