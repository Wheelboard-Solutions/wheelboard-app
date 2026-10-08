import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../widgets/custom_snackbar.dart';

// Design tokens (match the Legal/Settings screens)
const _primary = Color(0xFFF36969);
const _bg = Color(0xFFF9FAFB);
const _card = Colors.white;
const _textDark = Color(0xFF111827);
const _textGrey = Color(0xFF6B7280);
const _border = Color(0xFFE5E7EB);

class _BlockedUser {
  final String id;
  final String name;
  final String initials;

  const _BlockedUser({
    required this.id,
    required this.name,
    required this.initials,
  });

  factory _BlockedUser.fromJson(Map<String, dynamic> json) => _BlockedUser(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Wheelboard user',
        initials: json['initials']?.toString() ?? 'U',
      );
}

/// Lists users blocked from the community feed and lets the user unblock them.
class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<_BlockedUser> _users = [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final data = await ApiClient.instance
          .get<Map<String, dynamic>>(ApiEndpoints.feeds.blockedUsers);
      final list = (data['users'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_BlockedUser.fromJson)
          .toList();
      if (mounted) setState(() => _users = list);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unblock(_BlockedUser user) async {
    try {
      await ApiClient.instance
          .delete<dynamic>(ApiEndpoints.feeds.blockUser(user.id));
      setState(() => _users.removeWhere((u) => u.id == user.id));
      SnackBarHelper.success('${user.name} unblocked');
    } on dio.DioException {
      SnackBarHelper.error('Failed to unblock ${user.name}');
    }
  }

  void _confirmUnblock(_BlockedUser user) {
    Get.dialog(
      AlertDialog(
        title: Text('Unblock ${user.name}?'),
        content: const Text(
          'Their posts and comments will show in your feed again.',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Get.back();
              _unblock(user);
            },
            child: const Text('Unblock', style: TextStyle(color: _primary)),
          ),
        ],
      ),
    );
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
        title: Text('Blocked users',
            style: GoogleFonts.poppins(
                fontSize: 17, fontWeight: FontWeight.w700, color: _textDark)),
        centerTitle: true,
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }
    if (_failed) {
      return _message(
        'Could not load blocked users',
        action: TextButton(onPressed: _load, child: const Text('Retry')),
      );
    }
    if (_users.isEmpty) {
      return _message(
        "You haven't blocked anyone",
        detail: 'Block someone from the ••• menu on their post.',
      );
    }
    return RefreshIndicator(
      color: _primary,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _users.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _tile(_users[i]),
      ),
    );
  }

  Widget _tile(_BlockedUser user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: const Color(0xFFFFF1F1),
          child: Text(user.initials,
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600, color: _primary)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(user.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w500, color: _textDark)),
        ),
        OutlinedButton(
          onPressed: () => _confirmUnblock(user),
          style: OutlinedButton.styleFrom(
            foregroundColor: _primary,
            side: const BorderSide(color: _primary),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Unblock'),
        ),
      ]),
    );
  }

  Widget _message(String title, {String? detail, Widget? action}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.block_rounded, size: 40, color: _textGrey),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w600, color: _textDark)),
          if (detail != null) ...[
            const SizedBox(height: 6),
            Text(detail,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 13, color: _textGrey)),
          ],
          if (action != null) ...[const SizedBox(height: 8), action],
        ]),
      ),
    );
  }
}
