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
  function sendToken(token, source, extraUser, refreshToken, expiresAt) {
    if (!token || typeof token !== 'string') return;
    var clean = token.replace(/^Bearer\\s+/i, '').trim();
    if (clean.length < 20) return;
    if (window.TokenChannel) {
      window.TokenChannel.postMessage(JSON.stringify({
        token: clean,
        refreshToken: refreshToken || null,
        expiresAt: expiresAt || null,
        source: source || 'unknown',
        user: extraUser || null
      }));
    }
  }

  var isCheckingWorkos = false;
  var lastWorkosCheck = 0;
  function tryWorkosCookieAuth() {
    var now = Date.now();
    if (isCheckingWorkos || (now - lastWorkosCheck < 2500)) return;
    if (!document.cookie || document.cookie.indexOf('workos-has-session') === -1) return;
    isCheckingWorkos = true;
    lastWorkosCheck = now;

    fetch('https://api.workos.com/user_management/authenticate', {
      method: 'POST',
      credentials: 'include',
      headers: {
        'Accept': 'application/json, text/plain, */*',
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        client_id: 'client_01KJWQWJ8M8WAKN8ZDWVVJ4BG1',
        grant_type: 'refresh_token'
      })
    }).then(function(res) {
      if (res.ok) return res.json();
      return null;
    }).then(function(data) {
      isCheckingWorkos = false;
      if (data) {
        var tok = data.access_token || data.accessToken || data.token;
        var rf = data.refresh_token || data.refreshToken;
        var exp = data.expires_at || data.expiresAt;
        var usr = data.user || null;
        if (tok && typeof tok === 'string' && tok.length > 20) {
          sendToken(tok, 'workos:cookie_auth', usr, rf, exp);
        }
      }
    }).catch(function() {
      isCheckingWorkos = false;
    });
  }
  window.__tryWorkosCookieAuth = tryWorkosCookieAuth;

  function checkWorkosStorage() {
    try {
      if (!window.localStorage) return false;
      var wat = localStorage.getItem('workos:access-token');
      var wrt = localStorage.getItem('workos:refresh-token');
      var wexp = localStorage.getItem('workos:expires-at');
      var wu = localStorage.getItem('workos:user');
      var uObj = null;
      if (wu) {
        try { uObj = JSON.parse(wu); } catch(e) {}
      }

      if (wat && wat.length > 20) {
        sendToken(wat, 'workos:storage', uObj, wrt, wexp);
        return true;
      }

      var as = localStorage.getItem('auth-storage');
      if (as) {
        var parsed = JSON.parse(as);
        if (parsed && parsed.state) {
          var s = parsed.state;
          var tok = s.token || (s.session ? (s.session.accessToken || s.session.access_token) : null);
          var rf = (s.session ? (s.session.refreshToken || s.session.refresh_token) : null) || wrt;
          var exp = (s.session ? (s.session.expiresAt || s.session.expires_at) : null) || wexp;
          var usr = s.user || uObj;
          if (tok && tok.length > 20) {
            sendToken(tok, 'auth-storage:state', usr, rf, exp);
            return true;
          }
        }
      }
    } catch(e) {}
    return false;
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
            var rf = (parsed.state.session ? (parsed.state.session.refreshToken || parsed.state.session.refresh_token) : null);
            var exp = (parsed.state.session ? (parsed.state.session.expiresAt || parsed.state.session.expires_at) : null);
            sendToken(parsed.state.token, source + ':parsed_state_token', parsed.state.user, rf, exp);
            return;
          }
          var tok = parsed.accessToken || parsed.access_token || parsed.token ||
                    (parsed.data && (parsed.data.accessToken || parsed.data.access_token || parsed.data.token));
          var rf = parsed.refreshToken || parsed.refresh_token ||
                   (parsed.data && (parsed.data.refreshToken || parsed.data.refresh_token));
          var exp = parsed.expiresAt || parsed.expires_at ||
                    (parsed.data && (parsed.data.expiresAt || parsed.data.expires_at));
          var usr = parsed.user || (parsed.data && parsed.data.user);
          if (tok && typeof tok === 'string' && tok.length > 20) {
            sendToken(tok, source + ':parsed_token', usr, rf, exp);
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
        if (key.indexOf('workos') !== -1 || key === 'auth-storage') {
          checkWorkosStorage();
        }
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
          checkWorkosStorage();
          tryWorkosCookieAuth();
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
            checkWorkosStorage();
            tryWorkosCookieAuth();
          }
        } catch(e) {}
      });
      return origOpen.apply(this, arguments);
    };
  }

  // Active scan inside JavaScript
  function runScan() {
    try {
      if (checkWorkosStorage()) return;
      tryWorkosCookieAuth();

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
      // 1. Trigger cookie auth first (WorkOS)
      try {
        await _webViewController.runJavaScript('''
if (typeof window.__tryWorkosCookieAuth === 'function') {
  window.__tryWorkosCookieAuth();
} else if (document.cookie && document.cookie.indexOf('workos-has-session') !== -1) {
  fetch('https://api.workos.com/user_management/authenticate', {
    method: 'POST',
    credentials: 'include',
    headers: { 'Accept': 'application/json, text/plain, */*', 'Content-Type': 'application/json' },
    body: JSON.stringify({ client_id: 'client_01KJWQWJ8M8WAKN8ZDWVVJ4BG1', grant_type: 'refresh_token' })
  }).then(function(r) { return r.ok ? r.json() : null; }).then(function(data) {
    if (data && (data.access_token || data.accessToken || data.token)) {
      if (window.TokenChannel) {
        window.TokenChannel.postMessage(JSON.stringify({
          token: data.access_token || data.accessToken || data.token,
          refreshToken: data.refresh_token || data.refreshToken || null,
          expiresAt: data.expires_at || data.expiresAt || null,
          user: data.user || null,
          source: 'dart_scan_workos'
        }));
      }
    }
  }).catch(function() {});
}
''');
      } catch (_) {}

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
        content: Text('🔍 Memindai token & sesi dari halaman...'),
        duration: Duration(seconds: 1),
      ),
    );
    await _scanForTokens();
  }

  Future<void> _onTokenCaptured(String payload) async {
    if (_isProcessingToken || !mounted) return;

    String rawToken = payload;
    String? refreshToken;
    int? expiresAt;
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
          } else if (map['accessToken'] != null) {
            rawToken = map['accessToken'].toString();
          } else if (map['access_token'] != null) {
            rawToken = map['access_token'].toString();
          }
          if (map['refreshToken'] != null) {
            refreshToken = map['refreshToken'].toString();
          } else if (map['refresh_token'] != null) {
            refreshToken = map['refresh_token'].toString();
          }
          if (map['expiresAt'] != null || map['expires_at'] != null) {
            final expVal = map['expiresAt'] ?? map['expires_at'];
            if (expVal is int) {
              expiresAt = expVal > 9999999999 ? expVal ~/ 1000 : expVal;
            } else if (expVal != null) {
              final parsed = int.tryParse(expVal.toString());
              if (parsed != null) {
                expiresAt = parsed > 9999999999 ? parsed ~/ 1000 : parsed;
              }
            }
          }
          if (map['user'] is Map) {
            userData = Map<String, dynamic>.from(map['user'] as Map);
          }
        }
      }
    } catch (_) {}

    // Fallback regex if rawToken still contains JSON or Bearer
    final jwtMatch = RegExp(r'eyJ[A-Za-z0-9_\\-]+\\.[A-Za-z0-9_\\-]+\\.[A-Za-z0-9_\\-]+').firstMatch(rawToken);
    final pasetoMatch = RegExp(r'v4\\.public\\.[A-Za-z0-9_\\-]+').firstMatch(rawToken);

    if (jwtMatch != null) {
      rawToken = jwtMatch.group(0)!;
    } else if (pasetoMatch != null) {
      rawToken = pasetoMatch.group(0)!;
    }

    final clean = ClipboardHelper.cleanToken(rawToken);
    if (clean.length < 20) return;

    // Check expiration
    final jwtExp = ClipboardHelper.getJwtExpiration(clean);
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final isExpired = jwtExp != null && jwtExp < nowSec;

    // If refreshToken was not captured in the payload, query localStorage directly
    if (refreshToken == null || refreshToken.isEmpty) {
      try {
        final rt = await _webViewController.runJavaScriptReturningResult(
          "localStorage.getItem('workos:refresh-token') || ''",
        );
        final cleanRt = rt.toString().replaceAll('"', '').trim();
        if (cleanRt.isNotEmpty && cleanRt != 'null') {
          refreshToken = cleanRt;
        }
      } catch (_) {}
    }

    // Guard against accepting a dead, unrefreshable token (from stale storage)
    if (isExpired && (refreshToken == null || refreshToken.isEmpty)) {
      debugPrint('Captured token is expired without refresh token. Triggering cookie auth instead...');
      try {
        await _webViewController.runJavaScript("if (typeof window.__tryWorkosCookieAuth === 'function') window.__tryWorkosCookieAuth();");
      } catch (_) {}
      return;
    }

    if (!mounted) return;

    setState(() {
      _isProcessingToken = true;
    });

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.saveSession(
      accessToken: clean,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
      userMap: userData,
    );

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
          PopupMenuButton<String>(
            tooltip: 'Opsi Sesi',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) async {
              if (val == 'reset') {
                try {
                  await WebViewCookieManager().clearCookies();
                  await _webViewController.clearCache();
                  await _webViewController.runJavaScript('localStorage.clear(); sessionStorage.clear();');
                } catch (_) {}
                _webViewController.loadRequest(Uri.parse('https://s1.shinigami.mx/'));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sesi & cookie web berhasil dibersihkan.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.cleaning_services_rounded, size: 18, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Bersihkan Sesi / Ganti Akun', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ],
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
