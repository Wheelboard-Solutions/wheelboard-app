import 'dart:io';
import 'package:dio/dio.dart' as dio;
import 'package:get/get.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import 'package:wheelboard/core/auth/auth_service.dart';
import '../../models/feed_model.dart';
import '../../services/media_service.dart';
import '../../utils/app_logger.dart';
import '../../widgets/custom_snackbar.dart';

// Re-export the feed models so existing `import '.../post_controller.dart'`
// consumers keep seeing `Post` / `FeedComment` / `FeedAuthor`.
export '../../models/feed_model.dart';

/// Canonical feed controller. A 1:1 mirror of the FE `feedsAPI`
/// (`wheelboard-fe/src/lib/api.ts`) and `useFeeds` hook.
///
/// All requests are JSON and derive the user from the auth token — no `userId`
/// is sent in any body (the backend rejects non-whitelisted fields).
class PostController extends GetxController {
  var isLoading = false.obs;
  var isCreatingPost = false.obs;
  var posts = <Post>[].obs;
  var stats = Rxn<FeedStats>();

  // Pagination + filtering (mirrors the FE feed list).
  var selectedCategory = 'all'.obs;
  var page = 1.obs;
  var totalPages = 1.obs;
  var total = 0.obs;

  @override
  void onInit() {
    super.onInit();
    _initWithAuth();
  }

  Future<void> _initWithAuth() async {
    await AuthService.to.refreshLoginStatus();
    await fetchFeeds();
    fetchStats();
  }

  /// GET /feeds — paginated, optional category filter.
  Future<void> fetchFeeds({String? category, int page = 1}) async {
    try {
      isLoading.value = true;

      final cat = category ?? selectedCategory.value;
      final params = <String, dynamic>{
        'page': page,
        'limit': 20,
        if (cat.isNotEmpty && cat != 'all') 'category': cat,
      };

      final data = await ApiClient.instance.get<Map<String, dynamic>>(
        ApiEndpoints.feeds.list,
        queryParameters: params,
      );

      final feedsList = data['feeds'] as List<dynamic>? ?? [];
      posts.value = feedsList
          .whereType<Map<String, dynamic>>()
          .map(Post.fromJson)
          .toList();
      this.page.value = (data['page'] as num?)?.toInt() ?? page;
      totalPages.value = (data['totalPages'] as num?)?.toInt() ?? 1;
      total.value = (data['total'] as num?)?.toInt() ?? posts.length;
      selectedCategory.value = cat;
      AppLogger.d("✅ Fetched ${posts.length} feeds (category: $cat)");
    } on dio.DioException catch (e) {
      AppLogger.e("❌ Failed to fetch feeds: ${_msg(e)}");
    } catch (e) {
      AppLogger.e("❌ Error fetching feeds: $e");
    } finally {
      isLoading.value = false;
    }
  }

  /// GET /feeds/stats — community statistics.
  Future<void> fetchStats() async {
    try {
      final data = await ApiClient.instance.get<Map<String, dynamic>>(
        ApiEndpoints.feeds.stats,
      );
      stats.value = FeedStats.fromJson(data);
    } catch (e) {
      AppLogger.d("ℹ️ Failed to fetch feed stats: $e");
    }
  }

  /// Filter the feed by category ('all' clears the filter).
  Future<void> setCategory(String category) async {
    await fetchFeeds(category: category, page: 1);
  }

  /// Upload a post image via the unified /media endpoint → hosted URL.
  Future<String?> uploadImage(File file) async {
    final media = await MediaService.upload(file, folder: 'feed-images');
    return media?.url;
  }

