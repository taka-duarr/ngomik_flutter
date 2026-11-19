import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/shngm_api_service.dart';
import '../services/storage_service.dart';
import '../core/utils/clipboard_helper.dart';

class AuthProvider with ChangeNotifier {
  final ShngmApiService _apiService = ShngmApiService();
  final StorageService _storageService = StorageService();

  User? _user;
  String? _token;
  String? _refreshToken;
  int? _tokenExpiresAt; // Unix timestamp (seconds)
  bool _isLoading = false;
  String? _errorMessage;

  User? get user => _user;
  String? get token => _token;
  String? get refreshToken => _refreshToken;
  bool get isLoggedIn => _user != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// True if the access_token is expired or will expire within 5 minutes
  bool get isTokenExpired {
    if (_token == null || _token!.isEmpty) return true;

    int? exp = _tokenExpiresAt;
    if (exp == null) {
      exp = ClipboardHelper.getJwtExpiration(_token!);
      if (exp != null) {
        _tokenExpiresAt = exp;
        _storageService.saveTokenExpiresAt(exp);
      }
    }

    if (exp == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now >= (exp - 300); // 5-minute buffer before expiry
  }

  /// True if user has a valid refresh token (session can be extended)
  bool get hasRefreshToken =>
      _refreshToken != null && _refreshToken!.isNotEmpty;

  Future<void> init() async {
    _token = await _storageService.getToken();
    _refreshToken = await _storageService.getRefreshToken();
    _tokenExpiresAt = await _storageService.getTokenExpiresAt();
    _user = await _storageService.getUser();

    // Auto-extract exp from token if missing in storage
    if (_token != null && _tokenExpiresAt == null) {
      final exp = ClipboardHelper.getJwtExpiration(_token!);
      if (exp != null) {
        _tokenExpiresAt = exp;
        await _storageService.saveTokenExpiresAt(exp);
      }
    }

    // Auto-refresh expired token using refresh token on startup
    if (isTokenExpired && hasRefreshToken) {
      debugPrint('Stored access token expired on startup, refreshing silently...');
      await refreshTokenSilently();
    } else if (_token != null && _token!.isNotEmpty && !isTokenExpired) {
      await refreshProfile();
    }

    notifyListeners();
  }

  /// Returns a valid, active access token.
  /// Automatically refreshes silently if expired or expiring soon.
  Future<String?> getValidToken() async {
    if (_token == null || _token!.isEmpty) return null;

    if (isTokenExpired && hasRefreshToken) {
      debugPrint('Access token is expired or near expiry, refreshing...');
      final success = await refreshTokenSilently();
      if (success) {
        return _token;
      }
    }
    return _token;
  }

  /// Silently refresh the token using WorkOS refresh token
  Future<bool> refreshTokenSilently() async {
    if (_refreshToken == null || _refreshToken!.isEmpty) {
      _refreshToken = await _storageService.getRefreshToken();
    }

    if (_refreshToken != null && _refreshToken!.isNotEmpty) {
      try {
        debugPrint('Attempting silent token refresh via WorkOS API...');
        final res = await _apiService.refreshWorkosToken(_refreshToken!);
        if (res != null) {
          final newAccess = res['access_token']?.toString();
          final newRefresh = res['refresh_token']?.toString() ?? _refreshToken;
          if (newAccess != null && newAccess.isNotEmpty) {
            final exp = ClipboardHelper.getJwtExpiration(newAccess);
            _token = newAccess;
            _refreshToken = newRefresh;
            _tokenExpiresAt = exp;

            await _storageService.saveToken(newAccess);
            if (newRefresh != null) await _storageService.saveRefreshToken(newRefresh);
            if (exp != null) await _storageService.saveTokenExpiresAt(exp);

            if (_user != null) {
              _user = _user!.copyWith(token: newAccess);
              await _storageService.saveUser(_user!);
            }

            debugPrint('WorkOS token refreshed successfully! Expires at: $exp');
            notifyListeners();
            return true;
          }
        }
      } catch (e) {
        debugPrint('refreshTokenSilently error: $e');
      }
    }

    return false;
  }

  /// Comprehensive session saver for WorkOS & Shinigami
  Future<bool> saveSession({
    required String accessToken,
    String? refreshToken,
    int? expiresAt,
    Map<String, dynamic>? userMap,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final clean = ClipboardHelper.cleanToken(accessToken);
      int? exp = expiresAt;
      if (exp == null || exp <= 0) {
        exp = ClipboardHelper.getJwtExpiration(clean);
      }

      // Assign tokens to instance variables first so onTokenRefresh can work if needed
      _token = clean;
      _refreshToken = refreshToken;
      _tokenExpiresAt = exp;

      User? profile;
      try {
        profile = await _apiService.fetchUserProfile(clean);
      } catch (_) {}

      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final isExpired = exp != null && exp < nowSec;

      // If token expired, profile failed, and no refresh token, fail gracefully
      if (profile == null && userMap == null && isExpired && (refreshToken == null || refreshToken.isEmpty)) {
        _token = null;
        _refreshToken = null;
        _tokenExpiresAt = null;
        _errorMessage = 'Sesi telah kedaluwarsa. Silakan login kembali.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (profile != null) {
        _user = profile.copyWith(token: clean);
      } else if (userMap != null) {
        final userId = (userMap['id'] ?? userMap['user_id'] ?? '').toString();
        final username = (userMap['name'] ?? userMap['first_name'] ?? userMap['username'] ?? userMap['email'] ?? 'Pembaca').toString();
        final email = userMap['email']?.toString();
        final avatar = userMap['avatar']?.toString() ?? userMap['avatar_image_url']?.toString();
        _user = User(
          userId: userId,
          username: username,
          email: email,
          avatarImageUrl: avatar,
          token: clean,
        );
      } else if (_user != null) {
        _user = _user!.copyWith(token: clean);
      } else {
        _user = User(
          userId: 'user',
          username: 'Pembaca',
          token: clean,
        );
      }

      _token = clean;
      _refreshToken = refreshToken;
      _tokenExpiresAt = exp;

      await _storageService.saveToken(clean);
      await _storageService.saveUser(_user!);
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _storageService.saveRefreshToken(refreshToken);
      }
      if (exp != null) {
        await _storageService.saveTokenExpiresAt(exp);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('saveSession error: $e');
      _errorMessage = 'Gagal menyimpan sesi: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Login with Bearer token
  Future<bool> loginWithToken(String inputToken, {String? refreshToken, int? expiresAt}) async {
    return saveSession(
      accessToken: inputToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
    );
  }

  /// Login with token and pre-loaded user data (e.g. from web auth-storage)
  Future<bool> loginWithUserData(
    String inputToken,
    Map<String, dynamic> userMap, {
    String? refreshToken,
    int? expiresAt,
  }) async {
    return saveSession(
      accessToken: inputToken,
      userMap: userMap,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
    );
  }

  /// Login using a Supabase session cookie (lasts ~60 days)
  /// Accepts the full cookie string: "sb-kratos-auth-token.0=base64-eyJ..."
  Future<bool> loginWithSupabaseCookie(String cookieStr) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final session = ClipboardHelper.parseSupabaseCookie(cookieStr);
      if (session == null) {
        _errorMessage =
            'Cookie tidak lengkap atau terpotong.\n\n'
            'Gunakan: F12 → Console → ketik copy(document.cookie) → Enter';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final accessToken = session['access_token'] as String?;
      final refreshTok = session['refresh_token'] as String?;
      final expiresAt = session['expires_at'];

      if (accessToken == null || accessToken.isEmpty) {
        _errorMessage = 'Access token tidak ditemukan di dalam cookie.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Build User from JWT/session payload — no API call needed
      // Shinigami API uses Paseto tokens, not Supabase JWT
      final userJson = session['user'] as Map<String, dynamic>?;
      final userMeta = userJson?['user_metadata'] as Map<String, dynamic>?;

      final userId = userJson?['id']?.toString() ?? '';
      final email = userJson?['email']?.toString() ??
          userMeta?['email']?.toString() ?? '';
      final fullName = userMeta?['full_name']?.toString() ??
          userMeta?['name']?.toString() ??
          email.split('@').first;
      final avatarUrl = userMeta?['avatar_url']?.toString() ??
          userMeta?['picture']?.toString();
      final createdAt = userJson?['created_at']?.toString();

      if (userId.isEmpty) {
        _errorMessage = 'Data user tidak ditemukan dalam cookie. Coba copy ulang.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _user = User(
        userId: userId,
        username: fullName.isNotEmpty ? fullName : 'Pembaca',
        email: email,
        avatarImageUrl: avatarUrl,
        token: accessToken,
        registrationDate: createdAt,
      );
      _token = accessToken;
      _refreshToken = refreshTok;
      _tokenExpiresAt = expiresAt is int
          ? expiresAt
          : int.tryParse(expiresAt?.toString() ?? '');

      await _storageService.saveToken(accessToken);
      await _storageService.saveUser(_user!);
      if (_refreshToken != null) {
        await _storageService.saveRefreshToken(_refreshToken!);
      }
      if (_tokenExpiresAt != null) {
        await _storageService.saveTokenExpiresAt(_tokenExpiresAt!);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('loginWithSupabaseCookie error: $e');
      _errorMessage = 'Gagal memproses cookie: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshProfile() async {
    if (_token == null || _token!.isEmpty) return;
    try {
      final profile = await _apiService.fetchUserProfile(_token!);
      if (profile != null) {
        _user = profile.copyWith(token: _token);
        await _storageService.saveUser(_user!);
        notifyListeners();
      }
      // If 401, don't logout — just keep cached profile
    } catch (_) {}
  }

  Future<void> logout() async {
    _user = null;
    _token = null;
    _refreshToken = null;
    _tokenExpiresAt = null;
    await _storageService.clearToken();
    notifyListeners();
  }
}
