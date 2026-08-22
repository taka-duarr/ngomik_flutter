import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/clipboard_helper.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bookmark_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _tokenCtrl = TextEditingController();
  bool _autoDetected = false;
  String _guideTab = 'pc';

  @override
  void initState() {
    super.initState();
    _checkClipboard();
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkClipboard() async {
    final clipText = await ClipboardHelper.getClipboardText();
    if (ClipboardHelper.isShinigamiToken(clipText) && mounted) {
      setState(() {
        _tokenCtrl.text = clipText!.trim();
        _autoDetected = true;
      });
    }
  }

  Future<void> _pasteFromClipboard() async {
    final clipText = await ClipboardHelper.getClipboardText();
    if (clipText != null && clipText.isNotEmpty && mounted) {
      setState(() {
        _tokenCtrl.text = clipText.trim();
        _autoDetected = ClipboardHelper.isShinigamiToken(clipText);
      });
    }
  }

  Future<void> _submitLogin() async {
    if (_tokenCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan masukkan token otorisasi.')),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.loginWithToken(_tokenCtrl.text);

    if (success && mounted) {
      // Sync bookmarks immediately
      if (authProvider.token != null) {
        context.read<BookmarkProvider>().syncRemoteBookmarks(authProvider.token!);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selamat datang kembali, ${authProvider.user?.username ?? "Pembaca"}!'),
          backgroundColor: AppColors.emerald,
        ),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Gagal menghubungkan token.'),
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
        title: const Text('Hubungkan Akun', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Logo & Header
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sinkronkan bookmark komik & riwayat langsung dengan akun resmimu.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Auto-Detected Badge
          if (_autoDetected) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.emerald.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.emerald.withValues(alpha: 0.35)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: AppColors.emerald, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Token Shinigami otomatis terdeteksi dari Clipboard!',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.emerald),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Form Box
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
                    const Text(
                      'Token Otorisasi (Bearer)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                    ),
                    TextButton.icon(
                      onPressed: _pasteFromClipboard,
                      icon: const Icon(Icons.paste_rounded, size: 14, color: AppColors.primaryLight),
                      label: const Text(
                        'Tempel',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primaryLight),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _tokenCtrl,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Tempel token di sini (v4.public...)',
                    hintStyle: const TextStyle(fontSize: 12, color: AppColors.textDisabled),
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
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: authProvider.isLoading ? null : _submitLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: authProvider.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            _autoDetected ? '? Token Siap! Hubungkan Sekarang' : 'Hubungkan & Sinkronkan Akun',
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Tutorial Accordion
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
                const Row(
                  children: [
                    Icon(Icons.help_outline_rounded, color: AppColors.cyan, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Tutorial Cara Ambil Token di Web',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _guideTab = 'pc'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            decoration: BoxDecoration(
                              color: _guideTab == 'pc'
                                  ? AppColors.cyan.withValues(alpha: 0.25)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '?? Laptop / PC',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: _guideTab == 'pc' ? AppColors.cyan : AppColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _guideTab = 'hp'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            decoration: BoxDecoration(
                              color: _guideTab == 'hp'
                                  ? AppColors.primary.withValues(alpha: 0.25)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '?? HP Android',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: _guideTab == 'hp' ? AppColors.primaryLight : AppColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_guideTab == 'pc') ...[
                  const Text(
                    '1. Buka 11.shinigami.asia & pastikan sudah login.\n'
                    '2. Tekan F12 (Inspect Element) ? Tab Network.\n'
                    '3. Buka halaman Bookmark di web.\n'
                    '4. Klik list?page=1... ? Tab Headers.\n'
                    '5. Salin teks authorization: Bearer v4.public...',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
                  ),
                ] else ...[
                  const Text(
                    '1. Buka web Shinigami di Chrome/Kiwi/Brave HP.\n'
                    '2. Buka tab baru lalu salin kode berikut ke console:\n',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'copy(localStorage.token || document.cookie)',
                      style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.cyan),
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
}
