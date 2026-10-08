import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

import '../../controllers/Transport/job_controller.dart';
import '../../models/job_model.dart';
import '../../models/job_stats_model.dart';
import '../../utils/share_service.dart';
import '../../widgets/custom_loader.dart';
import '../CompanyTransport/job_application_screen.dart';
import '../CompanyTransport/job_form_screen.dart';
import '../CompanyTransport/hired_professionals_screen.dart';

// Design tokens
const _primary = Color(0xFFF36969);
const _primaryLt = Color(0xFFFFF1F1);
const _bg = Color(0xFFF9FAFB);
const _card = Colors.white;
const _textDark = Color(0xFF111827);
const _textGrey = Color(0xFF6B7280);
const _border = Color(0xFFE5E7EB);
const _green = Color(0xFF22C55E);
const _amber = Color(0xFFF59E0B);
const _blue = Color(0xFF3B82F6);
const _purple = Color(0xFF7C3AED);
const _red = Color(0xFFEF4444);

/// Service Provider Jobs screen — mirrors `/business/jobs` on web.
///
/// Service providers (businesses) can create job listings for Technicians /
/// Helpers (not Drivers — the form already filters that via [isServiceProvider]).
class SpJobScreen extends StatefulWidget {
  const SpJobScreen({super.key});

  @override
  State<SpJobScreen> createState() => _SpJobScreenState();
}

class _SpJobScreenState extends State<SpJobScreen> {
  late final JobController _ctrl;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _filterStatus = 'All';

  static const _statusFilters = ['All', 'Active', 'Paused', 'Closed'];

