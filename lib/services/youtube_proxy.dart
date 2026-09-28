import 'dart:io';
import 'package:flutter/foundation.dart';

/// Local HTTP proxy that relays YouTube CDN audio to media_kit.
///
/// Why: libmpv on Android cannot authenticate with YouTube CDN regardless
/// of which HTTP headers are injected via Media(httpHeaders:...). Dart's
/// own HttpClient has no such restrictions. This proxy runs on localhost,
/// accepts libmpv requests (including Range/seek requests), and forwards
/// them to YouTube CDN with the correct Android User-Agent.
class YouTubeLocalProxy {
  HttpServer? _server;
  String? _targetUrl;

  bool get isRunning => _server != null;

  static const String _androidUA =
      'com.google.android.youtube/19.09.37 (Linux; U; Android 11) gzip';

  /// Starts (or updates) the proxy pointing at [youtubeUrl].
  /// Returns the localhost URL that media_kit should open.
  Future<String> serve(String youtubeUrl) async {
    _targetUrl = youtubeUrl;
    if (_server == null) {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _listenForRequests();
      debugPrint('[YouTubeProxy] Started server on port ${_server!.port}');
    }
    final proxyUrl = 'http://127.0.0.1:${_server!.port}/audio';
    debugPrint('[YouTubeProxy] Serving via $proxyUrl');
    return proxyUrl;
  }

  void _listenForRequests() {
    _server!.listen(
      (HttpRequest request) async {
        if (_targetUrl == null) {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }
        HttpClient? client;
        try {
          final rangeHeader = request.headers.value('range');
          debugPrint('[YouTubeProxy] ${request.method} range=${rangeHeader ?? "(none)"}');

          client = HttpClient();
          client.autoUncompress = false;

          final ytReq = await client.openUrl(request.method, Uri.parse(_targetUrl!));
          ytReq.headers.set(HttpHeaders.userAgentHeader, _androidUA);
          if (rangeHeader != null) {
            ytReq.headers.set(HttpHeaders.rangeHeader, rangeHeader);
          } else {
            ytReq.headers.set(HttpHeaders.rangeHeader, 'bytes=0-');
          }

          final ytResp = await ytReq.close();
          debugPrint('[YouTubeProxy] CDN responded ${ytResp.statusCode}');

          request.response.statusCode = ytResp.statusCode;
          for (final name in const ['content-type', 'content-length', 'content-range', 'accept-ranges']) {
            final value = ytResp.headers.value(name);
            if (value != null) request.response.headers.set(name, value);
          }

          if (request.method != 'HEAD') {
            await ytResp.pipe(request.response);
          } else {
            await request.response.close();
          }
        } catch (e) {
          debugPrint('[YouTubeProxy] Request info/interrupted: $e');
          try {
            request.response.statusCode = HttpStatus.internalServerError;
            await request.response.close();
          } catch (_) {}
        } finally {
          client?.close(force: true);
        }
      },
      onError: (Object e) => debugPrint('[YouTubeProxy] Server error: $e'),
      cancelOnError: false,
    );
  }

  /// Gracefully clears the target URL without abruptly tearing down
  /// the loopback server, preventing TCP connection-refused errors during track changes.
  Future<void> stop() async {
    _targetUrl = null;
  }

  /// Closes the server socket completely on application shutdown.
  Future<void> dispose() async {
    await _server?.close(force: true);
    _server = null;
    _targetUrl = null;
  }
}
