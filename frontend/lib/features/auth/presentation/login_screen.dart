import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/mobile_widgets.dart';
import 'school_picker_sheet.dart';
import 'server_settings_sheet.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const _lastSchoolKey = 'erp_last_school';

  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscure = true;
  DiscoveredSchool? _school;

  @override
  void initState() {
    super.initState();
    _restoreLastSchool();
  }

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // The last chosen school is a convenience, not a credential.
  Future<void> _restoreLastSchool() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_lastSchoolKey);
      if (raw != null && raw.length == 3 && mounted) {
        setState(() => _school = DiscoveredSchool(id: raw[0], code: raw[1], name: raw[2]));
      }
    } catch (_) {}
  }

  Future<void> _rememberSchool(DiscoveredSchool? school) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (school == null) {
        await prefs.remove(_lastSchoolKey);
      } else {
        await prefs.setStringList(_lastSchoolKey, [school.id, school.code, school.name]);
      }
    } catch (_) {}
  }

  Future<void> _pickSchool() async {
    final picked = await SchoolPickerSheet.show(context, selectedCode: _school?.code);
    if (picked != null && mounted) {
      setState(() => _school = picked);
      _rememberSchool(picked);
      ref.read(authProvider.notifier).clearMessages();
    }
  }

  Future<void> _openServerSettings() async {
    final saved = await ServerSettingsSheet.show(context);
    if (mounted) {
      setState(() {});
      if (saved == true) {
        ref.read(authProvider.notifier).clearMessages();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Server address saved and reachable.')),
        );
      }
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final ok = await ref.read(authProvider.notifier).login(
          login: _loginController.text,
          password: _passwordController.text,
          schoolCode: _school?.code,
        );
    if (ok) {
      TextInput.finishAutofillContext();
    } else if (mounted) {
      _passwordController.clear();
    }
  }

  bool _isConnectivityError(String? message) {
    if (message == null) return false;
    final m = message.toLowerCase();
    return m.contains('reach') || m.contains('refused') || m.contains('too long') ||
        m.contains('no server address') || m.contains('network connection') || m.contains('not the ark-erp');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final text = Theme.of(context).textTheme;
    final api = ApiClient();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Brand
                      Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppColors.primaryAccent,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(Icons.school, color: Colors.white, size: 34),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text('Ark-ERP',
                          textAlign: TextAlign.center,
                          style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: AppColors.textDark)),
                      const SizedBox(height: AppSpacing.xs),
                      Text('Sign in to your school account',
                          textAlign: TextAlign.center, style: text.bodyLarge?.copyWith(color: AppColors.textMuted)),
                      const SizedBox(height: AppSpacing.xxl),

                      if (auth.noticeMessage != null) ...[
                        MessageBanner(
                          message: auth.noticeMessage!,
                          isError: false,
                          onDismiss: () => ref.read(authProvider.notifier).clearMessages(),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      if (auth.errorMessage != null) ...[
                        MessageBanner(
                          message: auth.errorMessage!,
                          onDismiss: () => ref.read(authProvider.notifier).clearMessages(),
                        ),
                        if (_isConnectivityError(auth.errorMessage) && AppConfig.allowsRuntimeOverride)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _openServerSettings,
                              icon: const Icon(Icons.dns_outlined, size: 18),
                              label: const Text('Check server settings'),
                            ),
                          ),
                        const SizedBox(height: AppSpacing.lg),
                      ],

                      // School
                      _SchoolField(school: _school, onTap: auth.isLoading ? null : _pickSchool, onClear: () {
                        setState(() => _school = null);
                        _rememberSchool(null);
                      }),
                      const SizedBox(height: AppSpacing.lg),

                      TextFormField(
                        controller: _loginController,
                        enabled: !auth.isLoading,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.username, AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Email or username',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your email or username' : null,
                        onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextFormField(
                        controller: _passwordController,
                        focusNode: _passwordFocus,
                        enabled: !auth.isLoading,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _obscure ? 'Show password' : 'Hide password',
                            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Enter your password';
                          if (v.length < 6) return 'Password must be at least 6 characters';
                          return null;
                        },
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      FilledButton(
                        onPressed: auth.isLoading ? null : _submit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        child: auth.isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                              )
                            : const Text('Sign in'),
                      ),
                      const SizedBox(height: AppSpacing.xxl),

                      // Server indicator
                      Center(
                        child: TextButton.icon(
                          onPressed: auth.isLoading ? null : _openServerSettings,
                          icon: Icon(api.isConfigured ? Icons.dns_outlined : Icons.warning_amber_outlined, size: 18),
                          label: Text(
                            api.isConfigured ? 'Server: ${Uri.parse(api.baseUrl).authority}' : 'Set server address',
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SchoolField extends StatelessWidget {
  final DiscoveredSchool? school;
  final VoidCallback? onTap;
  final VoidCallback onClear;
  const _SchoolField({required this.school, required this.onTap, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: school == null ? 'Select school' : 'School: ${school!.name}. Tap to change.',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        borderRadius: AppRadius.lgBorderRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.lgBorderRadius,
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              borderRadius: AppRadius.lgBorderRadius,
              border: Border.all(color: AppColors.borderStrong),
            ),
            child: Row(children: [
              const Icon(Icons.apartment_outlined, color: AppColors.textMuted),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: school == null
                    ? Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text('Select your school', style: text.bodyLarge),
                        Text('Recommended if you belong to more than one school',
                            style: text.bodySmall?.copyWith(color: AppColors.textMuted)),
                      ])
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(school!.name, style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(school!.code, style: text.bodySmall?.copyWith(color: AppColors.textMuted)),
                      ]),
              ),
              if (school != null)
                IconButton(tooltip: 'Clear school', icon: const Icon(Icons.close), onPressed: onTap == null ? null : onClear)
              else
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ]),
          ),
        ),
      ),
    );
  }
}
