import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/mobile_widgets.dart';

class DiscoveredSchool {
  final String id;
  final String code;
  final String name;
  final String? address;

  const DiscoveredSchool({required this.id, required this.code, required this.name, this.address});

  factory DiscoveredSchool.fromJson(Map<String, dynamic> json) => DiscoveredSchool(
        id: '${json['id'] ?? ''}',
        code: '${json['code'] ?? ''}',
        name: '${json['name'] ?? ''}',
        address: json['address'] as String?,
      );
}

/// Searches active schools through the public `/tenant-discovery` endpoint.
class SchoolPickerSheet extends StatefulWidget {
  final String? selectedCode;
  const SchoolPickerSheet({super.key, this.selectedCode});

  static Future<DiscoveredSchool?> show(BuildContext context, {String? selectedCode}) =>
      showModalBottomSheet<DiscoveredSchool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => SchoolPickerSheet(selectedCode: selectedCode),
      );

  @override
  State<SchoolPickerSheet> createState() => _SchoolPickerSheetState();
}

class _SchoolPickerSheetState extends State<SchoolPickerSheet> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<DiscoveredSchool> _schools = [];
  bool _loading = true;
  String? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _fetch('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _fetch(String query) async {
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient().dio.get('/tenant-discovery', queryParameters: {
        if (query.trim().isNotEmpty) 'query': query.trim(),
      });
      if (!mounted || id != _requestId) return;
      final list = (res.data['data'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(DiscoveredSchool.fromJson)
          .toList();
      setState(() {
        _schools = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _loading = false;
        _error = apiErrorMessage(e);
      });
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _fetch(value));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final height = MediaQuery.of(context).size.height * 0.75;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.md),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Select your school', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _search,
                  autofocus: false,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Search by school name or code',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: _onChanged,
                  onSubmitted: _fetch,
                ),
              ]),
            ),
            const Divider(height: 1),
            Expanded(child: _buildBody(text)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(TextTheme text) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ListView(padding: const EdgeInsets.all(AppSpacing.xl), children: [
        MessageBanner(message: _error!, onRetry: () => _fetch(_search.text)),
      ]);
    }
    if (_schools.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.search_off, size: 40, color: AppColors.textSubtle),
            const SizedBox(height: AppSpacing.md),
            Text('No schools match "${_search.text}".', style: text.bodyMedium, textAlign: TextAlign.center),
          ]),
        ),
      );
    }
    return ListView.separated(
      itemCount: _schools.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, i) {
        final s = _schools[i];
        final selected = s.code == widget.selectedCode;
        return ListTile(
          minVerticalPadding: 12,
          leading: CircleAvatar(
            backgroundColor: selected ? AppColors.primaryAccent : AppColors.primaryAccentSubtle,
            child: Text(
              s.code.length >= 2 ? s.code.substring(0, 2) : s.code,
              style: TextStyle(fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.primaryAccent),
            ),
          ),
          title: Text(s.name),
          subtitle: Text([s.code, if ((s.address ?? '').isNotEmpty) s.address!].join(' · '),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: selected ? const Icon(Icons.check_circle, color: AppColors.primaryAccent) : null,
          onTap: () => Navigator.pop(context, s),
        );
      },
    );
  }
}
