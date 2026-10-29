import 'dart:async';

import 'package:flackle_mobile/app.dart';
import 'package:flackle_mobile/core/api.dart';
import 'package:flackle_mobile/core/models.dart';
import 'package:flackle_mobile/core/permissions.dart';
import 'package:flackle_mobile/core/prefs.dart';
import 'package:flackle_mobile/core/state.dart';
import 'package:flackle_mobile/core/theme.dart';
import 'package:flackle_mobile/screens/add_server_view.dart';
import 'package:flackle_mobile/screens/channel_dialog.dart';
import 'package:flackle_mobile/screens/chat_view.dart';
import 'package:flackle_mobile/screens/group_dm_dialog.dart';
import 'package:flackle_mobile/screens/group_dm_sheet.dart';
import 'package:flackle_mobile/screens/friends_view.dart';
import 'package:flackle_mobile/screens/login_screen.dart';
import 'package:flackle_mobile/screens/member_panel.dart';
import 'package:flackle_mobile/screens/notifications_sheet.dart';
import 'package:flackle_mobile/screens/profile_editor_screen.dart';
import 'package:flackle_mobile/screens/search_dialog.dart';
import 'package:flackle_mobile/screens/server_settings_screen.dart';
import 'package:flackle_mobile/screens/settings_screen.dart';
import 'package:flackle_mobile/screens/stats_view.dart';
import 'package:flackle_mobile/screens/workspace_screen.dart';
import 'package:flackle_mobile/ui/common.dart';
import 'package:flackle_mobile/ui/icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _person =
    User(id: 'person', username: 'alex_handle', displayName: 'Alex Morgan');
const _secondPerson =
    User(id: 'sam', username: 'sam', displayName: 'Sam Rivers');
const _channel = Channel(id: 'chat', name: 'general', type: 'text');
const _stats = Channel(
    id: 'stats',
    name: 'Community activity and member statistics',
    type: 'stats');
const _dm = Conversation(
    id: 'dm',
    type: 'dm',
    name: 'Alex Morgan',
    members: [ConversationMember(user: _person)]);
const _group = Conversation(
    id: 'group',
    type: 'group',
    name: 'Weekend plans',
    members: [
      ConversationMember(user: _person),
      ConversationMember(user: _secondPerson)
    ]);

class _AuditClient extends FlackleClient {
  _AuditClient()
      : super(
            httpClient: MockClient((_) async => http.Response('{}', 200,
                headers: {'content-type': 'application/json'})));
  Completer<void>? categoryRequest;
  Completer<Conversation>? dmRequest;
  int categoryCalls = 0;
  bool failCategory = false;
  bool failRoles = false;
  bool failProfile = false;
  Completer<LoginResult>? loginRequest;

  @override
  Future<Category> createCategory(String serverId, String name) async {
    categoryCalls++;
    await categoryRequest?.future;
    if (failCategory) {
      throw const FlackleException('Category could not be saved');
    }
    return Category(id: 'created', name: name);
  }

  @override
  Future<Category> updateCategory(String serverId, String id, String name) =>
      createCategory(serverId, name);

  @override
  Future<RolesResponse> batchRoles(
      String serverId, Map<String, dynamic> batch) async {
    if (failRoles) throw const FlackleException('Role could not be saved');
    return const RolesResponse();
  }

  @override
  Future<void> updateProfile({String? displayName}) async {
    if (failProfile) throw const FlackleException('Profile could not be saved');
  }

  @override
  Future<LoginResult> login(String email, String password) =>
      loginRequest!.future;

  @override
  Future<Conversation> createDM(String userId) =>
      dmRequest?.future ?? Future.value(_dm);

  @override
  Future<Conversation> fetchConversation(String conversationId) async => _group;

  @override
  Future<UserCard> fetchUserCard(String username, {String? serverId}) async =>
      const UserCard(user: _person);

  @override
  Future<AnalyticsBundle> fetchAnalytics(
          String serverId, String channelId) async =>
      const AnalyticsBundle(
          memberCount: 123456789, presenceCount: 12345, voiceCount: 32);
}

class _AuditState extends AppState {
  _AuditState(super.client, super.prefs);
  bool failMembers = false;
  final requestedMembers = <String>[];

