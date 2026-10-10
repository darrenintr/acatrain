import 'dart:async';

import 'package:flutter/material.dart';

import 'package:acatrain/app_ui.dart';
import 'package:acatrain/expressive.dart';
import 'package:acatrain/haptics.dart';
import 'package:acatrain/language.dart';
import 'package:acatrain/store.dart';

/// Sign-in and registration sheet. Owns only ephemeral form state;
/// all credentials and account operations remain in AppStore.
class AcatrainAuthSheet extends StatefulWidget {
  const AcatrainAuthSheet({super.key, required this.store});
  final AppStore store;

  @override
  State<AcatrainAuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends State<AcatrainAuthSheet> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _emailLink = TextEditingController();
  bool _creating = false;
  bool _submitting = false;
  bool _passwordless = false;
  bool _passwordVisible = false;
  bool _linkSent = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    _emailLink.dispose();
    super.dispose();
  }

  Future<void> _run(
    Future<bool> Function() action, {
    bool close = false,
  }) async {
    setState(() {
      _submitting = true;
      _error = null;
      _notice = null;
    });
    final ok = await action();
    if (!ok) unawaited(Haptics.play(AcHaptic.error));
    if (!mounted) return;
    if (ok && close) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _submitting = false;
      if (ok) {
        _notice = widget.store.status;
      } else {
        _error = widget.store.status;
        if (_error!.contains('password account') ||
            _error!.contains('with its password')) {
          _creating = false;
          _passwordless = false;
          if (_email.text.isEmpty && widget.store.pendingGoogleEmail != null) {
            _email.text = widget.store.pendingGoogleEmail!;
          }
        }
      }
    });
  }

  Future<void> _submitPassword() async {
    if (_creating && _password.text != _confirmation.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    await _run(
      () => widget.store.signIn(_email.text, _password.text, register: _creating),
      close: true,
    );
  }

  Future<void> _sendLink() => _run(() async {
    final ok = await widget.store.sendEmailSignInLink(_email.text);
    if (ok && mounted) setState(() => _linkSent = true);
    return ok;
  });

  Future<void> _finishLink() => _run(
    () => widget.store.signInWithEmailLink(_email.text, _emailLink.text),
    close: true,
  );

  Future<void> _resetPassword() =>
      _run(() => widget.store.sendPasswordReset(_email.text));

  Future<void> _signInGoogle() =>
      _run(widget.store.signInWithGoogle, close: true);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 6, 24, 24 + bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr(
              context,
              _passwordless
                  ? 'Sign in without a password'
                  : _creating
                  ? 'Create your account'
                  : 'Welcome back',
            ),
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              context,
              _passwordless
                  ? 'We can send a one-time Firebase email link. On desktop/mobile you can paste the full link back here.'
                  : 'Your cloud account only exists to sync learning progress across devices.',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: _submitting ? null : _signInGoogle,
            icon: const Icon(Icons.account_circle_outlined),
            label: Text(tr(context, 'Continue with Google')),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(tr(context, 'or use email')),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _email,
            enabled: !_submitting,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(
              labelText: tr(context, 'Email'),
              prefixIcon: const Icon(Icons.mail_outline_rounded),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: AcatrainSprings.durationOf(
              context,
              AcatrainSprings.effectsDefault,
            ),
            switchInCurve: AcatrainSprings.effectsDefaultCurve,
            switchOutCurve: AcatrainSprings.effectsDefaultCurve,
            child:
                _passwordless
                    ? Column(
                      key: const ValueKey('link-auth'),
                      children: [
                        if (_linkSent) ...[
                          TextField(
                            controller: _emailLink,
                            enabled: !_submitting,
                            decoration: InputDecoration(
                              labelText: tr(context, 'Email link or oobCode'),
                              prefixIcon: const Icon(Icons.link_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        FilledButton.icon(
                          onPressed:
                              _submitting
                                  ? null
                                  : _linkSent
                                  ? _finishLink
                                  : _sendLink,
                          icon: Icon(
                            _linkSent
                                ? Icons.login_rounded
                                : Icons.send_outlined,
                          ),
                          label: Text(
                            tr(
                              context,
                              _linkSent
                                  ? 'Complete sign in'
                                  : 'Send sign-in link',
                            ),
                          ),
                        ),
                      ],
                    )
                    : Column(
                      key: const ValueKey('password-auth'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _password,
                          enabled: !_submitting,
                          obscureText: !_passwordVisible,
                          enableSuggestions: false,
                          autocorrect: false,
                          autofillHints:
                              _creating
                                  ? const [AutofillHints.newPassword]
                                  : const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: tr(context, 'Password'),
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _passwordVisible = !_passwordVisible),
                              tooltip: tr(context, _passwordVisible
                                  ? 'Hide password' : 'Show password'),
                              icon: Icon(_passwordVisible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined),
                            ),
                          ),
                        ),
                        if (_creating) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: _confirmation,
                            enabled: !_submitting,
                            obscureText: !_passwordVisible,
                            autocorrect: false,
                            enableSuggestions: false,
                            autofillHints: const [AutofillHints.newPassword],
                            decoration: InputDecoration(
                              labelText: tr(context, 'Confirm password'),
                              prefixIcon: const Icon(Icons.lock_reset_rounded),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _submitting ? null : _submitPassword,
                          child: Text(
                            tr(
                              context,
                              _submitting
                                  ? 'Connecting...'
                                  : _creating
                                  ? 'Create account'
                                  : 'Sign in',
                            ),
                          ),
                        ),
                        if (!_creating)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: _submitting ? null : _resetPassword,
                              child: Text(tr(context, 'Forgot password?')),
                            ),
                          ),
                      ],
                    ),
          ),
          if (_notice != null) ...[
            const SizedBox(height: 12),
            _AuthMessage(
              text: _notice!,
              icon: Icons.mark_email_read_outlined,
              color: theme.colorScheme.primaryContainer,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            _AuthMessage(
              text: _error!,
              icon: Icons.error_outline_rounded,
              color: theme.colorScheme.errorContainer,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(tr(context, 'or')),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed:
                _submitting
                    ? null
                    : () => setState(() {
                      _passwordless = !_passwordless;
                      _error = null;
                      _notice = null;
                    }),
            icon: Icon(
              _passwordless
                  ? Icons.password_rounded
                  : Icons.mark_email_unread_outlined,
            ),
            label: Text(
              tr(
                context,
                _passwordless
                    ? 'Use email and password'
                    : 'Use passwordless email link',
              ),
            ),
          ),
          if (!_passwordless)
            TextButton(
              onPressed:
                  _submitting
                      ? null
                      : () => setState(() => _creating = !_creating),
              child: Text(
                tr(
                  context,
                  _creating
                      ? 'Already have an account? Sign in'
                      : 'New to Acatrain? Create an account',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AuthMessage extends StatelessWidget {
  const _AuthMessage({
    required this.text,
    required this.icon,
    required this.color,
  });
  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(AcatrainRadii.l),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(tr(context, text))),
      ],
    ),
  );
}
