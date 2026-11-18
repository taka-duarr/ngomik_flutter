import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/app_backdrop.dart';
import '../../core/utils/clipboard_helper.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bookmark_provider.dart';
import '../../providers/history_provider.dart';
import 'webview_login_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _inputCtrl = TextEditingController();
  bool _autoDetected = false;
  bool _isManualExpanded = false;

  @override
  void initState() {
    super.initState();
    _checkClipboard();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkClipboard() async {
    final clipText = await ClipboardHelper.getClipboardText();
    if (clipText == null || !mounted) return;
    final trimmed = clipText.trim();

    if (ClipboardHelper.isShinigamiToken(trimmed) || ClipboardHelper.isSupabaseCookie(trimmed)) {
      setState(() {
        _inputCtrl.text = trimmed;
        _autoDetected = true;
        _isManualExpanded = true;
      });
    }
  }

  Future<void> _pasteFromClipboard() async {
    final clipText = await ClipboardHelper.getClipboardText();
    if (clipText != null && clipText.isNotEmpty && mounted) {
      setState(() {
        _inputCtrl.text = clipText.trim();
        _autoDetected = ClipboardHelper.isShinigamiToken(clipText) || ClipboardHelper.isSupabaseCookie(clipText);
      });
    }
  }

  Future<void> _openWebViewLogin() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const WebViewLoginScreen()),
    );
    if (result == true && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _submitManualLogin() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan masukkan token atau cookie.')),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    bool success;

    if (ClipboardHelper.isSupabaseCookie(text)) {
      success = await authProvider.loginWithSupabaseCookie(text);
    } else {
      success = await authProvider.loginWithToken(text);
    }

    if (success && mounted) {
      if (authProvider.token != null) {
        context.read<BookmarkProvider>().syncRemoteBookmarks(authProvider.token!);
        context.read<HistoryProvider>().syncRemoteHistory(authProvider.token!);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Selamat datang, ${authProvider.user?.username ?? "Pembaca"}! Akun terhubung.'),
          backgroundColor: AppColors.emerald,
        ),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Gagal menghubungkan akun.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return AppBackdrop(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        titleSpacing: 0,
        title: const Text('Hubungkan Akun'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Logo & Header
          Center(
            child: Column(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    image: const DecorationImage(
                      image: AssetImage('assets/images/logo.png'),
                      fit: BoxFit.cover,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Masuk Akun Shinigami',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sinkronkan bookmark komik & riwayat baca secara otomatis.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // PRIMARY CARD: In-App WebView Auto-Login
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.25),
                  const Color(0xFF2A2F4C),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.auto_awesome, color: AppColors.accent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Login Otomatis via Web',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Paling Mudah • Anti Ribet',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.accent),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Buka halaman web Shinigami langsung di dalam aplikasi. Begitu kamu login dengan Google atau Email, sesi & token akan otomatis tersimpan!',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.45),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _openWebViewLogin,
                    icon: const Icon(Icons.open_in_browser_rounded, size: 18, color: Colors.white),
                    label: const Text(
                      'Buka Web & Login Otomatis',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 4,
                      shadowColor: AppColors.primary.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Collapsible Manual Input Accordion
          Container(
            decoration: BoxDecoration(
              color: AppColors.glassFillStrong,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: _isManualExpanded,
                onExpansionChanged: (expanded) => setState(() => _isManualExpanded = expanded),
                leading: const Icon(Icons.code_rounded, color: AppColors.textMuted, size: 20),
                title: const Text(
                  'Atau Tempel Token Manual',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  if (_autoDetected) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppColors.emerald.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.emerald.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: AppColors.emerald, size: 14),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Token terdeteksi dari clipboard!',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.emerald),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Token Otorisasi (Bearer v4.public...)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                      ),
                      TextButton.icon(
                        onPressed: _pasteFromClipboard,
                        icon: const Icon(Icons.paste_rounded, size: 13, color: AppColors.primaryLight),
                        label: const Text('Tempel', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _inputCtrl,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Tempel token di sini (v4.public...)',
                      hintStyle: const TextStyle(fontSize: 11, color: AppColors.textDisabled),
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
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: OutlinedButton(
                      onPressed: authProvider.isLoading ? null : _submitManualLogin,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: authProvider.isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Hubungkan Token Manual',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primaryLight),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
      ),
    );
  }
}
