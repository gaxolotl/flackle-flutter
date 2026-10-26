import 'package:flutter/material.dart';

import '../core/state.dart';
import '../core/theme.dart';
import '../ui/icons.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.state, super.key});

  final AppState state;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _showPassword = false;
  bool _busy = false;
  bool _backupCode = false;
  String? _mfaToken;
  String? _error;

  AppState get _state => widget.state;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_mfaToken == null) {
        final result = await _state.client.login(_email.text, _password.text);
        if (result.requiresMfa) {
          setState(() => _mfaToken = result.mfaToken);
          return;
        }
        await _state.start();
      } else {
        await _state.client.loginMfa(
          _mfaToken!,
          _code.text,
          backupCode: _backupCode,
        );
        await _state.start();
      }
    } catch (failure) {
      setState(() => _error = failure.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _resetMfa() {
    setState(() {
      _mfaToken = null;
      _code.clear();
      _error = null;
      _backupCode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMfa = _mfaToken != null;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 820;
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: wide ? 48 : 22,
                vertical: wide ? 56 : 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: _pitch(context)),
                            const SizedBox(width: 56),
                            SizedBox(
                              width: 400,
                              child: _card(context, isMfa: isMfa),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _mobileHeader(context),
                            const SizedBox(height: 30),
                            _card(context, isMfa: isMfa),
                            const SizedBox(height: 20),
                            _footer(context),
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _mobileHeader(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FlackleWordmark(markSize: 32, fontSize: 24, showBeta: true),
          const SizedBox(height: 26),
          Text(
            'Your communities,\nin your pocket.',
            style: context.display(32,
                weight: FontWeight.w600, height: 1.08, letterSpacing: -1.2),
          ),
          const SizedBox(height: 10),
          Text(
            'A lighter way to keep up with every server, channel and conversation.',
            style: context.label(14, color: context.c.muted, height: 1.55),
          ),
        ],
      );

  Widget _pitch(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const FlackleWordmark(markSize: 40, fontSize: 30, showBeta: true),
        const SizedBox(height: 40),
        Text(
          'The whole server,\nwithout the bloat.',
          style: context.display(48,
              weight: FontWeight.w600, height: 1.05, letterSpacing: -1.9),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Text(
            'Channels, DMs, roles, moderation and live stats  -  a native client for Flackle built on the same graphite-and-ember design language.',
            style: context.label(15, color: c.muted, height: 1.6),
          ),
        ),
        const SizedBox(height: 36),
        for (final feature in const [
          (
            'hash',
            'Channels & categories',
            'Unread pings, icons and full history.'
          ),
          (
            'dm',
            'Direct messages',
            'Typing indicators and read state in real time.'
          ),
          (
            'shield',
            'Moderation tools',
            'Roles, bans, invites and the audit log.'
          ),
          ('chart', 'Live stats', 'Member, presence and activity analytics.'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 35,
                  height: 35,
                  decoration: BoxDecoration(
                    color: c.accentDim,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.accent.withValues(alpha: 0.22)),
                  ),
                  alignment: Alignment.center,
                  child: AppIcon(feature.$1, size: 17, color: c.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(feature.$2,
                          style: context.label(13.5, weight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(feature.$3,
                          style:
                              context.label(12, color: c.muted, height: 1.45)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _card(BuildContext context, {required bool isMfa}) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: c.panel,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: c.shadow, blurRadius: 40, offset: const Offset(0, 22))
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(isMfa ? 'Two-factor check' : 'Welcome back',
                style: context.display(21,
                    weight: FontWeight.w600, letterSpacing: -0.4)),
            const SizedBox(height: 5),
            Text(
              isMfa
                  ? 'Enter a code from your authenticator app to finish signing in.'
                  : 'Sign in with your Flackle account.',
              style: context.label(13, color: c.muted, height: 1.45),
            ),
            const SizedBox(height: 22),
            if (!isMfa) ...[
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.username],
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'you@example.com',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter your email.'
                    : null,
              ),
              const SizedBox(height: 13),
              TextFormField(
                controller: _password,
                obscureText: !_showPassword,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    tooltip: _showPassword ? 'Hide password' : 'Show password',
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                    icon: Icon(
                      _showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 19,
                    ),
                  ),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Enter your password.'
                    : null,
              ),
            ] else ...[
              TextFormField(
                controller: _code,
                keyboardType:
                    _backupCode ? TextInputType.text : TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText:
                      _backupCode ? 'Backup code' : 'Authentication code',
                  hintText: _backupCode ? 'XXXX-XXXX' : '000 000',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter your code.'
                    : null,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() {
                    _backupCode = !_backupCode;
                    _code.clear();
                  }),
                  child: Text(_backupCode
                      ? 'Use an authenticator code'
                      : 'Use a backup code'),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: c.danger.withValues(alpha: 0.1),
                  border: Border.all(color: c.danger.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(_error!,
                    style: TextStyle(
                        color: c.danger, fontSize: 12.5, height: 1.4)),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              height: 46,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(isMfa ? 'Verify and continue' : 'Sign in'),
              ),
            ),
            if (isMfa)
              TextButton(
                onPressed: _resetMfa,
                child: const Text('Use a different account'),
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 13, color: c.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Your password is sent only to flackle.com and is never stored on this device.',
                    style: context.label(11, color: c.muted, height: 1.45),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer(BuildContext context) => Text(
        'Flackle Mobile is an unofficial client for flackle.com. It is not affiliated with Flackle or Folkward LLC.',
        style: context.label(11, color: context.c.muted, height: 1.5),
      );
}
