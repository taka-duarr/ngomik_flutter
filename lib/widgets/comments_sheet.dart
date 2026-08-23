import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/date_formatter.dart';
import '../models/comment.dart';
import '../services/shngm_api_service.dart';
import '../providers/auth_provider.dart';
import 'app_network_image.dart';
import 'google_dots_loading.dart';
import 'liquid_glass_container.dart';

class CommentsSheet extends StatefulWidget {
  final String path;
  final String title;

  const CommentsSheet({super.key, required this.path, required this.title});

  static void show(
    BuildContext context, {
    required String path,
    required String title,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(path: path, title: title),
    );
  }

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final ShngmApiService _apiService = ShngmApiService();
  final TextEditingController _commentCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<WalineComment> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;
  int _page = 1;
  int _totalPages = 1;
  int _totalCount = 0;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchComments({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
    }
    setState(() => _isLoading = _page == 1);

    final res = await _apiService.fetchComments(
      widget.path,
      page: _page,
      pageSize: 20,
    );

    if (mounted) {
      setState(() {
        if (_page == 1) {
          _comments = res.comments;
        } else {
          _comments.addAll(res.comments);
        }
        _totalPages = res.totalPages;
        _totalCount = res.totalRecords;
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _page >= _totalPages) return;
    setState(() {
      _isLoadingMore = true;
      _page++;
    });
    await _fetchComments();
  }

  Future<void> _submitComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || _isSending) return;

    final authProvider = context.read<AuthProvider>();
    final nick = authProvider.user?.username ?? 'Pembaca';
    final email = authProvider.user?.email ?? '';

    setState(() => _isSending = true);

    final success = await _apiService.postComment(
      path: widget.path,
      comment: text,
      nick: nick,
      mail: email,
    );

    if (mounted) {
      setState(() => _isSending = false);
      if (success) {
        _commentCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Komentar berhasil dikirim!'),
            backgroundColor: AppColors.primary,
            duration: Duration(seconds: 2),
          ),
        );
        _fetchComments(refresh: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mengirim komentar. Coba lagi.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.78,
      margin: EdgeInsets.only(bottom: bottomInset),
      child: LiquidGlassContainer(
        borderRadius: 24,
        blur: 24,
        color: const Color(0xF00D111A),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            // Sheet Drag Handle & Title
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Komentar (${_totalCount > 0 ? _totalCount : _comments.length})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white70,
                          size: 20,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.border, height: 1),

            // Comments List Body
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: GoogleDotsLoading(dotSize: 11, jumpHeight: 14),
                    )
                  : _comments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 48,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Belum ada komentar.\nJadilah yang pertama berkomentar!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount:
                          _comments.length + (_page < _totalPages ? 1 : 0),
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        if (index == _comments.length) {
                          return Center(
                            child: TextButton(
                              onPressed: _isLoadingMore ? null : _loadMore,
                              child: _isLoadingMore
                                  ? const GoogleDotsLoading(
                                      dotSize: 8,
                                      jumpHeight: 10,
                                    )
                                  : const Text(
                                      'Muat Komentar Lainnya',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5,
                                      ),
                                    ),
                            ),
                          );
                        }

                        final c = _comments[index];
                        return _buildCommentTile(c);
                      },
                    ),
            ),

            // Bottom Input Bar
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                border: const Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                      child: TextField(
                        controller: _commentCtrl,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Tulis komentar...',
                          hintStyle: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12.5,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.primaryGradient,
                    ),
                    child: IconButton(
                      icon: _isSending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                      onPressed: _isSending ? null : _submitComment,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentTile(WalineComment comment) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author Header: Avatar, Nickname, Time
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: comment.avatar != null && comment.avatar!.isNotEmpty
                    ? AppNetworkImage(
                        imageUrl: comment.avatar!,
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 32,
                        height: 32,
                        color: AppColors.primary.withValues(alpha: 0.2),
                        child: Center(
                          child: Text(
                            comment.nick.isNotEmpty
                                ? comment.nick[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.nick,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    if (comment.insertedAt != null)
                      Text(
                        DateFormatter.timeAgo(comment.insertedAt),
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Comment Text Body
          if (comment.cleanComment.isNotEmpty) ...[
            Text(
              comment.cleanComment,
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.white.withValues(alpha: 0.88),
                height: 1.45,
              ),
            ),
          ],

          // Attached Images & Emotes / Stickers
          if (comment.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final img in comment.imageUrls) _buildCommentMedia(img),
              ],
            ),
          ],

          // Nested Replies
          if (comment.replies.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(
                children: comment.replies
                    .map((r) => _buildCommentTile(r))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _isEmoteOrSticker(String url) {
    final lower = url.toLowerCase();
    return lower.contains('emoji') ||
        lower.contains('sticker') ||
        lower.contains('pepe') ||
        lower.contains('alu') ||
        lower.contains('aru') ||
        lower.contains('tieba') ||
        lower.contains('bilibili') ||
        lower.contains('weibo') ||
        lower.contains('qq') ||
        lower.contains('blob') ||
        lower.contains('emot') ||
        lower.contains('menhera') ||
        lower.contains('twemoji') ||
        lower.contains('bplus') ||
        lower.contains('wl-emoji') ||
        lower.contains('/sticker/') ||
        lower.contains('/stickers/') ||
        lower.contains('/emojis/') ||
        lower.contains('/emoji/');
  }

  void _showImagePreview(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AppNetworkImage(imageUrl: imageUrl, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentMedia(String url) {
    final isSticker = _isEmoteOrSticker(url);

    if (isSticker) {
      return Container(
        constraints: const BoxConstraints(
          maxWidth: 80,
          maxHeight: 80,
          minWidth: 44,
          minHeight: 44,
        ),
        child: AppNetworkImage(
          imageUrl: url,
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
        ),
      );
    }

    // Regular image: keep it large and clear with full width & zoom support
    return GestureDetector(
      onTap: () => _showImagePreview(url),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AppNetworkImage(
            imageUrl: url,
            width: double.infinity,
            fit: BoxFit.fitWidth,
            alignment: Alignment.center,
          ),
        ),
      ),
    );
  }
}