  /// Create a feed post. Mirrors the FE flow exactly: the image is uploaded
  /// first (on the compose screen, via [uploadImage] → `/media` → hosted URL),
  /// then `POST /feeds` carries that hosted URL string as `image`.
  ///
  /// Pass [imageUrl] when the image was already uploaded on the compose screen
  /// (preferred — matches the web's upload-on-select). [images] is a fallback
  /// that uploads on submit.
  Future<bool> createPost({
    required String content,
    required String category,
    List<File>? images,
    String? imageUrl,
  }) async {
    try {
      isCreatingPost.value = true;

      String? finalImageUrl = imageUrl;
      if ((finalImageUrl == null || finalImageUrl.isEmpty) &&
          images != null &&
          images.isNotEmpty) {
        // A failed photo upload shouldn't sink the whole post — mirrors the
        // web app, where a bad image only affects the image, not the text +
        // category submission.
        try {
          finalImageUrl = await uploadImage(images.first);
        } catch (e) {
          AppLogger.e("❌ Photo upload failed, posting without photo: $e");
          SnackBarHelper.warning("Photo upload failed — posting without photo");
        }
      }

      final feed = await ApiClient.instance.post<Map<String, dynamic>>(
        ApiEndpoints.feeds.create,
        data: {
          'content': content,
          'category': category,
          if (finalImageUrl != null && finalImageUrl.isNotEmpty)
            'image': finalImageUrl,
        },
      );

      posts.insert(0, Post.fromJson(feed));
      total.value += 1;
      fetchStats();
      SnackBarHelper.success("Post created successfully!");
      return true;
    } on dio.DioException catch (e) {
      AppLogger.e("❌ Error creating post: $e");
      SnackBarHelper.error(_msg(e, fallback: 'Failed to create post'));
      return false;
    } catch (e) {
      AppLogger.e("❌ Error creating post: $e");
      SnackBarHelper.error("Failed to create post: $e");
      return false;
    } finally {
      isCreatingPost.value = false;
    }
  }

  /// PATCH /feeds/:id — update own post (content / category / image URL).
  Future<bool> updateFeed(
    String id, {
    String? content,
    String? category,
    String? image,
  }) async {
    try {
      final feed = await ApiClient.instance.patch<Map<String, dynamic>>(
        ApiEndpoints.feeds.update(id),
        data: {
          if (content != null) 'content': content,
          if (category != null) 'category': category,
          if (image != null) 'image': image,
        },
      );
      _replacePost(Post.fromJson(feed));
      SnackBarHelper.success("Post updated");
      return true;
    } on dio.DioException catch (e) {
      SnackBarHelper.error(_msg(e, fallback: 'Failed to update post'));
      return false;
    } catch (e) {
      SnackBarHelper.error("Failed to update post: $e");
      return false;
    }
  }

  /// DELETE /feeds/:id — delete own post.
  Future<bool> deleteFeed(String id) async {
    try {
      await ApiClient.instance.delete<dynamic>(ApiEndpoints.feeds.delete(id));
      posts.removeWhere((p) => p.id == id);
      total.value = total.value > 0 ? total.value - 1 : 0;
      fetchStats();
      SnackBarHelper.success("Post deleted");
      return true;
    } on dio.DioException catch (e) {
      SnackBarHelper.error(_msg(e, fallback: 'Failed to delete post'));
      return false;
    } catch (e) {
      SnackBarHelper.error("Failed to delete post: $e");
      return false;
    }
  }

  /// POST /feeds/:id/like — toggle like (no body). Returns success.
  Future<bool> toggleLike(String id) async {
    // Optimistic update.
    final index = posts.indexWhere((p) => p.id == id);
    Post? original;
    if (index != -1) {
      original = posts[index];
      final newLiked = !original.isLiked;
      posts[index] = original.copyWith(
        isLiked: newLiked,
        likes: newLiked
            ? original.likes + 1
            : (original.likes > 0 ? original.likes - 1 : 0),
      );
      posts.refresh();
    }

    try {
      final data = await ApiClient.instance.post<Map<String, dynamic>>(
        ApiEndpoints.feeds.toggleLike(id),
      );
      // Reconcile with the server's authoritative counts.
      if (index != -1) {
        posts[index] = posts[index].copyWith(
          likes: (data['likes'] as num?)?.toInt(),
          isLiked: data['isLiked'] as bool?,
        );
        posts.refresh();
      }
      return true;
    } on dio.DioException catch (e) {
      if (original != null && index != -1) {
        posts[index] = original; // revert
        posts.refresh();
      }
      AppLogger.e("❌ Failed to toggle like: ${_msg(e)}");
      return false;
    } catch (e) {
      if (original != null && index != -1) {
        posts[index] = original;
        posts.refresh();
      }
      return false;
    }
  }

