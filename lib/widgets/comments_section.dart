import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/date_formatter.dart';
import '../models/comment.dart';
import '../services/shngm_api_service.dart';
import '../providers/auth_provider.dart';
import 'app_network_image.dart';
import 'google_dots_loading.dart';

class CommentsSection extends StatefulWidget {
  final String path;
  final String title;
  final String? mangaId;
  final String? chapterId;

  const CommentsSection({
    super.key,
    required this.path,
    required this.title,
    this.mangaId,
    this.chapterId,
  });

  @override
  State<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<CommentsSection> {
  final ShngmApiService _apiService = ShngmApiService();
  final TextEditingController _commentCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<WalineComment> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;
  int _page = 1;
  int _totalPages = 1;
  int _totalCount = 0;
  bool _isLoadingMore = false;
  final Set<String> _expandedComments = {};
  final Set<String> _expandedReplies = {};
  WalineComment? _replyingToComment;

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  @override
  void didUpdateWidget(covariant CommentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _page = 1;
      _replyingToComment = null;
      _fetchComments();
    }
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startReply(WalineComment comment) {
    setState(() {
      _replyingToComment = comment;
    });
    _focusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingToComment = null;
    });
  }

  Future<void> _fetchComments({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
    }
    setState(() => _isLoading = _page == 1);

    final authProvider = context.read<AuthProvider>();
    final res = await _apiService.fetchComments(
      widget.path,
      page: _page,
      pageSize: 15,
      sortBy: 'like_desc',
      mangaId: widget.mangaId,
      chapterId: widget.chapterId,
      token: authProvider.token,
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
    final replyTarget = _replyingToComment;
    final int? rid = replyTarget != null ? int.tryParse(replyTarget.id) : null;

    setState(() => _isSending = true);

    final success = await _apiService.postComment(
      path: widget.path,
      comment: text,
      nick: nick,
      mail: email,
      mangaId: widget.mangaId,
      chapterId: widget.chapterId,
      rid: rid,
      token: authProvider.token,
    );

    if (mounted) {
      setState(() => _isSending = false);
      if (success) {
        _commentCtrl.clear();
        final repliedId = replyTarget?.id;
        setState(() {
          _replyingToComment = null;
          if (repliedId != null) {
            _expandedReplies.add(repliedId);
          }
        });
        FocusScope.of(context).unfocus();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(replyTarget != null ? 'Balasan berhasil dikirim!' : 'Komentar berhasil dikirim!'),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 2),
          ),
        );
        _fetchComments(refresh: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.token == null || authProvider.token!.isEmpty
                ? 'Gagal mengirim. Silakan login akun terlebih dahulu.'
                : 'Gagal mengirim balasan. Coba lagi.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _voteComment(WalineComment comment) async {
    final auth = context.read<AuthProvider>();
    final success = await _apiService.voteComment(
      comment.id,
      up: true,
      token: auth.token,
    );
    if (success && mounted) {
      setState(() {
        final idx = _comments.indexWhere((c) => c.id == comment.id);
        if (idx != -1) {
          _comments[idx] = _comments[idx].copyWith(like: _comments[idx].like + 1);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title (💬 Komentar Komik (1755))
          Row(
            children: [
              const Icon(
                Icons.chat_bubble_outline_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Komentar Komik (${_totalCount > 0 ? _totalCount : _comments.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // SPECULAR GLASS WRITE COMMENT BOX (Zero GPU lag)
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2A2F4C).withValues(alpha: 0.85),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.09),
                  Colors.white.withValues(alpha: 0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_replyingToComment != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.reply_rounded,
                          color: AppColors.primary,
                          size: 15,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Membalas @${_replyingToComment!.nick}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: _cancelReply,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white70,
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                TextField(
                  controller: _commentCtrl,
                  focusNode: _focusNode,
                  maxLines: 3,
                  minLines: 1,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: _replyingToComment != null
                        ? 'Balas @${_replyingToComment!.nick}...'
                        : 'Tulis komentar Anda di sini...',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 12.5,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    height: 34,
                    child: ElevatedButton.icon(
                      onPressed: _isSending ? null : _submitComment,
                      icon: _isSending
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _replyingToComment != null ? Icons.reply_rounded : Icons.send_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                      label: Text(
                        _replyingToComment != null ? 'Balas' : 'Kirim',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Comments List (Fast rendering with zero live BackdropFilter overhead)
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: GoogleDotsLoading(dotSize: 10, jumpHeight: 14),
              ),
            )
          else if (_comments.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 36,
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Belum ada komentar.\nJadilah yang pertama berkomentar!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: [
                ...List.generate(_comments.length, (index) {
                  final c = _comments[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index < _comments.length - 1 ? 12 : 0,
                    ),
                    child: _buildCommentCard(c),
                  );
                }),

                // Load more button
                if (_page < _totalPages) ...[
                  const SizedBox(height: 14),
                  Center(
                    child: TextButton.icon(
                      onPressed: _isLoadingMore ? null : _loadMore,
                      icon: _isLoadingMore
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            )
                          : const Icon(
                              Icons.expand_more_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                      label: const Text(
                        'Muat Komentar Lainnya',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCommentCard(WalineComment comment, {bool isReply = false}) {
    final isExpandedText = _expandedComments.contains(comment.id);
    final isExpandedReply = _expandedReplies.contains(comment.id);
    final text = comment.cleanComment;
    final isLongText = text.length > 220;

    return Container(
      decoration: BoxDecoration(
        color: isReply
            ? const Color(0xFF2A2F4C).withValues(alpha: 0.85)
            : const Color(0xFF1F2339).withValues(alpha: 0.90),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: isReply ? 0.08 : 0.10),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: isReply ? 0.10 : 0.15),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author Header: Avatar, Nickname, Level Badge, Time
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: comment.avatar != null && comment.avatar!.isNotEmpty
                    ? AppNetworkImage(
                        imageUrl: comment.avatar!,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 36,
                        height: 36,
                        color: AppColors.primary.withValues(alpha: 0.3),
                        child: Center(
                          child: Text(
                            comment.nick.isNotEmpty
                                ? comment.nick[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            comment.nick,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Lv. 1 Pill Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5A2350),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Lv. ${comment.level}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFFF6CB8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    if (comment.insertedAt != null)
                      Text(
                        DateFormatter.timeAgo(comment.insertedAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Comment Text Body
          if (text.isNotEmpty) ...[
            Text(
              (!isExpandedText && isLongText)
                  ? '${text.substring(0, 220)}...'
                  : text,
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.white.withValues(alpha: 0.92),
                height: 1.5,
              ),
            ),
            if (isLongText)
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (isExpandedText) {
                      _expandedComments.remove(comment.id);
                    } else {
                      _expandedComments.add(comment.id);
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Text(
                    isExpandedText ? 'Tutup' : 'Lihat selengkapnya',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE2288E),
                    ),
                  ),
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

          const SizedBox(height: 10),

          // Action Buttons: Specular Glass Like Pill (❤ 103) & Reply Expander (⤷ Lihat 21 Balasan ⌄)
          Row(
            children: [
              // Specular Glass Like Pill
              GestureDetector(
                onTap: () => _voteComment(comment),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x33E2288E),
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFE2288E).withValues(alpha: 0.20),
                        const Color(0xFFE2288E).withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFB5186E).withValues(alpha: 0.7),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.favorite_rounded,
                        color: Color(0xFFFF6CB8),
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${comment.like}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFF6CB8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Balas Button
              GestureDetector(
                onTap: () => _startReply(comment),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 0.8,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.reply_rounded,
                        color: Colors.white70,
                        size: 13,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Balas',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Specular Glass Replies Button
          if (comment.replies.isNotEmpty) ...[
            const SizedBox(height: 10),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  setState(() {
                    if (isExpandedReply) {
                      _expandedReplies.remove(comment.id);
                    } else {
                      _expandedReplies.add(comment.id);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.10),
                        Colors.white.withValues(alpha: 0.02),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.subdirectory_arrow_right_rounded,
                        color: Colors.white70,
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Lihat ${comment.replies.length} Balasan',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        isExpandedReply
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Expanded Replies List
            if (isExpandedReply) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Column(
                  children: comment.replies
                      .map(
                        (r) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildCommentCard(r, isReply: true),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
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
