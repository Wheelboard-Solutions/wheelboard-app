import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wheelboard/constants/apps_colors.dart';
import 'package:wheelboard/screens/CompanyTransport/fleet_userprofile.dart';
import 'package:wheelboard/core/auth/auth_service.dart';
import '../CompanyTransport/new_post_screen.dart';
import '../../controllers/Transport/post_controller.dart';
import '../../widgets/custom_loader.dart';
import '../../widgets/smart_image.dart';
import '../../widgets/ui/app_ui.dart';
import '../../utils/share_service.dart';

/// Common Feed Screen — shared across Transport, Service Provider, and
/// Professional modules. Full feature parity with the web `FeedCard`:
/// likes, comments, share (counted), report, edit/delete (own posts),
/// category filter and community stats.
class CommonFeedScreen extends StatefulWidget {
  final bool showNewPostButton;
  const CommonFeedScreen({super.key, this.showNewPostButton = true});

  @override
  State<CommonFeedScreen> createState() => _CommonFeedScreenState();
}

class _CommonFeedScreenState extends State<CommonFeedScreen> {
  late final PostController postController;

  // 'all' + the backend feed categories.
  static const _categories = [
    'all',
    'Promotions',
    'tip',
    'services',
    'question',
    'general',
  ];

  @override
  void initState() {
    super.initState();
    postController = Get.isRegistered<PostController>()
        ? Get.find<PostController>()
        : Get.put(PostController());
  }

