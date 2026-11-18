import 'dart:async';
import 'dart:convert';
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
    this.initialUrl = 'https://s1.shinigami.mx/',
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
  Timer? _pollTimer;

  static const String _tokenInterceptorScript = '''
(function() {
  function sendToken(token, source, extraUser) {
    if (!token || typeof token !== 'string') return;
    var clean = token.replace(/^Bearer\\s+/i, '').trim();
    if (clean.length < 20) return;
    if (window.TokenChannel) {
      window.TokenChannel.postMessage(JSON.stringify({
        token: clean,
        source: source || 'unknown',
        user: extraUser || null
      }));
    }
  }

  function inspectValue(val, source) {
    if (!val) return;
    if (typeof val !== 'string') {
      try { val = JSON.stringify(val); } catch(e) { return; }
    }

    // 1. Check if it's JSON containing auth-storage or token
    try {
      if (val.indexOf('{') !== -1) {
        var parsed = JSON.parse(val);
        if (parsed) {
          if (parsed.state && parsed.state.token) {
            sendToken(parsed.state.token, source + ':parsed_state_token', parsed.state.user);
            return;
          }
          if (parsed.token) {
            sendToken(parsed.token, source + ':parsed_token', parsed.user);
            return;
          }
          if (parsed.access_token) {
            sendToken(parsed.access_token, source + ':parsed_access_token', parsed.user);
            return;
          }
        }
      }
    } catch(e) {}

    // 2. JWT (eyJ...)
    var jwtMatch = val.match(/eyJ[A-Za-z0-9_\\-]+\\.[A-Za-z0-9_\\-]+\\.[A-Za-z0-9_\\-]+/);
    if (jwtMatch) {
      sendToken(jwtMatch[0], source + ':jwt');
      return;
    }

    // 3. Paseto (v4.public....)
    var pasetoMatch = val.match(/v4\\.public\\.[A-Za-z0-9_\\-]+/);
    if (pasetoMatch) {
      sendToken(pasetoMatch[0], source + ':paseto');
      return;
    }

    // 4. Raw Bearer
    var bearerMatch = val.match(/Bearer\\s+([A-Za-z0-9_\\-\\.]+)/i);
    if (bearerMatch) {
      sendToken(bearerMatch[1], source + ':bearer');
      return;
    }
  }

  // Hook localStorage.setItem
  if (window.localStorage && !window.__shngm_storage_hooked) {
    window.__shngm_storage_hooked = true;
    var origSetItem = localStorage.setItem;
    localStorage.setItem = function(key, val) {
      try {
        inspectValue(val, 'setItem:' + key);
      } catch(e) {}
      return origSetItem.apply(this, arguments);
    };
  }

  // Hook window.fetch
  if (window.fetch && !window.__shngm_fetch_hooked) {
    window.__shngm_fetch_hooked = true;
    var originalFetch = window.fetch;
    window.fetch = async function() {
      try {
        var url = arguments[0] ? arguments[0].toString() : '';
        var options = arguments[1] || {};
        var headers = options.headers || {};
        if (headers) {
          var auth = null;
          if (typeof headers.get === 'function') {
            auth = headers.get('authorization') || headers.get('Authorization');
          } else if (typeof headers === 'object') {
            auth = headers['Authorization'] || headers['authorization'] || headers['AUTHORIZATION'];
          }
          if (auth) inspectValue(auth, 'fetch_hdr:' + url);
        }
      } catch (e) {}

      var response = await originalFetch.apply(this, arguments);

      try {
        var clone = response.clone();
        clone.text().then(function(text) {
          inspectValue(text, 'fetch_resp');
        }).catch(function() {});
      } catch (e) {}

      return response;
    };
  }

  // Hook XMLHttpRequest
  if (window.XMLHttpRequest && !window.__shngm_xhr_hooked) {
    window.__shngm_xhr_hooked = true;
    var origOpen = XMLHttpRequest.prototype.open;
    var origSetHeader = XMLHttpRequest.prototype.setRequestHeader;

    XMLHttpRequest.prototype.setRequestHeader = function(header, value) {
      if (header && header.toLowerCase() === 'authorization') {
        inspectValue(value, 'xhr_hdr');
      }
      return origSetHeader.apply(this, arguments);
    };

    XMLHttpRequest.prototype.open = function() {
      this.addEventListener('load', function() {
        try {
          if (this.responseText) {
            inspectValue(this.responseText, 'xhr_resp');
          }
        } catch(e) {}
      });
      return origOpen.apply(this, arguments);
    };
  }

  // Active scan inside JavaScript
  function runScan() {
    try {
      if (window.localStorage) {
        var as = localStorage.getItem('auth-storage');
        if (as) inspectValue(as, 'scan:auth-storage');
        var wat = localStorage.getItem('workos:access-token');
        if (wat) inspectValue(wat, 'scan:workos:access-token');

        for (var i = 0; i < localStorage.length; i++) {
          var k = localStorage.key(i);
          inspectValue(localStorage.getItem(k), 'scan:localStorage:' + k);
        }
      }
      if (window.sessionStorage) {
        for (var j = 0; j < sessionStorage.length; j++) {
          var sk = sessionStorage.key(j);
          inspectValue(sessionStorage.getItem(sk), 'scan:sessionStorage:' + sk);
        }
      }
      if (document.cookie) {
        inspectValue(document.cookie, 'scan:cookie');
      }
    } catch(e) {}
  }

  runScan();
  if (!window.__shngm_scan_interval) {
    window.__shngm_scan_interval = setInterval(runScan, 1500);
  }
})();
''';

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.initialUrl;
    _initWebView();
    _startPolling();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (!mounted || _isProcessingToken) return;
      _scanForTokens();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
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
    if (_isProcessingToken || !mounted) return;
    try {
      final result = await _webViewController.runJavaScriptReturningResult('''
(function() {
  try {
    // 1. Direct check auth-storage
    var authStorage = localStorage.getItem('auth-storage');
    if (authStorage) {
      try {
        var parsed = JSON.parse(authStorage);
        if (parsed && parsed.state && parsed.state.token) {
          return JSON.stringify({
            token: parsed.state.token,
            user: parsed.state.user || null
          });
        }
      } catch(e) {}
    }

    // 2. Direct check workos:access-token
    var workosToken = localStorage.getItem('workos:access-token');
    if (workosToken && workosToken.length > 20) {
      var workosUser = null;
      try {
        workosUser = JSON.parse(localStorage.getItem('workos:user') || 'null');
      } catch(e) {}
      return JSON.stringify({
        token: workosToken,
        user: workosUser
      });
    }

    // 3. Scan localStorage for JWT or Paseto
    for (var i = 0; i < localStorage.length; i++) {
      var val = localStorage.getItem(localStorage.key(i)) || '';
      var jwt = val.match(/eyJ[A-Za-z0-9_\\-]+\\.[A-Za-z0-9_\\-]+\\.[A-Za-z0-9_\\-]+/);
      if (jwt) return JSON.stringify({ token: jwt[0] });
      var paseto = val.match(/v4\\.public\\.[A-Za-z0-9_\\-]+/);
      if (paseto) return JSON.stringify({ token: paseto[0] });
    }

    // 4. Scan cookies
    if (document.cookie) {
      var cJwt = document.cookie.match(/eyJ[A-Za-z0-9_\\-]+\\.[A-Za-z0-9_\\-]+\\.[A-Za-z0-9_\\-]+/);
      if (cJwt) return JSON.stringify({ token: cJwt[0] });
      var cPaseto = document.cookie.match(/v4\\.public\\.[A-Za-z0-9_\\-]+/);
      if (cPaseto) return JSON.stringify({ token: cPaseto[0] });
    }

    return '';
  } catch(e) {
    return '';
  }
})();
''');
      final str = result.toString().trim();
      if (str.isNotEmpty && str != '""' && str != 'null') {
        _onTokenCaptured(str);
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
    Map<String, dynamic>? userData;

    // Check if payload is JSON
    try {
      String cleanStr = payload;
      if (cleanStr.startsWith('"') && cleanStr.endsWith('"')) {
        cleanStr = jsonDecode(cleanStr) as String;
      }

      if (cleanStr.trim().startsWith('{') && cleanStr.trim().endsWith('}')) {
        final map = jsonDecode(cleanStr);
        if (map is Map) {
          if (map['token'] != null) {
            rawToken = map['token'].toString();
          }
          if (map['user'] is Map) {
            userData = Map<String, dynamic>.from(map['user'] as Map);
          }
        }
      }
    } catch (_) {}

    // Fallback regex if rawToken still contains JSON or Bearer
    final jwtMatch = RegExp(r'eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+').firstMatch(rawToken);
    final pasetoMatch = RegExp(r'v4\.public\.[A-Za-z0-9_\-]+').firstMatch(rawToken);

    if (jwtMatch != null) {
      rawToken = jwtMatch.group(0)!;
    } else if (pasetoMatch != null) {
      rawToken = pasetoMatch.group(0)!;
    }

    final clean = ClipboardHelper.cleanToken(rawToken);
    if (clean.length < 20) return;

    setState(() {
      _isProcessingToken = true;
    });

    final authProvider = context.read<AuthProvider>();
    bool success = await authProvider.loginWithToken(clean);

    // If API call fails but we have userData from auth-storage, create session directly
    if (!success && userData != null) {
      success = await authProvider.loginWithUserData(clean, userData);
    }

    if (!mounted) return;

    if (success) {
      _pollTimer?.cancel();
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
            icon: const Icon(Icons.sync_rounded, size: 16, color: AppColors.accent),
            label: const Text(
              'Hubungkan',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppColors.accent,
              ),
            ),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.accent.withValues(alpha: 0.15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Ke Beranda',
            icon: const Icon(Icons.home_outlined),
            onPressed: () {
              _webViewController.loadRequest(Uri.parse('https://s1.shinigami.mx/'));
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
        bottom: _isLoading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2.5),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  backgroundColor: AppColors.surface,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 2.5,
                ),
              )
            : null,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _webViewController),

          // Processing Overlay
          if (_isProcessingToken)
            Container(
              color: Colors.black.withValues(alpha: 0.85),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _detectedAccountName != null
                          ? 'Menghubungkan akun $_detectedAccountName...'
                          : 'Sesi login terdeteksi! Memverifikasi token...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Menyinkronkan bookmark & riwayat baca...',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Floating helper hint banner
          if (!_isProcessingToken)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.card.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Silakan login di halaman web. Sesi & token akun kamu akan otomatis terhubung.',
                        style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                      ),
                    ),
                    TextButton(
                      onPressed: _manualScanNow,
                      child: const Text('Hubungkan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
