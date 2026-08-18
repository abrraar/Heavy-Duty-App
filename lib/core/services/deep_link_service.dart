import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../navigation/app_routes.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  Future<void> init(GoRouter router) async {
    // 1. Cold Start
    final initial = await _appLinks.getInitialLink();
    if (initial != null) {
      debugPrint('[DeepLink] cold-start URI: $initial');
      _route(initial, router);
    }

    // 2. Warm / background
    _sub = _appLinks.uriLinkStream.listen((uri) {
      debugPrint('[DeepLink] stream URI: $uri');
      _route(uri, router);
    }, onError: (err) {
      debugPrint('[DeepLink] stream error: $err');
    });
  }

  void _route(Uri uri, GoRouter router) {
    // Capture parameters from both query and fragment (Supabase sometimes uses hashes)
    final Map<String, String> params = {...uri.queryParameters};
    if (uri.hasFragment) {
      try {
        final fragmentUri = Uri.parse('?${uri.fragment}');
        params.addAll(fragmentUri.queryParameters);
      } catch (e) {
        debugPrint('[DeepLink] fragment parse error: $e');
      }
    }
    
    debugPrint('[DeepLink] resolved params: $params');

    final type = params['type'];
    final basePath = switch (type) {
      'recovery' => AppRoutes.changePassword,
      'email_change' => AppRoutes.manageEmail,
      _ => null,
    };

    if (basePath == null) {
      debugPrint('[DeepLink] no matching type, ignoring: $type');
      return; // Do NOT fall back to '/'
    }

    String finalPath = basePath;
    if (basePath == AppRoutes.manageEmail) {
      final message = params['message'];
      finalPath = message != null 
          ? '$basePath?verified=true&message=${Uri.encodeComponent(message)}'
          : '$basePath?verified=true';
    }

    debugPrint('[DeepLink] routing to $finalPath');
    // Single go() call. go_router resolves the full ancestor chain from the
    // nested route hierarchy (Settings -> ManageEmail / Settings ->
    // ChangePassword) automatically. 
    router.go(finalPath);
    debugPrint('[DeepLink] router.go($finalPath) called');
  }

  void dispose() {
    _sub?.cancel();
  }
}
