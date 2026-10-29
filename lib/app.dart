import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'core/media.dart';

import 'core/api.dart';
import 'core/background_service.dart';
import 'core/models.dart';
import 'core/notifications.dart';
import 'core/permissions.dart';
import 'core/prefs.dart';
import 'core/state.dart';
import 'core/theme.dart';
import 'screens/login_screen.dart';
import 'screens/profile_sheet.dart';
import 'screens/workspace_screen.dart';
import 'ui/common.dart';
import 'ui/emoji.dart';
import 'ui/icons.dart';
import 'ui/navigation.dart';

Future<void> bootstrapFlackleApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BrandAssets.load();
  await EmojiIndex.load();
  final prefs = await AppPrefs.load();
  final client = FlackleClient();
  runApp(FlackleApp(prefs: prefs, client: client));
}

class FlackleApp extends StatefulWidget {
  const FlackleApp({required this.prefs, required this.client, super.key});

  final AppPrefs prefs;
  final FlackleClient client;

  @override
  State<FlackleApp> createState() => _FlackleAppState();
}

class _FlackleAppState extends State<FlackleApp> with WidgetsBindingObserver {
  late final AppState _state = AppState(widget.client, widget.prefs);
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _restoring = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(initFlackleBackgroundService());
    unawaited(setFlackleUiActive(true));
    unawaited(AppNotifications.bind(
      state: _state,
      navigatorKey: _navigatorKey,
    ));
    _restore();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _state.appInForeground = state == AppLifecycleState.resumed;
    unawaited(setFlackleUiActive(state == AppLifecycleState.resumed));
    if (state == AppLifecycleState.resumed) {
      AppNotifications.flushPending();
    }
  }

  Future<void> _restore() async {
    try {
      final user = await widget.client.restoreSession();
      if (user != null) {
        await _state.start();
        AppNotifications.flushPending();
        unawaited(startFlackleBackgroundService());
      }
    } catch (_) {
      // The login screen is the right destination when restoring fails.
    }
    if (mounted) setState(() => _restoring = false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _state.dispose();
    widget.client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_state.me != null) {
        AppNotifications.flushPending();
        unawaited(startFlackleBackgroundService());
      } else if (!_restoring) {
        unawaited(stopFlackleBackgroundService());
      }
    });
    return FlackleScope(
      state: _state,
      child: AnimatedBuilder(
        animation: widget.prefs,
        builder: (context, _) => MaterialApp(
          title: 'Flackle',
          navigatorKey: _navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: buildFlackleTheme(Brightness.light, widget.prefs.accentColor),
          darkTheme:
              buildFlackleTheme(Brightness.dark, widget.prefs.accentColor),
          themeMode: widget.prefs.themeMode,
          scrollBehavior: const _FlackleScrollBehavior(),
          home: _restoring ? const _SplashScreen() : const _RootGate(),
        ),
      ),
    );
  }
}

class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final state = FlackleScope.of(context);
    if (state.me == null) return LoginScreen(state: state);
    return WorkspaceScreen(state: state);
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FlackleMark(size: 46),
              const SizedBox(height: 16),
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.c.accent,
                ),
              ),
            ],
          ),
        ),
      );
}

class _FlackleScrollBehavior extends MaterialScrollBehavior {
  const _FlackleScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.trackpad,
      };
}

/// Full profile sheet used from chat, the member list and mention taps.
Future<void> showProfile(
  BuildContext context, {
  required User user,
  Member? member,
  String? serverId,
}) async {
  final state = FlackleScope.read(context);
  final parentContext = context;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, controller) => ProfileSheet(
        user: user,
        member: member,
        serverId: serverId,
        controller: controller,
        onOpenConversation: (conversation) async {
          if (parentContext.mounted) {
            await openConversation(parentContext, state, conversation);
          }
        },
      ),
    ),
  );
}

/// Full-screen image viewer used by attachments, media and avatars.
Future<void> openImageViewer(BuildContext context, String url,
    {String? title}) async {
  final state = FlackleScope.read(context);
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.9),
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        final saved = state.savedMediaUrls.contains(url);
        final canSave =
            state.active?.isChannel != true || state.can(Permission.saveMedia);
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5,
                  child: AppImage(url, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Row(
                  children: [
                    if (canSave)
                      IconButton(
                        tooltip:
                            saved ? 'Remove from saved media' : 'Save media',
                        onPressed: () async {
                          try {
                            final nowSaved = await state.toggleSavedMedia(url);
                            setDialogState(() {});
                            if (context.mounted) {
                              showAppToast(
                                context,
                                nowSaved
                                    ? 'Saved to your media.'
                                    : 'Removed from saved media.',
                              );
                            }
                          } catch (failure) {
                            if (context.mounted) {
                              showAppToast(context, failure.toString());
                            }
                          }
                        },
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.55),
                          foregroundColor: Colors.white,
                        ),
                        icon: Icon(
                          saved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                        ),
                      ),
                    if (canSave) const SizedBox(width: 6),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.55),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              if (title != null)
                Positioned(
                  left: 16,
                  bottom: 12,
                  right: 70,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}
