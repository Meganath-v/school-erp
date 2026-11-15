import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/mobile_widgets.dart';

/// Lets developers/testers point a debug build at the right backend
/// (emulator host, or the PC's LAN IP from a physical phone) and test it.
class ServerSettingsSheet extends StatefulWidget {
  const ServerSettingsSheet({super.key});

  static Future<bool?> show(BuildContext context) => showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const ServerSettingsSheet(),
      );

  @override
  State<ServerSettingsSheet> createState() => _ServerSettingsSheetState();
}

class _ServerSettingsSheetState extends State<ServerSettingsSheet> {
  final _api = ApiClient();
  late final TextEditingController _controller;
  bool _busy = false;
  String? _result;
  bool _resultOk = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _api.baseUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _normalized() {
    try {
      final url = AppConfig.normalizeBaseUrl(_controller.text, defaultPort: AppConfig.defaultPort);
      final problem = AppConfig.validateBaseUrl(url);
      if (problem != null) {
        setState(() {
          _result = problem;
          _resultOk = false;
        });
        return null;
      }
      return url;
    } on FormatException catch (e) {
      setState(() {
        _result = e.message;
        _resultOk = false;
      });
      return null;
    }
  }

  Future<void> _test() async {
    final url = _normalized();
    if (url == null) return;
    setState(() {
      _busy = true;
      _result = null;
    });
    final error = await _api.checkConnection(url);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _resultOk = error == null;
      _result = error == null ? 'Connected to the Ark-ERP API at $url' : error.message;
    });
  }

  Future<void> _save() async {
    final url = _normalized();
    if (url == null) return;
    setState(() => _busy = true);
    try {
      await _api.saveServerAddress(url);
      final error = await _api.checkConnection();
      if (!mounted) return;
      if (error == null) {
        Navigator.pop(context, true);
        return;
      }
      setState(() {
        _resultOk = false;
        _result = 'Saved, but the server is not answering yet: ${error.message}';
      });
    } on FormatException catch (e) {
      setState(() {
        _resultOk = false;
        _result = e.message;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    await _api.resetServerAddress();
    if (!mounted) return;
    setState(() {
      _controller.text = _api.baseUrl;
      _result = _api.isConfigured ? 'Restored the address built into this app.' : 'This build has no default address.';
      _resultOk = _api.isConfigured;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final canEdit = AppConfig.allowsRuntimeOverride;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Server settings', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Build profile: ${AppConfig.describeEnvironment(AppConfig.environment)}',
                style: text.bodyMedium?.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _controller,
                enabled: canEdit && !_busy,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'API server address',
                  hintText: '192.168.1.20:3000',
                  prefixIcon: Icon(Icons.dns_outlined),
                ),
                onSubmitted: (_) => _test(),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (canEdit)
                Wrap(spacing: AppSpacing.sm, children: [
                  ActionChip(
                    label: const Text('Android emulator'),
                    onPressed: () => _controller.text = 'http://10.0.2.2:${AppConfig.defaultPort}${AppConfig.apiPath}',
                  ),
                  ActionChip(
                    label: const Text('This computer'),
                    onPressed: () => _controller.text = 'http://localhost:${AppConfig.defaultPort}${AppConfig.apiPath}',
                  ),
                ]),
              const SizedBox(height: AppSpacing.md),
              Text(
                canEdit
                    ? 'On a physical phone, enter your computer\'s Wi-Fi IP address and port 3000 (for example 192.168.1.20:3000). '
                        'The phone and computer must be on the same Wi-Fi, and the computer\'s firewall must allow port 3000.'
                    : 'This release build uses a fixed HTTPS server address.',
                style: text.bodySmall?.copyWith(color: AppColors.textMuted, height: 1.4),
              ),
              if (_result != null) ...[
                const SizedBox(height: AppSpacing.md),
                MessageBanner(message: _result!, isError: !_resultOk),
              ],
              const SizedBox(height: AppSpacing.lg),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : _test,
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    child: _busy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Test connection'),
                  ),
                ),
                if (canEdit) ...[
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : _save,
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ]),
              if (canEdit)
                TextButton(onPressed: _busy ? null : _reset, child: const Text('Reset to build default')),
            ],
          ),
        ),
      ),
    );
  }
}
