# UI/UX audit — 29 October 2026

This pass checks complete screens and the transitions between them. It extends the
earlier workspace-header fixes into settings, server management, search, profiles,
member lists, notifications, dialogs, login, and chat.

## Findings and corrections

| Area | Observed inconsistency or failure | Correction |
| --- | --- | --- |
| Settings navigation | Personal and server settings used different sidebar widths, selected states, tab icons, and fixed tab-strip heights. | Both use shared navigation items and tabs that grow with system text size. |
| Server notification preferences | A long server name and the notification dropdown competed for one row; changing a level did not notify listeners. | Labeled full-width dropdowns sit below the server name and show the saved value immediately. |
| Server Overview | Notification choices and helper text clipped on phones. | Expanded dropdown content and wrapping helper text. |
| About and login | Branding rows overflowed with enlarged text. | Constrained text and flexible branding layouts. |
| Server management actions | Roles, Invites, and Bans headings competed with their primary action. | Actions wrap below headings when necessary. |
| Lifts | The level and progress summary overflowed narrow screens. | Responsive summary layout. |
| Role editor | Fixed-height content and a two-button icon row cramped the editor when the keyboard opened. | Scrollable content, wrapping controls, consistent busy states, and inline save errors. |
| Role creation | The dialog closed before the server accepted the role, losing the form on failure. | Shared text-entry dialog waits for success, prevents duplicate submission, and keeps errors beside the input. |
| Category creation/editing | Creation and editing handled saving differently; editing closed before completion. | Both use the same validated, keyboard-submit form and recoverable save flow. |
| Channel editing | Delete/Cancel/Save and icon controls overflowed; invalid slow-mode input silently became zero. | Wrapping actions, expanded category selection, and explicit slow-mode validation. |
| Server creation/joining | Empty submissions were enabled; fields and mode controls could change during a request. | Content-aware submit buttons, keyboard submission, and consistent busy controls. |
| Group creation | No friend search; creation enabled before enough people were selected; keyboard-open content was cramped. | Search by name or username, selection-aware submission, and scrollable content. |
| Group details | Heading and member actions competed for horizontal space. | Flexible heading and wrapping member actions. |
| Friend requests | Small text buttons consumed most of a narrow row. | Labeled, full-size icon actions preserve room for the person's name. |
| Friend removal | A destructive close icon sat beside the ordinary message action. | Removal is labeled in an options menu and retains its confirmation. |
| Search keyboard behavior | The footer advertised Enter-to-open without implementing it; the workspace displayed a Ctrl+K hint without binding it. | Ctrl+K/Cmd+K opens search and Enter opens the current first result, including immediately after typing. |
| Search matching | Usernames and surrounding whitespace were handled differently from Friends search; stats channels were excluded. | Trimmed matching, username matching, stats results, and clear-search recovery. |
| Search navigation | Async selections used a dismissed dialog's context, so navigation could disappear after a slow response. | Navigation uses the parent page's context. |
| Workspace selection | Opening a target through another flow could leave the desktop on the previous workspace view. | Workspace navigation follows changes to the active target. |
| Mobile message creation | Messages exposed group creation but lacked the direct-message creation flow available on desktop. | A direct-message action opens the selected conversation. |
| Mobile navigation | A restored channel could start on Messages; starting a group without friends changed only the desktop view flag. | Restored channels select Servers and the no-friends action opens Friends on mobile. |
| Tablet members | The Members button toggled a panel that was only rendered at larger desktop widths. | Intermediate widths open a visible member sheet. |
| Member list states | Empty or failed member requests could show a spinner indefinitely; switching servers did not reload the panel. | Separate loading, empty, error/retry, and server-change behavior, with a clearable search field. |
| Profiles | Message could update state without opening a mobile chat; side-by-side actions cramped their labels; closing relied on gestures. | Reliable parent-page navigation, full-width actions, and an explicit close button. |
| Profile editing | Unchanged saves were enabled and failures appeared only in transient feedback. | Save reflects actual edits, blocks overlapping submissions, and keeps errors with the entered name. |
| Chat composer | Formatting actions used small touch targets; a longer placeholder could expand an empty input. | Larger mobile targets, wrapping toolbar controls, a full-size send action, and a single-line placeholder. |
| Analytics and metrics | Long titles and large values clipped or wrapped digit by digit; the online icon referenced an unavailable asset. | Constrained titles, responsive metric cards, consistent value areas, and the shared presence indicator. |
| Notifications | Open inbox content did not react to arrivals, an empty inbox still enabled Mark all read, and dismissing the sheet marked everything read. | Live content, an actionable empty state, disabled irrelevant actions, and explicit read actions. |
| Dialogs and validation | Phone dialogs wasted horizontal space, long helper text clipped, and errors used different layouts. | Shared dialog margins, multiline helper/error text, and a consistent accessible inline error component. |
| Login requests | Account/MFA controls could change while verification was in flight; a response could update a disposed screen. | Disabled conflicting controls and mounted checks after asynchronous work. |

## Verification

The release passes 47 widget regression tests, including the earlier workspace checks.

- Widget tests cover all six personal settings sections and all seven server
  settings sections in dark and light themes at 320 px with enlarged text.
- Desktop tests exercise both settings sidebars and sections at 1100 px.
- Interaction tests cover keyboard search, delayed navigation, member failures
  and retry, mobile conversation creation, restored navigation, failed category,
  role and profile saves, notifications arriving while open, and leaving login
  during an in-flight request.
- Keyboard-open checks exercise channel/category dialogs, group creation,
  role editing, group details, and login.
- Rendered previews use the app's Manrope/Satoshi fonts and bundled icons.
  Review includes both themes, long names, large counts, and phone dialog layouts.
- The earlier regression suite still checks duplicate add-server actions,
  matching workspace headers, friend search, and the in-app release version.

The tests use deterministic local API fixtures. They verify layout and client
interaction behavior without making changes to a live account.

Run the checks with:

```sh
flutter test --no-pub
```

Regenerate the visual previews for inspection with:

```sh
flutter test test/ui_audit_test.dart --no-pub --dart-define=CAPTURE_UI=true --update-goldens
```

Previews are written to `shots/audit-*.png`, which is intentionally ignored by Git.