  @override
  void initState() {
    super.initState();
    _ctrl = Get.isRegistered<JobController>()
        ? Get.find<JobController>()
        : Get.put(JobController(), permanent: false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ctrl.refreshJobs());
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<JobModel> get _filtered {
    final q = _searchQuery.toLowerCase();
    return _ctrl.jobs.where((j) {
      final matchSearch = q.isEmpty ||
          j.title.toLowerCase().contains(q) ||
          j.city.toLowerCase().contains(q) ||
          j.type.toLowerCase().contains(q);
      final matchStatus = _filterStatus == 'All' || j.status == _filterStatus;
      return matchSearch && matchStatus;
    }).toList();
  }

  Future<void> _confirmDelete(JobModel job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _SpDeleteDialog(
          jobTitle: job.title.isNotEmpty ? job.title : job.type),
    );
    if (confirmed == true) {
      _ctrl.deleteJob(job.jobId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _card,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: _border,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _textDark, size: 20),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'My Job Listings',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _textDark,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Hired Professionals',
            icon: const Icon(Iconsax.people, color: _textDark),
            onPressed: () => Get.to(() => const HiredProfessionalsScreen()),
          ),
        ],
      ),
      body: Obx(() {
        if (_ctrl.isLoading.value && _ctrl.jobs.isEmpty) {
          return const Center(child: CustomLoader(message: 'Loading jobs…'));
        }

        return RefreshIndicator(
          onRefresh: _ctrl.refreshJobs,
          color: _primary,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              // Stats grid
              Obx(() {
                final stats = _ctrl.stats.value;
                if (stats == null) return const SizedBox.shrink();
                final totalViews =
                    _ctrl.jobs.fold<int>(0, (s, j) => s + j.views);
                return _SpStatsGrid(stats: stats, totalViews: totalViews);
              }),
              const SizedBox(height: 16),

              // Search bar
              _SpSearchBar(controller: _searchCtrl),
              const SizedBox(height: 10),

              // Filter chips
              _SpFilterChips(
                selected: _filterStatus,
                options: _statusFilters,
                onSelected: (s) => setState(() => _filterStatus = s),
              ),
              const SizedBox(height: 14),

              // Job cards
              Obx(() {
                final jobs = _filtered;
                if (jobs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: const BoxDecoration(
                              color: _primaryLt,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Iconsax.briefcase,
                                size: 38, color: _primary),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _searchQuery.isNotEmpty || _filterStatus != 'All'
                                ? 'No jobs match your filters'
                                : 'No jobs posted yet',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: _textDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _searchQuery.isNotEmpty || _filterStatus != 'All'
                                ? 'Try adjusting your search or filters'
                                : 'Tap "Post Job" below to create your first listing.',
                            style:
                                GoogleFonts.poppins(fontSize: 14, color: _textGrey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Column(
                  children: jobs.asMap().entries.map((e) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: e.key < jobs.length - 1 ? 14 : 0,
                      ),
                      child: _SpJobCard(
                        job: e.value,
                        ctrl: _ctrl,
                        onEdit: () async {
                          await Get.to(
                              () => PostJobScreen(jobToEdit: e.value));
                          _ctrl.refreshJobs();
                        },
                        onTap: () => Get.to(() =>
                            JobApplicationsScreen(jobId: e.value.jobId)),
                        onDelete: () => _confirmDelete(e.value),
                      ),
                    );
                  }).toList(),
                );
              }),
            ],
          ),
        );
      }),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _primary,
        onPressed: () async {
          await Get.to(() => const PostJobScreen());
          _ctrl.refreshJobs();
        },
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
        label: Text(
          'Post Job',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Stats grid ────────────────────────────────────────────────────────────────

class _SpStatsGrid extends StatelessWidget {
  final JobStats stats;
  final int totalViews;
  const _SpStatsGrid({required this.stats, required this.totalViews});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: [
        _statCard('${stats.totalJobs}', 'Total Jobs', Iconsax.briefcase,
            _primary, _primaryLt),
        _statCard('${stats.activeJobs}', 'Active Jobs', Iconsax.tick_circle,
            _green, const Color(0xFFDCFCE7)),
        _statCard('${stats.totalApplications}', 'Applications',
            Iconsax.user_octagon, _blue, const Color(0xFFDBEAFE)),
        _statCard('$totalViews', 'Total Views', Iconsax.eye, _purple,
            const Color(0xFFEDE9FE)),
      ],
    );
  }

  Widget _statCard(String value, String label, IconData icon, Color color,
      Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _textDark,
                    height: 1.1,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.poppins(fontSize: 10, color: _textGrey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────

class _SpSearchBar extends StatelessWidget {
  final TextEditingController controller;
  const _SpSearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (_, value, __) {
        return Container(
          height: 46,
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            style: GoogleFonts.poppins(fontSize: 13, color: _textDark),
            decoration: InputDecoration(
              hintText: 'Search by title, type or city…',
              hintStyle: GoogleFonts.poppins(fontSize: 13, color: _textGrey),
              prefixIcon: const Icon(Icons.search_rounded,
                  size: 20, color: Color(0xFF9CA3AF)),
              suffixIcon: value.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded,
                          size: 18, color: Color(0xFF9CA3AF)),
                      onPressed: () => controller.clear(),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        );
      },
    );
  }
}

// ── Filter chips ──────────────────────────────────────────────────────────────

