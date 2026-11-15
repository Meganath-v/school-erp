import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/mobile_widgets.dart';

/// Validates an optional password typed by the platform owner (empty = generate one).
String? validateOptionalPassword(String? value) {
  final v = value ?? '';
  if (v.isEmpty) return null;
  if (v.length < 8) return 'Use at least 8 characters, or leave blank to generate one';
  if (v.length > 128) return 'Use at most 128 characters';
  return null;
}

/// Shows the result of creating/resetting an admin account. A generated temporary
/// password is displayed once, with a copy button, and is never stored by the app.
Future<void> showAdminCredentialResult(
  BuildContext context, {
  required String title,
  required Map<String, dynamic>? credentials,
}) {
  final email = '${credentials?['email'] ?? ''}';
  final temp = credentials?['temporaryPassword'] as String?;
  final passwordSet = credentials?['passwordSet'] == true;

  return showDialog<void>(
    context: context,
    barrierDismissible: false, // the one-time password must not vanish on a stray tap
    builder: (ctx) {
      final text = Theme.of(ctx).textTheme;
      return AlertDialog(
        icon: const Icon(Icons.check_circle, color: AppColors.success, size: 32),
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Sign-in email', style: text.labelMedium?.copyWith(color: AppColors.textMuted)),
              SelectableText(email, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpacing.md),
              if (temp != null) ...[
                Text('Temporary password', style: text.labelMedium?.copyWith(color: AppColors.textMuted)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.only(left: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: AppRadius.mdBorderRadius,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: SelectableText(temp,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                    IconButton(
                      tooltip: 'Copy password',
                      icon: const Icon(Icons.copy),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: temp));
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Password copied')));
                        }
                      },
                    ),
                  ]),
                ),
                const SizedBox(height: AppSpacing.md),
                const MessageBanner(
                  isError: false,
                  message: 'This password is shown only once. Share it with the admin securely; '
                      'they should change it after signing in (Account → Change password).',
                ),
              ] else if (passwordSet)
                const MessageBanner(isError: false, message: 'The admin can now sign in with the password you entered.')
              else
                MessageBanner(isError: false, message: '${credentials?['note'] ?? 'Done.'}'),
            ],
          ),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
        ],
      );
    },
  );
}

/// Platform owner: set or reset the password of a school's admin account.
class ResetAdminPasswordDialog extends StatefulWidget {
  final Map<String, dynamic> school;
  const ResetAdminPasswordDialog({super.key, required this.school});

  /// Returns the API result (email + temporaryPassword or passwordSet), or null if cancelled.
  static Future<Map<String, dynamic>?> show(BuildContext context, Map<String, dynamic> school) =>
      showDialog<Map<String, dynamic>>(context: context, builder: (_) => ResetAdminPasswordDialog(school: school));

  @override
  State<ResetAdminPasswordDialog> createState() => _ResetAdminPasswordDialogState();
}

class _ResetAdminPasswordDialogState extends State<ResetAdminPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  List<Map<String, dynamic>> _admins = [];
  String? _email;
  bool _loading = true;
  bool _saving = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAdmins();
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _loadAdmins() async {
    try {
      final res = await ApiClient().dio.get('/platform/schools/${widget.school['id']}/admins');
      final list = (res.data['data'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
      setState(() {
        _admins = list;
        _email = list.isNotEmpty ? '${list.first['email']}' : null;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = apiErrorMessage(e);
      });
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false) || _email == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final res = await ApiClient().dio.post(
        '/platform/schools/${widget.school['id']}/admins/reset-password',
        data: {
          'email': _email,
          if (_password.text.isNotEmpty) 'newPassword': _password.text,
        },
      );
      if (mounted) Navigator.pop(context, Map<String, dynamic>.from(res.data['data'] as Map));
    } catch (e) {
      setState(() {
        _saving = false;
        _error = apiErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text('Reset admin password'),
      content: SizedBox(
        width: 420,
        child: _loading
            ? const SizedBox(height: 96, child: Center(child: CircularProgressIndicator()))
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('${widget.school['name']} (${widget.school['code']})',
                          style: text.bodyMedium?.copyWith(color: AppColors.textMuted)),
                      const SizedBox(height: AppSpacing.md),
                      if (_admins.isEmpty && _error == null)
                        const MessageBanner(message: 'This school has no school admin account.')
                      else if (_admins.isNotEmpty)
                        DropdownButtonFormField<String>(
                          initialValue: _email,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Admin account', prefixIcon: Icon(Icons.person_outline)),
                          items: [
                            for (final a in _admins)
                              DropdownMenuItem(
                                value: '${a['email']}',
                                child: Text('${a['name']} · ${a['email']}', overflow: TextOverflow.ellipsis),
                              ),
                          ],
                          onChanged: _saving ? null : (v) => setState(() => _email = v),
                        ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _password,
                        enabled: !_saving && _admins.isNotEmpty,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: 'New password (optional)',
                          helperText: 'Leave blank to generate a one-time temporary password',
                          helperMaxLines: 2,
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _obscure ? 'Show password' : 'Hide password',
                            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: validateOptionalPassword,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text('The admin will be signed out on all devices.',
                          style: text.bodySmall?.copyWith(color: AppColors.textMuted)),
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        MessageBanner(message: _error!),
                      ],
                    ],
                  ),
                ),
              ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving || _loading || _admins.isEmpty ? null : _submit,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Reset password'),
        ),
      ],
    );
  }
}
