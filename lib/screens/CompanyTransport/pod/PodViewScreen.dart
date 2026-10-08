import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart' as dio;

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../../widgets/custom_snackbar.dart';

class PodViewScreen extends StatefulWidget {
  final String tripId;
  const PodViewScreen({super.key, required this.tripId});

  @override
  State<PodViewScreen> createState() => _PodViewScreenState();
}

class _PodViewScreenState extends State<PodViewScreen> {
  Map<String, dynamic>? _pod;
  bool _loading = true;
  String? _error;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _fetchPod();
  }

  Future<void> _fetchPod() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient.instance.get<Map<String, dynamic>>(
        ApiEndpoints.trips.podDetails(widget.tripId),
      );
      setState(() {
        final raw = res;
        if (raw['collection'] is Map<String, dynamic>) {
          // Backend nests POD details under `collection` — merge so UI can read fields at top-level
          final coll = Map<String, dynamic>.from(raw['collection'] as Map);
          final merged = Map<String, dynamic>.from(raw);
          merged.addAll(coll);
          _pod = merged;
        } else {
          _pod = raw;
        }
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Could not load proof of delivery.';
      });
    }
  }

  // ── verify / reject ───────────────────────────────────────────────────
  Future<void> _verifyPod({required bool approve}) async {
    setState(() => _isVerifying = true);
    try {
      await ApiClient.instance.patch(
        ApiEndpoints.trips.podVerify(widget.tripId),
        data: {
          'status': approve ? 'verified' : 'rejected',
          if (!approve) 'rejectionReason': 'Rejected by fleet owner',
        },
      );
      SnackBarHelper.success(
        approve ? 'POD verified successfully!' : 'POD rejected.');
      if (mounted) Get.back();
    } on dio.DioException catch (e) {
      final msg = e.error is ApiException
          ? (e.error as ApiException).message
          : (e.response?.data?['message'] as String?) ?? 'Operation failed.';
      SnackBarHelper.error(msg);
    } catch (_) {
      SnackBarHelper.error('An unexpected error occurred.');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  void _showVerifyDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 20),
          const Icon(Icons.assignment_turned_in, size: 48, color: Color(0xFF27AE60)),
          const SizedBox(height: 12),
          Text('Review Proof of Delivery',
            style: GoogleFonts.poppins(
              fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Choose whether to verify or reject this proof of delivery.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                _verifyPod(approve: false);
              },
              icon: const Icon(Icons.cancel_outlined, color: Colors.red),
              label: Text('Reject',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, color: Colors.red)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              ),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                _verifyPod(approve: true);
              },
              icon: const Icon(Icons.check_circle_outline),
              label: Text('Verify',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF27AE60),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            )),
          ]),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // ── data helpers ──────────────────────────────────────────────────────
  String _recipientName() =>
      (_pod?['recipientDetails']?['name'] as String?)
      ?? (_pod?['recipientName'] as String?)
      ?? 'N/A';

  String _recipientPhone() =>
      (_pod?['recipientDetails']?['phoneNumber'] as String?)
      ?? (_pod?['recipientPhone'] as String?)
      ?? 'N/A';

  String _deliveryNotes() =>
      (_pod?['deliveryNotes'] as String?) ?? '';

  String _podStatus() {
    final s = (_pod?['status'] as String?) ?? '';
    return s.isEmpty ? 'Pending Verification' : s.toUpperCase();
  }

  Color _podStatusColor() {
    final s = (_pod?['status'] as String?) ?? '';
    if (s == 'verified') return const Color(0xFF27AE60);
    if (s == 'rejected') return Colors.red;
    return const Color(0xFFF59E0B);
  }

  List<String> _photos() {
    final raw = _pod?['deliveryPhotos'];
    if (raw is List) return raw.whereType<String>().toList();
    return [];
  }

  bool get _isPendingVerification {
    final s = (_pod?['status'] as String?) ?? '';
    return s.isEmpty || s == 'pending' || s == 'collected';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFFFF5E5E)),
          onPressed: () => Get.back(),
        ),
        centerTitle: true,
        title: Text('Proof of Delivery',
          style: GoogleFonts.poppins(
            fontSize: 18, fontWeight: FontWeight.w600,
            color: const Color(0xFF1F2937))),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFFF5E5E)),
            onPressed: _fetchPod,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5E5E)))
          : _error != null
              ? _buildError()
              : _pod == null
                  ? _buildNoPod()
                  : _buildContent(),
      bottomNavigationBar: (!_loading && _pod != null && _isPendingVerification)
          ? _buildVerifyBar()
          : null,
    );
  }

  Widget _buildError() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, size: 64, color: Colors.red),
      const SizedBox(height: 16),
      Text(_error!,
        style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600])),
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: _fetchPod,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF5E5E)),
        child: const Text('Retry'),
      ),
    ]));
  }

  Widget _buildNoPod() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[400]),
      const SizedBox(height: 16),
      Text('No POD submitted yet',
        style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600])),
      const SizedBox(height: 8),
      Text('The driver hasn\'t uploaded proof of delivery.',
        style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[400])),
    ]));
  }

  Widget _buildContent() {
    final photos = _photos();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // status banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _podStatusColor().withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _podStatusColor().withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            Icon(
              _isPendingVerification
                  ? Icons.hourglass_empty
                  : (_pod?['status'] == 'verified'
                      ? Icons.verified
                      : Icons.cancel),
              color: _podStatusColor(), size: 28),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('POD Status',
                style: GoogleFonts.poppins(
                  fontSize: 11, color: Colors.grey[600])),
              Text(_podStatus(),
                style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w700,
                  color: _podStatusColor())),
            ]),
          ]),
        ),
        const SizedBox(height: 20),

        // delivery photos
        if (photos.isNotEmpty) ...[
          _sectionTitle('Delivery Photos', Icons.photo_library),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10,
              childAspectRatio: 1.2),
            itemCount: photos.length,
            itemBuilder: (_, i) => _photoTile(photos[i]),
          ),
          const SizedBox(height: 20),
        ],

        // recipient details
        _sectionTitle('Recipient Details', Icons.person_outline),
        const SizedBox(height: 12),
        _infoTile(Icons.person, 'Name', _recipientName()),
        const SizedBox(height: 8),
        _infoTile(Icons.phone, 'Phone', _recipientPhone()),
        if (_deliveryNotes().isNotEmpty) ...[
          const SizedBox(height: 8),
          _infoTile(Icons.note, 'Notes', _deliveryNotes()),
        ],
        const SizedBox(height: 80),
      ]),
    );
  }

  Widget _buildVerifyBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 12, offset: const Offset(0, -4))],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isVerifying ? null : _showVerifyDialog,
          icon: _isVerifying
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.rate_review_outlined),
          label: Text(
            _isVerifying ? 'Processing...' : 'Review & Verify POD',
            style: GoogleFonts.poppins(
              fontSize: 16, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF27AE60),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  // ── helpers ───────────────────────────────────────────────────────────
  Widget _sectionTitle(String title, IconData icon) {
    return Row(children: [
      Icon(icon, size: 18, color: const Color(0xFFFF5E5E)),
      const SizedBox(width: 8),
      Text(title, style: GoogleFonts.poppins(
        fontSize: 14, fontWeight: FontWeight.w600,
        color: const Color(0xFF1F2937))),
    ]);
  }

  Widget _photoTile(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          color: Colors.grey[100],
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 1.5))),
        errorWidget: (_, __, ___) => Container(
          color: Colors.grey[200],
          child: Icon(Icons.broken_image, color: Colors.grey[400])),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: Colors.grey[400]),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.poppins(
              fontSize: 10, color: Colors.grey[500])),
            Text(value, style: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w600,
              color: const Color(0xFF1F2937))),
          ],
        )),
      ]),
    );
  }
}