  @override
  Future<void> loadMembers(String serverId, {bool force = false}) async {
    await Future<void>.value();
    requestedMembers.add(serverId);
    if (!failMembers) members.putIfAbsent(serverId, () => []);
    notifyListeners();
  }

  @override
  Future<void> loadRoles(String serverId, {bool force = false}) async {}
  @override
  Future<void> loadFriends() async {}
  @override
  Future<void> loadBundle(String serverId, {bool force = false}) async {}
  @override
  Future<void> reloadBundle(String serverId) async {}
  @override
  Future<void> openConversation(Conversation conversation) async {
    active = Target.conversation(conversation.id, title: 'Alex Morgan');
    notifyListeners();
  }

  @override
  Future<void> selectServer(String serverId,
      {String? preferredChannelId}) async {
    active = Target.channelView(
        serverId: serverId,
        serverName: 'Community',
        channelId: 'chat',
        title: 'general',
        channelType: 'text');
    notifyListeners();
  }
}

void main() {
  late _AuditClient client;
  late _AuditState state;
  late BuildContext pageContext;
  late GlobalKey previewKey;

  setUpAll(() async {
    if (!const bool.fromEnvironment('CAPTURE_UI')) return;
    for (final font in {
      'Manrope': 'assets/fonts/manrope-variable.ttf',
      'Satoshi': 'assets/fonts/satoshi-variable.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
    await BrandAssets.load();
  });

  setUp(() async {
    previewKey = GlobalKey();
    SharedPreferences.setMockInitialValues({});
    client = _AuditClient();
    state = _AuditState(client, await AppPrefs.load());
    state.me = const SelfUser(
        id: 'me',
        username: 'me',
        displayName: 'My Name',
        email: 'me@example.com',
        isAdmin: false);
    state.servers = const [
      Server(
          id: 'server',
          name: 'A community with a very long server name',
          memberCount: 12345)
    ];
    state.bundles['server'] = const ChannelBundle(channels: [
      _channel,
      _stats
    ], categories: [
      Category(
          id: 'category',
          name: 'A category with a very long name that should never overflow')
    ]);
    state.serverPermissions['server'] = Permission.administrator.toString();
    state.friends = [_person, _secondPerson];
    state.conversations = [_dm];
    state.roles['server'] = const [
      Role(
          id: 'role',
          name: 'Community moderators',
          color: '#4a9be8',
          position: 1)
    ];
    state.members['server'] = const [
      Member(user: _person),
      Member(user: _secondPerson)
    ];
  });

  tearDown(() {
    state.dispose();
    client.dispose();
  });

  Future<void> pumpPage(WidgetTester tester, Widget child,
      {Size size = const Size(320, 740),
      double scale = 1.4,
      Brightness brightness = Brightness.dark,
      double keyboard = 0}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(FlackleScope(
        state: state,
        child: RepaintBoundary(
            key: previewKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildFlackleTheme(brightness, accentChoices.first.color),
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(scale),
                      viewInsets: EdgeInsets.only(bottom: keyboard)),
                  child: child!),
              home: Builder(builder: (context) {
                pageContext = context;
                return Scaffold(body: child);
              }),
            ))));
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_UI')) return;
    await tester.pumpAndSettle();
    await expectLater(
        find.byKey(previewKey), matchesGoldenFile('../shots/audit-$name.png'));
  }

  Future<void> tapTab(WidgetTester tester, String label) async {
    final chip = find.widgetWithText(ChoiceChip, label);
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    testWidgets(
        'personal settings all sections fit at 320px (${brightness.name})',
        (tester) async {
      await pumpPage(tester, const SettingsScreen(), brightness: brightness);
      for (final tab in [
        'Account',
        'Appearance',
        'Chat',
        'Notifications',
        'Security',
        'About'
      ]) {
        await tapTab(tester, tab);
        expect(tester.takeException(), isNull, reason: tab);
        await capture(
            tester, 'settings-${tab.toLowerCase()}-${brightness.name}');
        await tester.drag(find.byType(ListView).last, const Offset(0, -1100));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$tab bottom');
      }
    });

    testWidgets(
        'server settings all sections fit at 320px (${brightness.name})',
        (tester) async {
      await pumpPage(tester, const ServerSettingsScreen(serverId: 'server'),
          brightness: brightness);
      for (final tab in [
        'Overview',
        'Roles',
        'Members',
        'Invites',
        'Bans',
        'Audit log',
        'Lifts'
      ]) {
        await tapTab(tester, tab);
        expect(tester.takeException(), isNull, reason: tab);
        await capture(tester,
            'server-${tab.toLowerCase().replaceAll(' ', '-')}-${brightness.name}');
        await tester.drag(find.byType(ListView).last, const Offset(0, -1000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$tab bottom');
      }
    });
  }

  testWidgets('profile editor disables unchanged saves and fits enlarged text',
      (tester) async {
    await pumpPage(tester, const ProfileEditorScreen());
    final save = find.widgetWithText(FilledButton, 'Save changes');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'A new name');
    await tester.pump();
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
    await capture(tester, 'profile-editor');
  });

  testWidgets('role creation preserves the form and shows save failures inline',
      (tester) async {
    client.failRoles = true;
    await pumpPage(tester, const ServerSettingsScreen(serverId: 'server'));
    await tapTab(tester, 'Roles');
    await tester.tap(find.text('New role'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create role'));
    await tester.pumpAndSettle();
    expect(find.text('Role could not be saved'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('failed profile saves keep the entered name available',
      (tester) async {
    client.failProfile = true;
    await pumpPage(tester, const ProfileEditorScreen());
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Updated name');
    await tester.ensureVisible(find.text('Save changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('Profile could not be saved'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Updated name');
  });

  testWidgets('pending friend actions remain tappable with enlarged text',
      (tester) async {
    state.friendRequests = const FriendRequests(incoming: [
      FriendRequest(id: 'request', status: 'pending', sender: _person)
    ]);
    await pumpPage(tester, const FriendsView());
    await tapTab(tester, 'Pending');
    for (final action in ['Accept friend request', 'Ignore friend request']) {
      expect(tester.getSize(find.byTooltip(action)).shortestSide,
          greaterThanOrEqualTo(48));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'leaving login during a request does not update a disposed screen',
      (tester) async {
    client.loginRequest = Completer<LoginResult>();
    await pumpPage(tester, LoginScreen(state: state), scale: 1);
    final fields = find.byType(TextFormField);
    await tester.ensureVisible(fields.first);
    await tester.enterText(fields.first, 'me@example.com');
    await tester.enterText(fields.last, 'a test password');
    await tester.ensureVisible(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    client.loginRequest!.complete(const LoginResult.mfa('test-token'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('role editor remains scrollable with the keyboard open',
      (tester) async {
    await pumpPage(tester, const ServerSettingsScreen(serverId: 'server'),
        keyboard: 240);
    await tapTab(tester, 'Roles');
    await tester.ensureVisible(find.text('Community moderators'));
    await tester.tap(find.text('Community moderators'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save role'));
    expect(find.byType(CheckboxListTile), findsWidgets);
    expect(tester.takeException(), isNull);
    await capture(tester, 'role-editor-keyboard');
  });

  testWidgets('group details actions fit with enlarged text and keyboard',
      (tester) async {
    await pumpPage(tester, const SizedBox(), keyboard: 240);
    unawaited(showGroupDmSheet(pageContext, _group));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Leave group'));
    expect(tester.takeException(), isNull);
    await capture(tester, 'group-details-keyboard');
  });

  for (final serverSettings in [false, true]) {
    testWidgets(
        'desktop settings navigation and sections fit (server: $serverSettings)',
        (tester) async {
      await pumpPage(
          tester,
          serverSettings
              ? const ServerSettingsScreen(serverId: 'server')
              : const SettingsScreen(),
          size: const Size(1100, 800),
          scale: 1.4,
          brightness: Brightness.light);
      final labels = serverSettings
          ? [
              'Overview',
              'Roles',
              'Members',
              'Invites',
              'Bans',
              'Audit log',
              'Lifts'
            ]
          : [
              'Account',
              'Appearance',
              'Chat',
              'Notifications',
              'Security',
              'About'
            ];
      for (final label in labels) {
        await tester.tap(find.widgetWithText(SettingsNavItem, label));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: label);
      }
    });
  }

  testWidgets(
      'per-server notification choices immediately show their saved value',
      (tester) async {
    await pumpPage(tester, const SettingsScreen(initialTab: 3));
    final field = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mentions only').last);
    await tester.pumpAndSettle();
    expect(state.serverSettings['server']?.notificationLevel, 'mentions');
    expect(tester.widget<DropdownButtonFormField<String>>(field).initialValue,
        'mentions');
  });

  testWidgets('login fits short screens with the keyboard open',
      (tester) async {
    await pumpPage(tester, LoginScreen(state: state),
        size: const Size(320, 600), keyboard: 260);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Sign in'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('member loading finishes for a genuinely empty server',
      (tester) async {
    await pumpPage(
        tester, const MemberPanel(serverId: 'empty', embedded: true));
    expect(find.text('No members yet'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
      'member failures offer retry and server switches fetch the new list',
      (tester) async {
    state.failMembers = true;
    await pumpPage(
        tester, const MemberPanel(serverId: 'missing', embedded: true));
    expect(find.text('Try again'), findsOneWidget);
    state.failMembers = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('No members yet'), findsOneWidget);
    await pumpPage(
        tester, const MemberPanel(serverId: 'another', embedded: true));
    expect(state.requestedMembers, contains('another'));
  });

  testWidgets('tablet Members opens a visible sheet', (tester) async {
    await state.selectServer('server');
    await pumpPage(tester, WorkspaceScreen(state: state),
        size: const Size(1000, 800), scale: 1);
    await tester.tap(find.byTooltip('Members'));
    await tester.pumpAndSettle();
    expect(find.byType(MemberPanel), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('mobile new message navigates into the selected conversation',
      (tester) async {
    await pumpPage(tester, WorkspaceScreen(state: state));
    await tester.tap(find.byTooltip('New message'));
    await tester.pumpAndSettle();
    await capture(tester, 'new-message');
    await tester.tap(find.text('Alex Morgan').last);
    await tester.pumpAndSettle();
    expect(find.byType(ChatPage), findsOneWidget);
  });

  testWidgets('restored channel selection starts on the Servers tab',
      (tester) async {
    await state.selectServer('server');
    await pumpPage(tester, WorkspaceScreen(state: state));
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1);
  });

  testWidgets('new group without friends opens the Friends tab on mobile',
      (tester) async {
    state.friends = [];
    await pumpPage(tester, WorkspaceScreen(state: state));
    await tester.tap(find.byTooltip('New group'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2);
  });

  testWidgets(
      'reopening the active conversation leaves the desktop Friends view',
      (tester) async {
    await state.openConversation(_dm);
    await pumpPage(tester, WorkspaceScreen(state: state),
        size: const Size(1200, 800), scale: 1);
    await tester.tap(find.byTooltip('Friends'));
    await tester.pumpAndSettle();
    expect(find.byType(FriendsView), findsOneWidget);
    await state.openConversation(_dm);
    await tester.pumpAndSettle();
    expect(find.byType(ChatView), findsOneWidget);
  });

  testWidgets('Ctrl K opens search and Enter opens the first result',
      (tester) async {
    await pumpPage(tester, WorkspaceScreen(state: state),
        size: const Size(1200, 800), scale: 1);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close search'), findsOneWidget);
    final search = find
        .byWidgetPredicate((widget) => widget is TextField && widget.autofocus);
    await tester.enterText(search, '  alex_handle  ');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close search'), findsNothing);
    expect(state.active?.conversationId, 'dm');
    expect(find.byType(ChatView), findsOneWidget);
  });

  testWidgets(
      'async search selections navigate after the search dialog is gone',
      (tester) async {
    await pumpPage(tester, const SizedBox());
    client.dmRequest = Completer<Conversation>();
    unawaited(showQuickSwitcher(pageContext));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'alex_handle');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alex Morgan'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    client.dmRequest!.complete(_dm);
    await tester.pumpAndSettle();
    expect(find.byType(ChatPage), findsOneWidget);
  });

  testWidgets('quick search includes stats channels and can clear no results',
      (tester) async {
    await pumpPage(tester, const SizedBox());
    unawaited(showQuickSwitcher(pageContext));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'statistics');
    await tester.pumpAndSettle();
    expect(find.text('#${_stats.name}'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'no such result');
    await tester.pumpAndSettle();
    expect(find.text('No matches found'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('#general'), findsOneWidget);
  });

  testWidgets(
      'category edit stays open on failure and prevents duplicate saves',
      (tester) async {
    await pumpPage(tester, const SizedBox(), keyboard: 240);
    client.failCategory = true;
    unawaited(openCategoryEdit(
        pageContext, 'server', const Category(id: 'cat', name: 'Original')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Updated');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('Category could not be saved'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    client.failCategory = false;
    client.categoryRequest = Completer<void>();
    await tester.tap(find.text('Save changes'));
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    client.categoryRequest!.complete();
    await tester.pumpAndSettle();
    expect(client.categoryCalls, 2);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('server dialog starts disabled and supports keyboard submission',
      (tester) async {
    await pumpPage(tester, const SizedBox(), keyboard: 240);
    unawaited(openAddServer(pageContext));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    await tester.enterText(find.byType(TextField), 'Community');
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);
    expect(tester.widget<TextField>(find.byType(TextField)).onSubmitted,
        isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('channel edit actions wrap with keyboard and long category names',
      (tester) async {
    await pumpPage(tester, const SizedBox(), keyboard: 240);
    unawaited(openChannelEdit(pageContext, 'server', _channel));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save changes'));
    expect(tester.takeException(), isNull);
    final slowmode = find.widgetWithText(TextField, 'Slow mode (seconds)');
    await tester.ensureVisible(slowmode);
    await tester.enterText(slowmode, 'invalid');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('Enter slow mode between 0 and 21600 seconds.'),
        findsOneWidget);
    await capture(tester, 'channel-validation-keyboard');
  });

  testWidgets('group picker is searchable and stays usable with a keyboard',
      (tester) async {
    await pumpPage(tester, const SizedBox(), keyboard: 240);
    unawaited(showCreateGroupDm(pageContext));
    await tester.pumpAndSettle();
    final create = find.widgetWithText(FilledButton, 'Create group');
    expect(tester.widget<FilledButton>(create).onPressed, isNull);
    final search = find.widgetWithText(TextField, 'Search friends');
    await tester.ensureVisible(search);
    await tester.enterText(search, 'alex_handle');
    await tester.pumpAndSettle();
    expect(find.text('Alex Morgan'), findsOneWidget);
    expect(find.text('Sam Rivers'), findsNothing);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    for (final name in ['Alex Morgan', 'Sam Rivers']) {
      await tester.ensureVisible(find.text(name));
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(create);
    expect(tester.widget<FilledButton>(create).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
    await capture(tester, 'group-picker-keyboard');
  });

  testWidgets(
      'mobile formatting controls are tappable and wrap without overflow',
      (tester) async {
    await pumpPage(tester,
        const ChatView(target: Target.conversation('dm', title: 'Alex')));
    for (final name in [
      'Chat settings',
      'Bold',
      'Italic',
      'Underline',
      'Strikethrough'
    ]) {
      expect(tester.getSize(find.byTooltip(name)).shortestSide,
          greaterThanOrEqualTo(44));
    }
    expect(tester.takeException(), isNull);
    await capture(tester, 'chat-composer');
  });

  testWidgets('analytics handles large counts and long channel titles',
      (tester) async {
    await pumpPage(
        tester, const StatsPage(serverId: 'server', channel: _stats));
    expect(find.text('123456789'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, 'analytics');
  });

  testWidgets(
      'notifications update live and closing does not mark everything read',
      (tester) async {
    await pumpPage(tester, WorkspaceScreen(state: state));
    await tester.tap(find.widgetWithText(NavigationDestination, 'You'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notifications').last);
    await tester.pumpAndSettle();
    expect(find.byType(NotificationsSheet), findsOneWidget);
    expect(
        tester
            .widget<TextButton>(
                find.widgetWithText(TextButton, 'Mark all read'))
            .onPressed,
        isNull);
    state.addNotification(
        title: 'New reply', body: 'A reply arrived while the inbox was open');
    await tester.pumpAndSettle();
    expect(find.text('New reply'), findsOneWidget);
    await capture(tester, 'notifications');
    await tester.tap(find.byTooltip('Close notifications'));
    await tester.pumpAndSettle();
    expect(state.unreadNotifications, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile Message action opens a mobile conversation',
      (tester) async {
    await pumpPage(tester, const SizedBox());
    unawaited(showProfile(pageContext, user: _person));
    await tester.pumpAndSettle();
    final message = find.widgetWithText(FilledButton, 'Message');
    await tester.ensureVisible(message);
    await capture(tester, 'profile');
    await tester.tap(message);
    await tester.pumpAndSettle();
    expect(find.byType(ChatPage), findsOneWidget);
  });
}
