import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'language.dart';
import 'store.dart';

/// Account settings are separate from guest-only study preferences.
class AccountPage extends StatefulWidget {
  const AccountPage({super.key, required this.store});
  final AppStore store;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _name = TextEditingController();
  bool _submitting = false;
  AppStore get store => widget.store;
  bool get _busy => _submitting || store.busy;

  @override
  void initState() {
    super.initState();
    _name.text = store.displayName ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted && store.uid != null && await store.refreshAccount() && mounted) {
        _name.text = store.displayName ?? '';
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<bool> _act(Future<bool> Function() operation) async {
    if (_busy) return false;
    setState(() => _submitting = true);
    final ok = await operation();
    if (!mounted) return ok;
    setState(() => _submitting = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(tr(context, store.status))));
    return ok;
  }

  Future<void> _changePassword() async {
    final next = TextEditingController();
    final confirm = TextEditingController();
    String? error;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refresh) => AlertDialog(
          title: Text(tr(ctx, 'Change password')),
          content: SizedBox(
            width: 380,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(tr(ctx, 'Use at least 8 characters. You may need to sign in again for sensitive changes.')),
              const SizedBox(height: 12),
              TextField(
                controller: next, obscureText: true,
                enableSuggestions: false, autocorrect: false,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(labelText: tr(ctx, 'New password')),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirm, obscureText: true,
                enableSuggestions: false, autocorrect: false,
                decoration: InputDecoration(labelText: tr(ctx, 'Confirm password')),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr(ctx, 'Cancel'))),
            FilledButton(onPressed: () {
              if (next.text.length < 8 || next.text.length > 128) {
                refresh(() => error = tr(ctx, 'Use a password between 8 and 128 characters.'));
              } else if (next.text != confirm.text) {
                refresh(() => error = tr(ctx, 'Passwords do not match.'));
              } else {
                Navigator.pop(ctx, true);
              }
            }, child: Text(tr(ctx, 'Update password'))),
          ],
        ),
      ),
    );
    final password = next.text;
    next.dispose();
    confirm.dispose();
    if (proceed == true && mounted) await _act(() => store.changePassword(password));
  }

  Future<void> _removeAccount() async {
    final expected = store.email?.trim().toLowerCase();
    if (expected == null || expected.isEmpty) return;
    var confirmation = '';
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refresh) => AlertDialog(
          title: Text(tr(ctx, 'Delete account permanently?')),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(ctx,
                  'Your account, cloud study progress and this account local progress will be deleted. Guest progress is not affected. This cannot be undone.')),
                const SizedBox(height: 16),
                Text(tr(ctx, 'Type your email to confirm:')),
                SelectableText(store.email ?? ''),
                const SizedBox(height: 10),
                TextField(
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (value) => refresh(() => confirmation = value),
                  decoration: InputDecoration(labelText: tr(ctx, 'Email')),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr(ctx, 'Cancel'))),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
                foregroundColor: Theme.of(ctx).colorScheme.onError,
              ),
              onPressed: confirmation.trim().toLowerCase() == expected
                  ? () => Navigator.pop(ctx, true) : null,
              child: Text(tr(ctx, 'Delete permanently')),
            ),
          ],
        ),
      ),
    );
    if (proceed == true && mounted) {
      final ok = await _act(store.deleteAccount);
      if (ok && mounted) Navigator.pop(context);
    }
  }

  Future<void> _copyProgress() async {
    final json = jsonEncode({
      'schemaVersion': 1,
      'uid': store.uid,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'items': store.progress.map((key, value) => MapEntry(key, value.toJson())),
    });
    await Clipboard.setData(ClipboardData(text: json));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr(context, 'Progress copied as JSON. Keep this data private.')),
      ));
    }
  }

  Widget _section(String heading, List<Widget> contents) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(heading, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 14),
        ...contents,
      ]),
    ),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final colors = Theme.of(context).colorScheme;
      if (store.uid == null) {
        return Scaffold(
          appBar: AppBar(title: Text(tr(context, 'Manage account'))),
          body: Center(child: Text(tr(context, 'You are signed out.'))),
        );
      }
      return Scaffold(
        appBar: AppBar(title: Text(tr(context, 'Manage account'))),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 740),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
              children: [
                Row(children: [
                  CircleAvatar(
                    radius: 30, backgroundColor: colors.primaryContainer,
                    foregroundColor: colors.onPrimaryContainer,
                    child: const Icon(Icons.person_rounded, size: 34),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(store.displayName?.isNotEmpty == true
                          ? store.displayName! : tr(context, 'Your account'),
                        style: Theme.of(context).textTheme.headlineSmall),
                      Text(store.email ?? ''),
                    ],
                  )),
                ]),
                const SizedBox(height: 16),
                _section(tr(context, 'Personal info'), [
                  TextField(
                    controller: _name, maxLength: 80, enabled: !_busy,
                    decoration: InputDecoration(labelText: tr(context, 'Name')),
                  ),
                  Align(alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : () => _act(
                        () => store.updateDisplayName(_name.text)),
                      icon: const Icon(Icons.save_outlined),
                      label: Text(tr(context, 'Save')),
                    )),
                  const Divider(height: 30),
                  Text(tr(context, 'Email') + ': ' + (store.email ?? '')),
                  const SizedBox(height: 8),
                  Text(
                    store.emailVerified == true ? tr(context, 'Email verified')
                    : store.emailVerified == false ? tr(context, 'Email not verified')
                    : tr(context, 'Verification status unavailable'),
                    style: TextStyle(color: store.emailVerified == true
                        ? colors.primary : colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    if (store.emailVerified != true) OutlinedButton.icon(
                      onPressed: _busy ? null : () => _act(store.sendVerificationEmail),
                      icon: const Icon(Icons.mark_email_unread_outlined),
                      label: Text(tr(context, 'Send verification email')),
                    ),
                    TextButton.icon(
                      onPressed: _busy ? null : () async {
                        if (await _act(store.refreshAccount) && mounted) {
                          _name.text = store.displayName ?? '';
                        }
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(tr(context, 'Refresh status')),
                    ),
                  ]),
                ]),
                const SizedBox(height: 12),
                _section(tr(context, 'Sign-in methods'), [
                  Row(children: [
                    const Icon(Icons.account_circle_outlined),
                    const SizedBox(width: 10),
                    Expanded(child: Text(store.googleConnected
                        ? tr(context, 'Google connected')
                        : tr(context, 'Google not connected'))),
                    if (!store.googleConnected) TextButton(
                      onPressed: _busy ? null : () => _act(store.signInWithGoogle),
                      child: Text(tr(context, 'Connect Google')),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _changePassword,
                    icon: const Icon(Icons.password_rounded),
                    label: Text(tr(context, 'Change password')),
                  ),
                  TextButton(
                    onPressed: _busy || store.email == null ? null : () => _act(
                      () => store.sendPasswordReset(store.email!)),
                    child: Text(tr(context, 'Send password reset email')),
                  ),
                ]),
                const SizedBox(height: 12),
                _section(tr(context, 'Study progress'), [
                  Text(tr(context,
                      'Your progress is stored separately from guest progress. Sync manually across devices.')),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    FilledButton.tonalIcon(
                      onPressed: _busy ? null : () => _act(store.syncProgress),
                      icon: const Icon(Icons.cloud_sync_outlined),
                      label: Text(tr(context, 'Sync progress')),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _copyProgress,
                      icon: const Icon(Icons.file_copy_outlined),
                      label: Text(tr(context, 'Copy progress JSON')),
                    ),
                  ]),
                ]),
                const SizedBox(height: 12),
                _section(tr(context, 'Account actions'), [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () async {
                      await store.signOut();
                      if (mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.logout_rounded),
                    label: Text(tr(context, 'Sign out')),
                  ),
                  const SizedBox(height: 12),
                  Text(tr(context, 'Danger zone'), style:
                    TextStyle(color: colors.error, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _removeAccount,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.error,
                      side: BorderSide(color: colors.error),
                    ),
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: Text(tr(context, 'Delete account')),
                  ),
                ]),
              ],
            ),
          ),
        ),
      );
    },
  );
}
