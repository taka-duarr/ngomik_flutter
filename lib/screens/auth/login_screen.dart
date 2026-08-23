import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/clipboard_helper.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bookmark_provider.dart';
import '../../providers/history_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _inputCtrl = TextEditingController();
  late TabController _tabController;
  bool _autoDetected = false;
  bool _isCookieMode = true; // Default to Cookie mode (longer session)

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);
    _tabController.addListener(() {
      setState(() => _isCookieMode = _tabController.index == 0);
      _inputCtrl.clear();
      setState(() => _autoDetected = false);
      _checkClipboard();
    });
    _checkClipboard();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkClipboard() async {
    final clipText = await ClipboardHelper.getClipboardText();
    if (clipText == null || !mounted) return;
    final trimmed = clipText.trim();

    if (_isCookieMode && ClipboardHelper.isSupabaseCookie(trimmed)) {
      setState(() {
        _inputCtrl.text = trimmed;
        _autoDetected = true;
      });
    } else if (!_isCookieMode && ClipboardHelper.isShinigamiToken(trimmed)) {
      setState(() {
        _inputCtrl.text = trimmed;
        _autoDetected = true;
      });
    }
  }

  Future<void> _pasteFromClipboard() async {
    final clipText = await ClipboardHelper.getClipboardText();
    if (clipText != null && clipText.isNotEmpty && mounted) {
      setState(() {
        _inputCtrl.text = clipText.trim();
        _autoDetected = _isCookieMode
            ? ClipboardHelper.isSupabaseCookie(clipText)
            : ClipboardHelper.isShinigamiToken(clipText);
      });
    }
  }

  Future<void> _submitLogin() async {
    if (_inputCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isCookieMode
              ? 'Silakan tempel cookie Supabase Anda.'
              : 'Silakan masukkan token otorisasi.'),
        ),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    bool success;

    if (_isCookieMode) {
      success =
          await authProvider.loginWithSupabaseCookie(_inputCtrl.text.trim());
    } else {
      success = await authProvider.loginWithToken(_inputCtrl.text.trim());
    }

    if (success && mounted) {
      if (authProvider.token != null) {
        context
            .read<BookmarkProvider>()
            .syncRemoteBookmarks(authProvider.token!);
        context.read<HistoryProvider>().syncRemoteHistory(authProvider.token!);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '✅ Selamat datang, ${authProvider.user?.username ?? "Pembaca"}! Sesi aktif ~60 hari.'),
          backgroundColor: AppColors.emerald,
          duration: const Duration(seconds: 3),
        ),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(authProvider.errorMessage ?? 'Gagal menghubungkan akun.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hubungkan Akun',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Header
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    image: const DecorationImage(
                      image: AssetImage('assets/images/logo.png'),
                      fit: BoxFit.cover,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Masuk Akun Shinigami',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sinkronkan bookmark & riwayat baca dengan akun resmimu.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Tab Selector
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.6), width: 1),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: AppColors.primaryLight,
              unselectedLabelColor: AppColors.textMuted,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
              tabs: const [
                Tab(
                  icon: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cookie_outlined, size: 15),
                      SizedBox(width: 5),
                      Text('Cookie (Rekomendasi)'),
                    ],
                  ),
                ),
                Tab(
                  icon: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.key_outlined, size: 15),
                      SizedBox(width: 5),
                      Text('Bearer Token'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Duration badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _isCookieMode
                  ? AppColors.emerald.withValues(alpha: 0.12)
                  : Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isCookieMode
                    ? AppColors.emerald.withValues(alpha: 0.35)
                    : Colors.orange.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isCookieMode
                      ? Icons.verified_rounded
                      : Icons.warning_amber_rounded,
                  size: 16,
                  color: _isCookieMode ? AppColors.emerald : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isCookieMode
                        ? '✅ Login via Cookie: Sesi aktif ±60 hari — tidak perlu login ulang!'
                        : '⚠️ Bearer Token hanya berlaku ±1 jam sebelum kedaluwarsa.',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _isCookieMode ? AppColors.emerald : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Auto-detected badge
          if (_autoDetected) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.emerald.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.emerald.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.emerald, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isCookieMode
                          ? '🍪 Cookie Shinigami terdeteksi otomatis dari Clipboard!'
                          : '✨ Token Shinigami terdeteksi otomatis dari Clipboard!',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.emerald),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Input Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isCookieMode ? 'Cookie Sesi Supabase' : 'Bearer Token',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary),
                    ),
                    TextButton.icon(
                      onPressed: _pasteFromClipboard,
                      icon: const Icon(Icons.paste_rounded,
                          size: 14, color: AppColors.primaryLight),
                      label: const Text('Tempel',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryLight)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _inputCtrl,
                  maxLines: 3,
                  style: const TextStyle(
                      fontSize: 11, fontFamily: 'monospace', color: Colors.white),
                  onChanged: (_) => setState(() => _autoDetected = false),
                  decoration: InputDecoration(
                    hintText: _isCookieMode
                        ? 'Tempel cookie di sini\n(sb-kratos-auth-token.0=base64-eyJ...)'
                        : 'Tempel token di sini (v4.public...)',
                    hintStyle: const TextStyle(
                        fontSize: 11, color: AppColors.textDisabled),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: authProvider.isLoading ? null : _submitLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: authProvider.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(
                            _autoDetected
                                ? (_isCookieMode
                                    ? '🍪 Cookie Terdeteksi! Login Sekarang'
                                    : '✨ Token Terdeteksi! Hubungkan Sekarang')
                                : (_isCookieMode
                                    ? 'Login via Cookie (±60 Hari)'
                                    : 'Hubungkan Bearer Token'),
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Tutorial
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _isCookieMode
                          ? Icons.cookie_outlined
                          : Icons.help_outline_rounded,
                      color: _isCookieMode ? AppColors.emerald : AppColors.cyan,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isCookieMode
                          ? 'Cara Ambil Cookie (Sekali, Valid ~60 Hari)'
                          : 'Cara Ambil Bearer Token',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (_isCookieMode) ...[
                  // Cara termudah: Console
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('⚡ Cara Paling Mudah (Console)',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryLight)),
                        const SizedBox(height: 6),
                        _buildStep('1',
                            'Buka 11.shinigami.asia & Login → tekan F12'),
                        _buildStep(
                            '2', 'Klik tab Console → ketik perintah ini:'),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const SelectableText(
                            'copy(document.cookie)',
                            style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                                color: AppColors.emerald),
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildStep('3',
                            'Tekan Enter → Cookie otomatis tersalin ke clipboard!'),
                        _buildStep('4',
                            'Kembali ke app → Tempel → aplikasi detect otomatis → Login!'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Alternatif: Application tab
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('📋 Cara Alternatif (Application Tab)',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary)),
                        const SizedBox(height: 6),
                        _buildStep(
                            '1', 'F12 → tab Application → Cookies → pilih URL'),
                        _buildStep('2',
                            'Cari sb-kratos-auth-token.0 (HARUS yang .0, bukan .1!)'),
                        _buildStep('3',
                            'Klik 2× Value → Ctrl+A → Ctrl+C → Tempel ke aplikasi'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.emerald.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.emerald.withValues(alpha: 0.25)),
                    ),
                    child: const Text(
                      '✅ Cookie berlaku ±60 hari — jauh lebih lama dari Bearer Token (1 jam)!\n⚠️ Jangan salin bagian .1 saja — harus .0 atau full document.cookie!',
                      style: TextStyle(
                          fontSize: 11.5, color: AppColors.emerald, height: 1.4),
                    ),
                  ),
                ] else ...[
                  _buildStep(
                      '1', 'Buka 11.shinigami.asia & pastikan sudah login.'),
                  _buildStep('2', 'Tekan F12 → Tab Network.'),
                  _buildStep('3', 'Buka halaman Bookmark di web.'),
                  _buildStep(
                      '4', 'Klik request list?page=1... → Tab Headers.'),
                  _buildStep('5',
                      'Salin teks authorization: Bearer v4.public...'),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.25)),
                    ),
                    child: const Text(
                      '⚠️ Bearer Token hanya berlaku ±1 jam. Gunakan mode Cookie di tab sebelumnya untuk sesi yang jauh lebih lama!',
                      style: TextStyle(
                          fontSize: 11.5, color: Colors.orange, height: 1.4),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.5), width: 1),
            ),
            alignment: Alignment.center,
            child: Text(num,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryLight)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.45)),
          ),
        ],
      ),
    );
  }
}
