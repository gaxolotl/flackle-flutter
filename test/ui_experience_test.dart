import 'dart:async';
import 'dart:io';

import 'package:flackle_mobile/core/api.dart';
import 'package:flackle_mobile/core/models.dart';
import 'package:flackle_mobile/core/prefs.dart';
import 'package:flackle_mobile/core/state.dart';
import 'package:flackle_mobile/core/theme.dart';
import 'package:flackle_mobile/screens/chat_view.dart';
import 'package:flackle_mobile/screens/friends_view.dart';
import 'package:flackle_mobile/screens/settings_screen.dart';
import 'package:flackle_mobile/ui/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends FlackleClient {
  int requests = 0;
  Completer<void>? pendingRequest;

  @override
  Future<void> addFriend(String username) async {
    requests++;
    await pendingRequest?.future;
  }
}

class _State extends AppState {
  _State(super.client, super.prefs);

  bool failRefresh = false;

  @override
  Future<void> loadFriends() async {
    if (failRefresh) throw const FlackleException('Connection unavailable');
  }
}

const _alex = User(id: 'alex', username: 'alex', displayName: 'Alex Morgan');
const _sam = User(id: 'sam', username: 'sam', displayName: 'Sam Rivers');

void main() {
  late _Client client;
  late _State state;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    client = _Client();
    state = _State(client, await AppPrefs.load());
  });

  tearDown(() {
    state.dispose();
    client.dispose();
  });

  Future<void> pumpScreen(WidgetTester tester,
      {Widget child = const FriendsView(),
      Size size = const Size(390, 740),
      double textScale = 1,
      Brightness brightness = Brightness.dark}) async {
    tester.view.reset();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(FlackleScope(
      state: state,
      child: MaterialApp(
        theme: buildFlackleTheme(brightness, accentChoices.first.color),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(body: child),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> selectTab(WidgetTester tester, String label) async {
    final chip = find.widgetWithText(ChoiceChip, label);
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }

  testWidgets('friend search trims input and can recover from no results',
      (tester) async {
    state.friends = [_alex, _sam];
    await pumpScreen(tester);
    await tester.enterText(find.byType(TextField), '  ALEX  ');
    await tester.pumpAndSettle();
    expect(find.text('Alex Morgan'), findsOneWidget);
    expect(find.text('Sam Rivers'), findsNothing);

    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pumpAndSettle();
    expect(find.text('No matches found'), findsOneWidget);
    expect(find.text('No friends yet'), findsNothing);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('Alex Morgan'), findsOneWidget);
    expect(find.text('Sam Rivers'), findsOneWidget);
    expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text, '');
  });

  testWidgets('search filters pending requests and blocked users',
      (tester) async {
    state.friendRequests = const FriendRequests(
      incoming: [FriendRequest(id: 'in', status: 'pending', sender: _alex)],
      outgoing: [FriendRequest(id: 'out', status: 'pending', receiver: _sam)],
    );
    state.blocked = [_alex, _sam];
    await pumpScreen(tester, size: const Size(700, 740));
    await selectTab(tester, 'Pending');
    await tester.enterText(find.byType(TextField), 'SAM');
    await tester.pumpAndSettle();
    expect(find.text('Sam Rivers'), findsOneWidget);
    expect(find.text('Alex Morgan'), findsNothing);
    await selectTab(tester, 'Blocked');
    expect(find.text('Sam Rivers'), findsOneWidget);
    expect(find.text('Alex Morgan'), findsNothing);
  });

  testWidgets('add friend fits a narrow screen and prevents duplicate sends',
      (tester) async {
    await pumpScreen(tester, size: const Size(320, 640), textScale: 1.4);
    await tester.tap(find.widgetWithText(FilledButton, 'Add a friend'));
    await tester.pumpAndSettle();
    final send = find.widgetWithText(FilledButton, 'Send request');
    expect(tester.widget<FilledButton>(send).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'alex');
    await tester.ensureVisible(send);
    await tester.pumpAndSettle();
    final fieldRect = tester.getRect(find.byType(TextField));
    expect(tester.getRect(send).top, greaterThanOrEqualTo(fieldRect.bottom));
    expect(tester.takeException(), isNull);

    client.pendingRequest = Completer<void>();
    await tester.tap(send);
    await tester.pump();
    // The same physical control stays disabled while its request is pending.
    final busy = find.byType(FilledButton);
    expect(tester.widget<FilledButton>(busy).onPressed, isNull);
    await tester.tap(busy);
    expect(client.requests, 1);
    client.pendingRequest!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Friend request sent to alex.'), findsOneWidget);
  });

  testWidgets('refresh failure keeps cached friends visible', (tester) async {
    state.friends = [_alex];
    state.failRefresh = true;
    await pumpScreen(tester);
    expect(find.text('Alex Morgan'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Could not reach Flackle'), findsNothing);
  });

  testWidgets('add friend remains usable after an initial load failure',
      (tester) async {
    state.failRefresh = true;
    await pumpScreen(tester, size: const Size(700, 740));
    expect(find.text('Could not reach Flackle'), findsOneWidget);
    await selectTab(tester, 'Add friend');
    expect(find.widgetWithText(FilledButton, 'Send request'), findsOneWidget);
    expect(find.text('Could not reach Flackle'), findsNothing);
  });

  testWidgets('send action follows typed and programmatic composer changes',
      (tester) async {
    await pumpScreen(tester,
        child: const ChatView(
          target: Target.conversation('dm', title: 'Alex'),
        ));
    final send = find.descendant(
        of: find.byTooltip('Send message'),
        matching: find.byType(FilledButton));
    expect(tester.widget<FilledButton>(send).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'Hello Alex');
    await tester.pump();
    expect(tester.widget<FilledButton>(send).onPressed, isNotNull);
    // Emoji insertion and draft restoration can change the controller directly.
    tester.widget<TextField>(find.byType(TextField)).controller!.text = '   ';
    await tester.pump();
    expect(tester.widget<FilledButton>(send).onPressed, isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('About screen displays the package release version',
      (tester) async {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(r'^version: ([^+\r\n]+)', multiLine: true)
        .firstMatch(pubspec)!
        .group(1);
    await pumpScreen(tester, child: const SettingsScreen(initialTab: 5));
    expect(find.text('Version $version · Flutter'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('empty state scrolls in limited space (${brightness.name})',
        (tester) async {
      await pumpScreen(tester,
          size: const Size(320, 180),
          textScale: 1.8,
          brightness: brightness,
          child: EmptyPane(
            icon: Icons.people_outline,
            title: 'No friends yet',
            detail: 'Add a friend to start a conversation.',
            action:
                FilledButton(onPressed: () {}, child: const Text('Add friend')),
          ));
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(FilledButton).hitTestable(), findsOneWidget);
    });
  }
}