  /// Legacy alias retained for callers that expect a boolean toggle.
  Future<bool> togglePostLike(String postId) => toggleLike(postId);

  /// POST /feeds/:id/comment — add a comment; returns the updated feed.
  Future<bool> addComment(String id, String content) async {
    try {
      final feed = await ApiClient.instance.post<Map<String, dynamic>>(
        ApiEndpoints.feeds.addComment(id),
        data: {'content': content},
      );
      _replacePost(Post.fromJson(feed));
      return true;
    } on dio.DioException catch (e) {
      SnackBarHelper.error(_msg(e, fallback: 'Failed to add comment'));
      return false;
    } catch (e) {
      SnackBarHelper.error("Failed to add comment: $e");
      return false;
    }
  }

  /// DELETE /feeds/:id/comment/:commentId — delete own comment.
  Future<bool> deleteComment(String feedId, String commentId) async {
    try {
      final feed = await ApiClient.instance.delete<Map<String, dynamic>>(
        ApiEndpoints.feeds.deleteComment(feedId, commentId),
      );
      _replacePost(Post.fromJson(feed));
      return true;
    } on dio.DioException catch (e) {
      SnackBarHelper.error(_msg(e, fallback: 'Failed to delete comment'));
      return false;
    } catch (e) {
      SnackBarHelper.error("Failed to delete comment: $e");
      return false;
    }
  }

  /// POST /feeds/:id/share — increment share count.
  Future<bool> shareFeed(String id) async {
    try {
      final data = await ApiClient.instance.post<Map<String, dynamic>>(
        ApiEndpoints.feeds.share(id),
      );
      final index = posts.indexWhere((p) => p.id == id);
      if (index != -1) {
        posts[index] = posts[index].copyWith(
          shares: (data['shares'] as num?)?.toInt(),
        );
        posts.refresh();
      }
      return true;
    } catch (e) {
      AppLogger.d("ℹ️ Failed to record share: $e");
      return false;
    }
  }

  /// POST /feeds/:id/report — report a post.
  Future<bool> reportFeed(String id, String reason) async {
    try {
      await ApiClient.instance.post<dynamic>(
        ApiEndpoints.feeds.report(id),
        data: {'reason': reason},
      );
      SnackBarHelper.success("Post reported. Thank you.");
      return true;
    } on dio.DioException catch (e) {
      SnackBarHelper.error(_msg(e, fallback: 'Failed to report post'));
      return false;
    } catch (e) {
      SnackBarHelper.error("Failed to report post: $e");
      return false;
    }
  }

  /// Blocks [userId]: the server hides their posts and comments from this
  /// user's feed from now on; their posts already loaded are dropped here.
  Future<bool> blockUser(String userId) async {
    try {
      await ApiClient.instance.post<dynamic>(
        ApiEndpoints.feeds.blockUser(userId),
      );
      final blocked = userId.toUpperCase();
      posts.removeWhere((p) => p.author.id.toUpperCase() == blocked);
      SnackBarHelper.success("User blocked. You won't see their posts.");
      return true;
    } on dio.DioException catch (e) {
      SnackBarHelper.error(_msg(e, fallback: 'Failed to block user'));
      return false;
    } catch (e) {
      SnackBarHelper.error("Failed to block user: $e");
      return false;
    }
  }

  Future<void> refreshPosts() async {
    await fetchFeeds(category: selectedCategory.value, page: 1);
    await fetchStats();
  }

  // ── Legacy aliases ────────────────────────────────────────────────────────
  Future<void> fetchUserPosts() => fetchFeeds();

  void _replacePost(Post updated) {
    final index = posts.indexWhere((p) => p.id == updated.id);
    if (index != -1) {
      posts[index] = updated;
      posts.refresh();
    }
  }

  /// `ApiException` is never actually attached to `DioException.error` by the
  /// interceptor, so `e.error is ApiException` was always false — read the
  /// backend's real validation message straight from the response body.
  String _msg(dio.DioException e, {String fallback = 'Something went wrong'}) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      final m = data['message'];
      return m is List ? m.join(', ') : m.toString();
    }
    return fallback;
  }
}
