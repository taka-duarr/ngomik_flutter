import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/manga.dart';
import '../models/user.dart';
import '../models/reading_history.dart';

class StorageService {
  static const String _keyToken = 'auth_token';
  static const String _keyUser = 'user_profile';
  static const String _keyBookmarks = 'user_bookmarks';
  static const String _keyHistory = 'reading_history';
  static const String _keyReadChapters = 'read_chapters';

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUser);
  }

  Future<void> saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUser, jsonEncode(user.toJson()));
  }

  Future<User?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyUser);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final map = jsonDecode(jsonStr);
        return User.fromJson(map as Map<String, dynamic>);
      } catch (_) {}
    }
    return null;
  }

  Future<void> saveBookmarks(List<Manga> bookmarks) async {
    final prefs = await SharedPreferences.getInstance();
    final list = bookmarks.map((m) => m.toJson()).toList();
    await prefs.setString(_keyBookmarks, jsonEncode(list));
  }

  Future<List<Manga>> getBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyBookmarks);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final list = jsonDecode(jsonStr);
        if (list is List) {
          return list.map((item) => Manga.fromJson(item as Map<String, dynamic>)).toList();
        }
      } catch (_) {}
    }
    return [];
  }

  Future<void> saveHistory(List<ReadingHistoryItem> history) async {
    final prefs = await SharedPreferences.getInstance();
    final list = history.map((h) => h.toJson()).toList();
    await prefs.setString(_keyHistory, jsonEncode(list));
  }

  Future<List<ReadingHistoryItem>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyHistory);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final list = jsonDecode(jsonStr);
        if (list is List) {
          return list.map((item) => ReadingHistoryItem.fromJson(item as Map<String, dynamic>)).toList();
        }
      } catch (_) {}
    }
    return [];
  }

  Future<void> markChapterRead(String chapterId, String mangaId) async {
    final prefs = await SharedPreferences.getInstance();
    final map = await getReadChapters();
    map[chapterId] = mangaId;
    await prefs.setString(_keyReadChapters, jsonEncode(map));
  }

  Future<Map<String, String>> getReadChapters() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyReadChapters);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final decoded = jsonDecode(jsonStr);
        if (decoded is Map) {
          return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
        }
      } catch (_) {}
    }
    return {};
  }
}
