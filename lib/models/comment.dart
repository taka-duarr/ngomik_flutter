class WalineComment {
  final String id;
  final String nick;
  final String comment;
  final String? avatar;
  final String? insertedAt;
  final int replyCount;
  final List<WalineComment> replies;

  const WalineComment({
    required this.id,
    required this.nick,
    required this.comment,
    this.avatar,
    this.insertedAt,
    this.replyCount = 0,
    this.replies = const [],
  });

  factory WalineComment.fromJson(Map<String, dynamic> json) {
    List<WalineComment> repList = [];
    if (json['children'] is List) {
      for (var c in json['children']) {
        if (c is Map<String, dynamic>) {
          repList.add(WalineComment.fromJson(c));
        }
      }
    }

    return WalineComment(
      id: json['objectId']?.toString() ?? json['id']?.toString() ?? '',
      nick: json['nick']?.toString() ?? 'Pembaca Anonim',
      comment: json['comment']?.toString() ?? '',
      avatar: json['avatar']?.toString(),
      insertedAt: json['insertedAt']?.toString() ?? json['created_at']?.toString(),
      replyCount: int.tryParse(json['reply_count']?.toString() ?? '0') ?? repList.length,
      replies: repList,
    );
  }
}
