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

class CommentsSection extends StatefulWidget {
  final String path;
  final String title;

  const CommentsSection({
    super.key,
    required this.path,
    required this.title,
  });

  @override
  State<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<CommentsSection> {
  final ShngmApiService _apiService = ShngmApiService();
  final TextEditingController _commentCtrl = TextEditingController();

  List<WalineComment> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;
  int _page = 1;
  int _totalPages = 1;
  int _totalCount = 0;
  bool _isLoadingMore = false;
  final Set<String> _expandedComments = {};
  final Set<String> _expandedReplies = {};

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
      _fetchComments();
    }
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
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
      pageSize: 15,
      sortBy: 'like_desc',
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
        FocusScope.of(context).unfocus();
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title (💬 Komentar Komik (1755))
          Row(
            children: [
              const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 18),
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

          // LIQUID GLASS WRITE COMMENT BOX
          LiquidGlassContainer(
            borderRadius: 18,
            blur: 16,
            color: Colors.white.withValues(alpha: 0.07),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TextField(
                  controller: _commentCtrl,
                  maxLines: 3,
                  minLines: 1,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Tulis komentar Anda di sini...',
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
                SizedBox(
                  height: 34,
                  child: ElevatedButton.icon(
                    onPressed: _isSending ? null : _submitComment,
                    icon: _isSending
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, size: 13, color: Colors.white),
                    label: const Text(
                      'Kirim',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Comments List
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: GoogleDotsLoading(dotSize: 10, jumpHeight: 14)),
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
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _comments.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final c = _comments[index];
                return _buildCommentCard(c);
              },
            ),

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
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        )
                      : const Icon(Icons.expand_more_rounded, size: 18, color: AppColors.primary),
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
        ],
      ),
    );
  }

  Widget _buildCommentCard(WalineComment comment, {bool isReply = false}) {
    final isExpandedText = _expandedComments.contains(comment.id);
    final isExpandedReply = _expandedReplies.contains(comment.id);
    final text = comment.cleanComment;
    final isLongText = text.length > 220;

    return LiquidGlassContainer(
      borderRadius: 18,
      blur: 20,
      color: isReply ? Colors.black.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08),
      border: Border.all(
        color: Colors.white.withValues(alpha: isReply ? 0.12 : 0.18),
        width: 0.9,
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
                            comment.nick.isNotEmpty ? comment.nick[0].toUpperCase() : 'U',
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
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4C1D38),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Lv. ${comment.level}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFFF4D8D),
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
              (!isExpandedText && isLongText) ? '${text.substring(0, 220)}...' : text,
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
                      color: Color(0xFFFF0055),
                    ),
                  ),
                ),
              ),
          ],

          // Attached Images
          if (comment.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final img in comment.imageUrls)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AppNetworkImage(
                    imageUrl: img,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
          ],

          const SizedBox(height: 10),

          // Action Buttons: Liquid Glass Like Pill (❤ 103) & Reply Expander (⤷ Lihat 21 Balasan ⌄)
          Row(
            children: [
              // Liquid Glass Like Pill
              LiquidGlassContainer(
                borderRadius: 16,
                blur: 14,
                color: const Color(0x66331422),
                border: Border.all(
                  color: const Color(0xFF8B2550).withValues(alpha: 0.7),
                  width: 0.8,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.favorite_rounded, color: Color(0xFFFF4D8D), size: 13),
                    const SizedBox(width: 4),
                    Text(
                      '${comment.like}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFF4D8D),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Liquid Glass Replies Button
          if (comment.replies.isNotEmpty) ...[
            const SizedBox(height: 10),
            LiquidGlassContainer(
              borderRadius: 12,
              blur: 14,
              color: Colors.white.withValues(alpha: 0.08),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              onTap: () {
                setState(() {
                  if (isExpandedReply) {
                    _expandedReplies.remove(comment.id);
                  } else {
                    _expandedReplies.add(comment.id);
                  }
                });
              },
              child: Row(
                children: [
                  const Icon(Icons.subdirectory_arrow_right_rounded, color: Colors.white70, size: 15),
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
                    isExpandedReply ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                ],
              ),
            ),

            // Expanded Replies List
            if (isExpandedReply) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Column(
                  children: comment.replies
                      .map((r) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildCommentCard(r, isReply: true),
                          ))
                      .toList(),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
