class User {
  final String userId;
  final String username;
  final String? email;
  final String? avatarImageUrl;
  final String? token;
  final bool isPremium;
  final int bookmarkCount;
  final int historyCount;
  final String? registrationDate;

  const User({
    required this.userId,
    required this.username,
    this.email,
    this.avatarImageUrl,
    this.token,
    this.isPremium = false,
    this.bookmarkCount = 0,
    this.historyCount = 0,
    this.registrationDate,
  });

  factory User.fromJson(Map<String, dynamic> json, {String? token}) {
    return User(
      userId: json['user_id']?.toString() ?? json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? json['name']?.toString() ?? 'Pembaca',
      email: json['email']?.toString(),
      avatarImageUrl: json['avatar_image_url']?.toString() ?? json['avatar']?.toString(),
      token: token ?? json['token']?.toString(),
      isPremium: json['is_premium'] == true,
      bookmarkCount: int.tryParse(json['bookmark_count']?.toString() ?? '0') ?? 0,
      historyCount: int.tryParse(json['history_count']?.toString() ?? '0') ?? 0,
      registrationDate: json['registration_date']?.toString() ?? json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'username': username,
        'email': email,
        'avatar_image_url': avatarImageUrl,
        'token': token,
        'is_premium': isPremium,
        'bookmark_count': bookmarkCount,
        'history_count': historyCount,
        'registration_date': registrationDate,
      };

  User copyWith({
    String? userId,
    String? username,
    String? email,
    String? avatarImageUrl,
    String? token,
    bool? isPremium,
    int? bookmarkCount,
    int? historyCount,
    String? registrationDate,
  }) {
    return User(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      email: email ?? this.email,
      avatarImageUrl: avatarImageUrl ?? this.avatarImageUrl,
      token: token ?? this.token,
      isPremium: isPremium ?? this.isPremium,
      bookmarkCount: bookmarkCount ?? this.bookmarkCount,
      historyCount: historyCount ?? this.historyCount,
      registrationDate: registrationDate ?? this.registrationDate,
    );
  }
}
