import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/clipboard_helper.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bookmark_provider.dart';
import '../../providers/history_provider.dart';

class WebViewLoginScreen extends StatefulWidget {
  final String initialUrl;

  const WebViewLoginScreen({
    super.key,
    this.initialUrl = 'https://11.shinigami.asia/auth/supabase/login-user',
  });

  @override
  State<WebViewLoginScreen> createState() => _WebViewLoginScreenState();
}

class _WebViewLoginScreenState extends State<WebViewLoginScreen> {
  late final WebViewController _webViewController;
  bool _isLoading = true;
  double _progress = 0.0;
  bool _isProcessingToken = false;
  String? _detectedAccountName;
  String _currentUrl = '';

  static const String _tokenInterceptorScript = '''
(function() {
  function reportToken(raw, source) {
    if (!raw || typeof raw !== 'string') return;
    var matches = raw.match(/v4\\.public\\.[A-Za-z0-9_\\-]+/g);
    if (matches && matches.length > 0) {
      if (window.TokenChannel) {
        window.TokenChannel.postMessage(JSON.stringify({
          token: matches[0],
          source: source || 'unknown'
        }));
      }
    }
  }

  // 1. Hook window.fetch
  if (window.fetch && !window.__shngm_fetch_hooked) {
    window.__shngm_fetch_hooked = true;
    var originalFetch = window.fetch;
    window.fetch = async function() {
      try {
        var url = arguments[0] ? arguments[0].toString() : '';
        var options = arguments[1] || {};
        var headers = options.headers || {};
        if (headers) {
          if (typeof headers.get === 'function') {
            reportToken(headers.get('authorization') || headers.get('Authorization'), 'fetch_hdr:' + url);
          } else if (typeof headers === 'object') {
            reportToken(headers['Authorization'] || headers['authorization'] || headers['AUTHORIZATION'], 'fetch_hdr:' + url);
          }
        }
      } catch (e) {}

      var response = await originalFetch.apply(this, arguments);

      try {
        var clone = response.clone();
        clone.text().then(function(text) {
          reportToken(text, 'fetch_resp');
        }).catch(function() {});
      } catch (e) {}

      return response;
    };
  }

  // 2. Hook XMLHttpRequest
  if (window.XMLHttpRequest && !window.__shngm_xhr_hooked) {
    window.__shngm_xhr_hooked = true;
    var origOpen = XMLHttpRequest.prototype.open;
    var origSetHeader = XMLHttpRequest.prototype.setRequestHeader;

    XMLHttpRequest.prototype.setRequestHeader = function(header, value) {
      if (header && header.toLowerCase() === 'authorization') {
        reportToken(value, 'xhr_hdr');
      }
      return origSetHeader.apply(this, arguments);
    };

    XMLHttpRequest.prototype.open = function() {
      this.addEventListener('load', function() {
        try {
          if (this.responseText) {
            reportToken(this.responseText, 'xhr_resp');
          }
        } catch(e) {}
      });
      return origOpen.apply(this, arguments);
    };
  }

  // 3. Scan storage & cookies once per page load
  try {
    if (window.localStorage) {
      for (var i = 0; i < localStorage.length; i++) {
        var k = localStorage.key(i);
        var v = localStorage.getItem(k);
        reportToken(v, 'localStorage:' + k);
      }
    }
    if (window.sessionStorage) {
      for (var j = 0; j < sessionStorage.length; j++) {
        var sk = sessionStorage.key(j);
        var sv = sessionStorage.getItem(sk);
        reportToken(sv, 'sessionStorage:' + sk);
      }
    }
    if (document.cookie) {
      reportToken(document.cookie, 'cookie');
    }
    if (window.__NUXT__) {
      reportToken(JSON.stringify(window.__NUXT__), 'nuxt_state');
    }
  } catch(e) {}
})();
''';

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.initialUrl;
    _initWebView();
  }

  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 13; Mobile; rv:125.0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36',
      )
      ..addJavaScriptChannel(
        'TokenChannel',
        onMessageReceived: (JavaScriptMessage message) {
          _onTokenCaptured(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            final uri = Uri.tryParse(request.url);
            final host = uri?.host.toLowerCase() ?? '';
            // Block external ad networks / popups from eating RAM & freezing emulator
            if (host.contains('redirectbandar') ||
                host.contains('menujupenta') ||
                host.contains('tajir.la') ||
                host.contains('linkakurat') ||
                host.contains('bet') ||
                host.contains('slot')) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _currentUrl = url;
              });
            }
            _injectScript();
          },
          onProgress: (int progress) {
            if (mounted) {
              setState(() => _progress = progress / 100.0);
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _currentUrl = url;
              });
            }
            _injectScript();
            _scanForTokens();
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView Resource Error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  Future<void> _injectScript() async {
    try {
      await _webViewController.runJavaScript(_tokenInterceptorScript);
    } catch (e) {
      debugPrint('Error injecting script: $e');
    }
  }

  Future<void> _scanForTokens() async {
    try {
      final result = await _webViewController.runJavaScriptReturningResult('''
(function() {
  try {
    var raw = '';
    for (var i = 0; i < localStorage.length; i++) {
      raw += ' ' + localStorage.getItem(localStorage.key(i));
    }
    for (var j = 0; j < sessionStorage.length; j++) {
      raw += ' ' + sessionStorage.getItem(sessionStorage.key(j));
    }
    raw += ' ' + document.cookie;
    if (window.__NUXT__) raw += ' ' + JSON.stringify(window.__NUXT__);

    var match = raw.match(/v4\\.public\\.[A-Za-z0-9_\\-]+/);
    return match ? match[0] : '';
  } catch(e) {
    return '';
  }
})();
''');
      final tokenStr = result.toString().replaceAll('"', '').trim();
      if (tokenStr.startsWith('v4.public.')) {
        _onTokenCaptured(tokenStr);
      }
    } catch (e) {
      debugPrint('Error scanning tokens: $e');
    }
  }

  Future<void> _manualScanNow() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔍 Memindai token dari halaman...'),
        duration: Duration(seconds: 1),
      ),
    );
    await _scanForTokens();
  }

  Future<void> _onTokenCaptured(String payload) async {
    if (_isProcessingToken || !mounted) return;

    String rawToken = payload;
    if (payload.contains('token')) {
      final tokenMatch = RegExp(r'v4\.public\.[A-Za-z0-9_\-]+').firstMatch(payload);
      if (tokenMatch != null) {
        rawToken = tokenMatch.group(0)!;
      }
    }

    final clean = ClipboardHelper.cleanToken(rawToken);
    if (!clean.startsWith('v4.public.')) return;

    setState(() {
      _isProcessingToken = true;
    });

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.loginWithToken(clean);

    if (!mounted) return;

    if (success) {
      final userName = authProvider.user?.username ?? 'Pembaca';
      setState(() => _detectedAccountName = userName);

      // Trigger automatic sync for bookmarks & history
      context.read<BookmarkProvider>().syncRemoteBookmarks(clean);
      context.read<HistoryProvider>().syncRemoteHistory(clean);

      await Future.delayed(const Duration(milliseconds: 800));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '🎉 Berhasil terhubung sebagai $userName! Bookmark & riwayat tersinkronkan.',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.emerald,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context, true);
      }
    } else {
      setState(() {
        _isProcessingToken = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Login Shinigami',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            Text(
              _currentUrl.replaceFirst('https://', ''),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _isProcessingToken ? null : _manualScanNow,
            icon: const Icon(Icons.sync_rounded, size: 16, color: AppColors.cyan),
            label: const Text(
              'Hubungkan',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppColors.cyan,
              ),
            ),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.cyan.withValues(alpha: 0.15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Ke Beranda',
            icon: const Icon(Icons.home_outlined),
            onPressed: () {
              _webViewController.loadRequest(Uri.parse('https://11.shinigami.asia/'));
            },
          ),
          IconButton(
            tooltip: 'Muat Ulang',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              _webViewController.reload();
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3.0),
          child: _isLoading
              ? LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  backgroundColor: AppColors.surface,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 3.0,
                )
              : const SizedBox(height: 3.0),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _webViewController),
          if (_isProcessingToken)
            Container(
              color: Colors.black.withValues(alpha: 0.8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 44,
                        height: 44,
                        child: CircularProgressIndicator(
                          strokeWidth: 3.5,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.cyan),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        '✨ Token Berhasil Terdeteksi!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _detectedAccountName != null
                            ? 'Menghubungkan akun $_detectedAccountName...'
                            : 'Memverifikasi sesi & menyinkronkan data...',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
