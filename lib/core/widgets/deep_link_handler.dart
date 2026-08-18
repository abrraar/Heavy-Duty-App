import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:heavy_duty/core/navigation/app_router.dart';
import 'package:heavy_duty/core/navigation/app_routes.dart';

class DeepLinkHandler extends StatefulWidget {
  final Widget child;
  const DeepLinkHandler({super.key, required this.child});

  @override
  State<DeepLinkHandler> createState() => _DeepLinkHandlerState();
}

class _DeepLinkHandlerState extends State<DeepLinkHandler> {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // 1. Cold Start: App opened from completely closed state via link
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint("DeepLinkHandler: Captured INITIAL link: $initialUri");
        _processUri(initialUri);
      }
    } catch (e) {
      debugPrint("DeepLinkHandler: Error capturing initial link: $e");
    }

    // 2. Warm Start: App running in background when link is clicked
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      debugPrint("DeepLinkHandler: Received STREAM link: $uri");
      _processUri(uri);
    }, onError: (err) {
      debugPrint("DeepLinkHandler: Stream error: $err");
    });
  }

  void _processUri(Uri uri) {
    // Check path or host from heavyduty://change-password or heavyduty://manage-email
    // host is often used when no path is provided (scheme://host)
    final routePath = uri.host.isNotEmpty ? uri.host : uri.path.replaceAll('/', '');
    debugPrint("DeepLinkHandler: Processing routePath: $routePath");

    if (routePath == 'change-password') {
      debugPrint("DeepLinkHandler: Routing to Change Password");
      appRouter.go(AppRoutes.changePassword);
    } else if (routePath == 'manage-email') {
      debugPrint("DeepLinkHandler: Routing to Manage Email");
      appRouter.go(AppRoutes.home);
      appRouter.push(AppRoutes.settings);
      appRouter.push('${AppRoutes.manageEmail}?verified=true');
    } else if (routePath == 'confirm-email') {
      debugPrint("DeepLinkHandler: Routing to Home (Confirmation)");
      appRouter.go(AppRoutes.home);
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