  String _label(String c) =>
      c == 'all' ? 'All' : c[0].toUpperCase() + c.substring(1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUi.scaffold,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        title: Image.asset('assets/headingImg.png', height: 40, fit: BoxFit.contain),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => postController.refreshPosts(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Community stats
          Obx(() {
            final stats = postController.stats.value;
            if (stats == null) return const SizedBox.shrink();
            return AppCard(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  StatTile(value: '${stats.totalMembers}', label: 'Members'),
                  StatTile(
                    value: '${stats.activeDiscussions}',
                    label: 'Discussions',
                    color: AppUi.blue,
                  ),
                  StatTile(
                    value: '${stats.postsThisWeek}',
                    label: 'This week',
                    color: AppUi.green,
                  ),
                ],
              ),
            );
          }),
          // Category filter
          Obx(
            () => AppFilterChips(
              options: _categories,
              selected: postController.selectedCategory.value,
              labelOf: _label,
              onSelected: postController.setCategory,
            ),
          ),
          Expanded(
            child: Obx(() {
              if (postController.isLoading.value && postController.posts.isEmpty) {
                return const CustomLoader(message: "Loading posts...");
              }
              if (postController.posts.isEmpty) {
                return const AppEmptyState(
                  icon: Icons.feed_outlined,
                  title: "No posts yet",
                  subtitle: "Be the first to share something with the community.",
                );
              }
              return RefreshIndicator(
                onRefresh: () => postController.refreshPosts(),
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100, top: 4),
                  itemCount: postController.posts.length,
                  itemBuilder: (context, index) => _FeedPostCard(
                    post: postController.posts[index],
                    controller: postController,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
      floatingActionButton: !widget.showNewPostButton
          ? null
          : Obx(() {
              final isProfessional = AuthService.to.isProfessional;
              if (isProfessional) return const SizedBox.shrink();
              return ElevatedButton.icon(
                onPressed: () {
                  Get.to(const NetworkPostScreen())?.then((result) {
                    if (result == true) postController.refreshPosts();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFD6C6C),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                icon: const Icon(Icons.add, color: AppColors.white, size: 18),
                label: const Text("New Post", style: TextStyle(color: AppColors.white)),
              );
            }),
    );
  }

}

/// A single feed post with the full engagement surface.
class _FeedPostCard extends StatefulWidget {
  final Post post;
  final PostController controller;
  const _FeedPostCard({required this.post, required this.controller});

  @override
  State<_FeedPostCard> createState() => _FeedPostCardState();
}

class _FeedPostCardState extends State<_FeedPostCard> {
  bool _showComments = false;
  final TextEditingController _commentCtrl = TextEditingController();

  Post get post => widget.post;
  PostController get controller => widget.controller;

  bool get _isOwner => post.author.id == AuthService.to.currentUserId;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Color get _categoryColor {
    switch (post.category) {
      case 'services':
        return const Color(0xFF3B82F6);
      case 'tip':
        return const Color(0xFF22C55E);
      case 'Promotions':
        return const Color(0xFF8B5CF6);
      case 'question':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 10),
          // Image first, then content — matches the web FeedCard layout.
          if (post.imageUrls.isNotEmpty) ...[
            _image(post.imageUrls.first),
            const SizedBox(height: 10),
          ],
          if (post.content.isNotEmpty)
            Text(post.content, style: const TextStyle(color: Colors.black87, fontSize: 14, height: 1.4)),
          const SizedBox(height: 10),
          _engagementCounts(),
          const Divider(height: 18),
          _actions(),
          if (_showComments) _commentsSection(),
        ],
      ),
    );
  }

  Widget _header() {
    final avatar = post.companyLogo;
    return Row(
      children: [
        InkWell(
          onTap: () => Get.to(() => FleetUserprofile(companyId: post.companyId)),
          borderRadius: BorderRadius.circular(25),
          child: _avatar(avatar, post.author.initials, 25),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      post.userName.isNotEmpty ? post.userName : "User",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (post.author.userType.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _userTypeBadge(post.author.userType),
                  ],
                ],
              ),
              if ((post.author.company ?? '').isNotEmpty)
                Text(
                  post.author.company!,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              Text(post.timeAgo, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ],
          ),
        ),
        if (post.category.isNotEmpty) _categoryBadge(),
        _moreMenu(),
      ],
    );
  }

  Widget _avatar(String? url, String initials, double radius) {
    if (url != null && url.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SmartImage(
          source: url,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          placeholder: _initialsAvatar(initials, radius),
        ),
      );
    }
    return _initialsAvatar(initials, radius);
  }

  Widget _initialsAvatar(String initials, double radius) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFFFE6E6),
      child: Text(
        initials.isNotEmpty ? initials : 'U',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: const Color(0xFFF25C5C),
          fontSize: radius * 0.7,
        ),
      ),
    );
  }

  Widget _userTypeBadge(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        type[0].toUpperCase() + type.substring(1),
        style: const TextStyle(fontSize: 9, color: Color(0xFF6B7280)),
      ),
    );
  }

  Widget _categoryBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _categoryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        post.category[0].toUpperCase() + post.category.substring(1),
        style: TextStyle(
          fontSize: 10,
          color: _categoryColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _moreMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz, size: 20, color: Colors.grey),
      onSelected: (value) {
        if (value == 'report') _showReportDialog();
        if (value == 'block') _confirmBlock();
        if (value == 'edit') _showEditDialog();
        if (value == 'delete') _confirmDelete();
      },
      itemBuilder: (_) => _isOwner
          ? const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ]
          : const [
              PopupMenuItem(value: 'report', child: Text('Report')),
              PopupMenuItem(value: 'block', child: Text('Block user')),
            ],
    );
  }

  Widget _image(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SmartImage(
        source: url,
        width: double.infinity,
        height: 220,
        fit: BoxFit.cover,
        placeholder: Container(
          height: 220,
          width: double.infinity,
          color: const Color(0xFFF3F4F6),
          alignment: Alignment.center,
          child: const Icon(Icons.image_outlined, color: Color(0xFF9CA3AF), size: 32),
        ),
      ),
    );
  }

  Widget _engagementCounts() {
    return Row(
      children: [
        Text(
          '${post.likes} ${post.likes == 1 ? 'like' : 'likes'}',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(width: 14),
        Text(
          '${post.commentCount} comments',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(width: 14),
        Text(
          '${post.shares} shares',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _actions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _actionButton(
          post.isLiked ? Icons.favorite : Icons.favorite_border,
          post.isLiked ? 'Liked' : 'Like',
          post.isLiked ? const Color(0xFFF36969) : Colors.grey[700]!,
          () => controller.toggleLike(post.id),
        ),
        _actionButton(
          Icons.mode_comment_outlined,
          'Comment',
          Colors.grey[700]!,
          () => setState(() => _showComments = !_showComments),
        ),
        _actionButton(
          Icons.share_outlined,
          'Share',
          Colors.grey[700]!,
          () async {
            await controller.shareFeed(post.id);
            await ShareService.sharePost(
              postId: post.id,
              content: post.content,
              userName: post.userName,
              category: post.category,
            );
          },
        ),
      ],
    );
  }

  Widget _actionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _commentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        ...post.comments.map(_commentTile),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentCtrl,
                decoration: InputDecoration(
                  hintText: 'Write a comment...',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  filled: true,
                  fillColor: const Color(0xFFF3F4F6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send, color: Color(0xFFF36969)),
              onPressed: () async {
                final text = _commentCtrl.text.trim();
                if (text.isEmpty) return;
                final ok = await controller.addComment(post.id, text);
                if (ok) _commentCtrl.clear();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _commentTile(FeedComment comment) {
    final isCommentOwner = comment.author.id == AuthService.to.currentUserId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _avatar(
            comment.author.avatar.isNotEmpty ? comment.author.avatar : null,
            comment.author.name.isNotEmpty
                ? comment.author.name.substring(0, 1).toUpperCase()
                : 'U',
            16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          comment.author.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Text(
                        comment.timeAgo,
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                      if (isCommentOwner)
                        GestureDetector(
                          onTap: () =>
                              controller.deleteComment(post.id, comment.id),
                          child: const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(Icons.close, size: 14, color: Colors.red),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(comment.content, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    const reasons = [
      'Spam or misleading',
      'Inappropriate content',
      'Harassment or bullying',
      'False information',
      'Violence or dangerous content',
      'Other',
    ];
    Get.bottomSheet(
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Report Post',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            ...reasons.map(
              (r) => ListTile(
                title: Text(r),
                onTap: () {
                  Get.back();
                  controller.reportFeed(post.id, r);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmBlock() {
    Get.dialog(
      AlertDialog(
        title: Text('Block ${post.author.name}?'),
        content: const Text(
          "You won't see their posts or comments in your feed.",
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Get.back();
              controller.blockUser(post.author.id);
            },
            child: const Text('Block', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog() {
    final contentCtrl = TextEditingController(text: post.content);
    String category = post.category.isNotEmpty ? post.category : 'general';
    Get.dialog(
      AlertDialog(
        title: const Text('Edit Post'),
        content: StatefulBuilder(
          builder: (context, setLocal) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: contentCtrl,
                maxLines: 4,
                decoration: const InputDecoration(hintText: 'Content'),
              ),
              const SizedBox(height: 12),
              DropdownButton<String>(
                value: category,
                isExpanded: true,
                items: const ['Promotions', 'tip', 'services', 'question', 'general']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setLocal(() => category = v ?? category),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Get.back();
              controller.updateFeed(
                post.id,
                content: contentCtrl.text.trim(),
                category: category,
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete() {
    Get.dialog(
      AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Get.back();
              controller.deleteFeed(post.id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

