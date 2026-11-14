import 'dart:async';
import 'package:flutter/material.dart';
import '../network/api_client.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'status_badge.dart';

class OmniSearchResult {
  final String id;
  final String type;
  final String title;
  final String subtitle;
  final String? status;
  final String routeTarget;
  final Map<String, dynamic>? metadata;

  OmniSearchResult({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    this.status,
    required this.routeTarget,
    this.metadata,
  });

  factory OmniSearchResult.fromJson(Map<String, dynamic> json) {
    return OmniSearchResult(
      id: json['id'] ?? '',
      type: json['type'] ?? 'ALL',
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      status: json['status'],
      routeTarget: json['routeTarget'] ?? '',
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

class OmniSearchDialog extends StatefulWidget {
  final Function(OmniSearchResult)? onNavigateToResult;

  const OmniSearchDialog({super.key, this.onNavigateToResult});

  static Future<OmniSearchResult?> show(BuildContext context, {Function(OmniSearchResult)? onNavigate}) {
    return showDialog<OmniSearchResult>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => OmniSearchDialog(onNavigateToResult: onNavigate),
    );
  }

  @override
  State<OmniSearchDialog> createState() => _OmniSearchDialogState();
}

class _OmniSearchDialogState extends State<OmniSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  bool _isLoading = false;
  String _selectedCategory = 'ALL';
  List<OmniSearchResult> _results = [];
  String? _errorMessage;

  final List<Map<String, String>> _categories = const [
    {'id': 'ALL', 'label': 'All Domains'},
    {'id': 'STUDENT', 'label': 'Students'},
    {'id': 'STAFF', 'label': 'Staff & Faculty'},
    {'id': 'CLASS', 'label': 'Classes'},
    {'id': 'SUBJECT', 'label': 'Subjects'},
    {'id': 'CIRCULAR', 'label': 'Circulars'},
    {'id': 'ASSIGNMENT', 'label': 'Assignments'},
    {'id': 'INVOICE', 'label': 'Invoices'},
    {'id': 'RECEIPT', 'label': 'Receipts'},
    {'id': 'EXAM', 'label': 'Exams'},
  ];

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiClient().dio.get(
        '/search',
        queryParameters: {
          'q': query,
          'type': _selectedCategory,
          'limit': 15,
        },
      );

      final data = res.data['data'] as Map<String, dynamic>? ?? {};
      final rawResults = (data['results'] as List<dynamic>?) ?? [];
      final parsed = rawResults.map((r) => OmniSearchResult.fromJson(r as Map<String, dynamic>)).toList();

      setState(() {
        _results = parsed;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Search query failed: $e';
        _isLoading = false;
      });
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'STUDENT':
        return Icons.school_outlined;
      case 'STAFF':
        return Icons.badge_outlined;
      case 'CLASS':
        return Icons.meeting_room_outlined;
      case 'SUBJECT':
        return Icons.menu_book_outlined;
      case 'CIRCULAR':
        return Icons.campaign_outlined;
      case 'ASSIGNMENT':
        return Icons.assignment_outlined;
      case 'INVOICE':
        return Icons.receipt_long_outlined;
      case 'RECEIPT':
        return Icons.receipt_outlined;
      case 'EXAM':
        return Icons.grade_outlined;
      default:
        return Icons.search;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'STUDENT':
        return AppColors.primaryAccent;
      case 'STAFF':
        return AppColors.secondary;
      case 'CLASS':
        return const Color(0xFF6366F1);
      case 'SUBJECT':
        return const Color(0xFF8B5CF6);
      case 'CIRCULAR':
        return AppColors.warning;
      case 'ASSIGNMENT':
        return const Color(0xFFEC4899);
      case 'INVOICE':
        return const Color(0xFF10B981);
      case 'RECEIPT':
        return const Color(0xFF059669);
      case 'EXAM':
        return AppColors.primary;
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
        child: Column(
          children: [
            // Top Search Input Header
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: AppColors.primaryAccent, size: 22),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Search students, staff, classes, subjects, invoices, exams...',
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textDark),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                  if (_isLoading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryAccent),
                    )
                  else if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18, color: AppColors.textMuted),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Category Filter Pills
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
              decoration: const BoxDecoration(
                color: AppColors.surfaceVariant,
                border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
              ),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (ctx, i) {
                  final cat = _categories[i];
                  final isSelected = _selectedCategory == cat['id'];
                  return ChoiceChip(
                    label: Text(cat['label']!),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    backgroundColor: Colors.white,
                    labelStyle: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : AppColors.textDark,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
                    ),
                    onSelected: (val) {
                      if (val) {
                        setState(() => _selectedCategory = cat['id']!);
                        _performSearch(_searchController.text.trim());
                      }
                    },
                  );
                },
              ),
            ),

            // Results List
            Expanded(
              child: _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(fontSize: 13, color: AppColors.error),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : _searchController.text.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.saved_search, size: 48, color: AppColors.textSubtle),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Type a keyword to search institutional records',
                                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Queries 9 core domains in real-time with multi-tenant isolation',
                                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSubtle),
                              ),
                            ],
                          ),
                        )
                      : _results.isEmpty && !_isLoading
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.search_off, size: 48, color: AppColors.textSubtle),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    'No matching records found for "${_searchController.text}"',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Try another name, admission number, subject code, or filter category.',
                                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _results.length,
                              separatorBuilder: (_, _) => const Divider(height: 1, indent: 56),
                              itemBuilder: (ctx, index) {
                                final r = _results[index];
                                final icon = _getIconForType(r.type);
                                final color = _getColorForType(r.type);

                                return ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: color.withValues(alpha: 0.12),
                                    child: Icon(icon, color: color, size: 18),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          r.title,
                                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (r.status != null) ...[
                                        const SizedBox(width: 8),
                                        StatusBadge.fromStatus(r.status!, isSmall: true),
                                      ],
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceVariant,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          r.type,
                                          style: GoogleFonts.inter(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    r.subtitle,
                                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.textSubtle),
                                  onTap: () {
                                    Navigator.pop(context, r);
                                    if (widget.onNavigateToResult != null) {
                                      widget.onNavigateToResult!(r);
                                    }
                                  },
                                );
                              },
                            ),
            ),

            // Footer Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: const BoxDecoration(
                color: AppColors.surfaceVariant,
                border: Border(top: BorderSide(color: AppColors.border, width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.keyboard_return, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text('Click to navigate to module', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                  Text('${_results.length} matches', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
