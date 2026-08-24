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
    if (_token == null) return true;
    if (_tokenExpiresAt == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now >= (_tokenExpiresAt! - 300); // 5-min buffer
  }

  /// True if user has a valid refresh token (session can be extended)
  bool get hasRefreshToken =>
      _refreshToken != null && _refreshToken!.isNotEmpty;

  Future<void> init() async {
    _token = await _storageService.getToken();
    _refreshToken = await _storageService.getRefreshToken();
    _tokenExpiresAt = await _storageService.getTokenExpiresAt();
    _user = await _storageService.getUser();
    notifyListeners();

    // Try to refresh profile if token looks still valid (best-effort)
    if (_token != null && _token!.isNotEmpty && !isTokenExpired) {
      await refreshProfile();
    }
    // If token expired but we have user data, keep showing cached profile
    // (no force-logout)
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

  /// Legacy login with Bearer token (still supported)
  Future<bool> loginWithToken(String inputToken) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final clean = ClipboardHelper.cleanToken(inputToken);
      final profile = await _apiService.fetchUserProfile(clean);

      if (profile != null) {
        _user = profile.copyWith(token: clean);
        _token = clean;
        _refreshToken = null;
        _tokenExpiresAt = null;
        await _storageService.saveToken(clean);
        await _storageService.saveUser(_user!);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Token tidak valid atau sudah kedaluwarsa.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Gagal memverifikasi akun.';
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
