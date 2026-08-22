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
  bool _isLoading = false;
  String? _errorMessage;

  User? get user => _user;
  String? get token => _token;
  bool get isLoggedIn => _user != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> init() async {
    _token = await _storageService.getToken();
    _user = await _storageService.getUser();
    notifyListeners();

    if (_token != null && _token!.isNotEmpty) {
      await refreshProfile();
    }
  }

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
      _errorMessage = 'Gagal memverifikasi akun: ';
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
    } catch (_) {}
  }

  Future<void> logout() async {
    _user = null;
    _token = null;
    await _storageService.clearToken();
    notifyListeners();
  }
}