class _SpFilterChips extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;
  const _SpFilterChips({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: options.map((o) {
        final isActive = o == selected;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => onSelected(o),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? _primary : _card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isActive ? _primary : _border),
              ),
              child: Text(
                o,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : _textGrey,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Job card ──────────────────────────────────────────────────────────────────

class _SpJobCard extends StatelessWidget {
  final JobModel job;
  final JobController ctrl;
  final VoidCallback onEdit;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SpJobCard({
    required this.job,
    required this.ctrl,
    required this.onEdit,
    required this.onTap,
    required this.onDelete,
  });

  Color _statusColor(String s) {
    switch (s) {
      case 'Active':
        return _green;
      case 'Paused':
        return _amber;
      default:
        return _textGrey;
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              job.title.isNotEmpty ? job.title : job.type,
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: _textDark,
                              ),
                            ),
                          ),
                          if (job.urgent) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [
                                  Color(0xFFF97316),
                                  Color(0xFFEF4444),
                                ]),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.trending_up,
                                      size: 10, color: Colors.white),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Urgent',
                                    style: GoogleFonts.poppins(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        job.duration.isNotEmpty ? job.duration : 'Permanent',
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: _textGrey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Status dropdown
                Obx(() {
                  final current = ctrl.jobs.firstWhere(
                      (j) => j.jobId == job.jobId,
                      orElse: () => job);
                  final status =
                      current.status.isNotEmpty ? current.status : 'Active';
                  final color = _statusColor(status);
                  return PopupMenuButton<String>(
                    tooltip: 'Change status',
                    onSelected: (s) => ctrl.updateJobStatus(job.jobId, s),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'Active', child: Text('Active')),
                      PopupMenuItem(value: 'Paused', child: Text('Paused')),
                      PopupMenuItem(value: 'Closed', child: Text('Closed')),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            status,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                          Icon(Icons.arrow_drop_down, size: 14, color: color),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          // ── Info grid: City | Type | Salary | Date ────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Column(
              children: [
                Row(children: [
                  _infoChip(Icons.location_on_outlined, job.city,
                      const Color(0xFFF3F4F6), _textDark),
                  const SizedBox(width: 8),
                  _infoChip(Icons.work_outline, job.type,
                      const Color(0xFFEFF6FF), _blue),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  _infoChip(
                      Icons.currency_rupee_outlined,
                      job.salary.isNotEmpty ? job.salary : '—',
                      const Color(0xFFF0FDF4),
                      _green),
                  const SizedBox(width: 8),
                  _infoChip(Icons.calendar_today_outlined,
                      _formatDate(job.createdAt), const Color(0xFFF5F3FF), _purple),
                ]),
              ],
            ),
          ),

          // ── Stats strip ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: Obx(() {
                final appCount = ctrl.getApplicationCount(job.jobId);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _miniStat(Iconsax.user_octagon, '$appCount',
                        'Applications', _primary),
                    Container(width: 1, height: 28, color: _border),
                    _miniStat(Iconsax.eye, '${job.views}', 'Views', _blue),
                    Container(width: 1, height: 28, color: _border),
                    _miniStat(Iconsax.document, '${job.openings}',
                        'Openings', _green),
                  ],
                );
              }),
            ),
          ),

          // ── Action buttons ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: _border)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _actionBtn(
                    icon: Iconsax.eye,
                    label: 'Applications',
                    color: _primary,
                    onTap: onTap,
                    filled: true,
                  ),
                ),
                const SizedBox(width: 8),
                _squareBtn(
                  icon: Iconsax.share,
                  color: _textGrey,
                  onTap: () => ShareService.shareJob(
                    jobId: job.jobId,
                    jobTitle: job.role,
                    city: job.city,
                    jobType: job.jobType,
                    jobDuration: job.jobDuration,
                    openings: job.openings,
                    salary: job.salary,
                    description: job.description,
                  ),
                ),
                const SizedBox(width: 8),
                _squareBtn(icon: Iconsax.edit, color: _blue, onTap: onEdit),
                const SizedBox(width: 8),
                _squareBtn(icon: Iconsax.trash, color: _red, onTap: onDelete),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, Color bg, Color fg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(IconData icon, String value, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 12, color: color),
          ),
          const SizedBox(width: 5),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _textDark,
            ),
          ),
        ]),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 9, color: _textGrey),
        ),
      ],
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: filled ? color : _card,
          borderRadius: BorderRadius.circular(10),
          border:
              filled ? null : Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: filled ? Colors.white : color),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: filled ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _squareBtn(
      {required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

// ── Delete confirmation dialog ─────────────────────────────────────────────────

class _SpDeleteDialog extends StatelessWidget {
  final String jobTitle;
  const _SpDeleteDialog({required this.jobTitle});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Iconsax.trash, size: 28, color: _red),
            ),
            const SizedBox(height: 16),
            Text(
              'Delete Job',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to delete "$jobTitle"? All applications will also be removed.',
              style: GoogleFonts.poppins(fontSize: 13, color: _textGrey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      side: BorderSide(color: _border),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _textGrey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: Text(
                      'Delete',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
