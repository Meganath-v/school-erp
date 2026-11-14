import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/status_badge.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final _loginController = TextEditingController(text: 'admin@oakridge.edu');
  final _passwordController = TextEditingController(text: 'password123');
  final _schoolCodeController = TextEditingController(text: 'OAK01');
  final _searchController = TextEditingController();

  List<dynamic> _discoveredSchools = [];
  bool _isSearching = false;
  String? _selectedSchoolName = 'Oakridge International School';

  @override
  void initState() {
    super.initState();
    _fetchSchools();
  }

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    _schoolCodeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchSchools([String query = '']) async {
    setState(() => _isSearching = true);
    try {
      final res = await ApiClient().dio.get('/tenant-discovery', queryParameters: {
        if (query.isNotEmpty) 'query': query,
      });
      setState(() {
        _discoveredSchools = res.data['data'] ?? [];
        _isSearching = false;
      });
    } catch (_) {
      setState(() => _isSearching = false);
    }
  }

  void _selectSchool(dynamic school) {
    setState(() {
      _schoolCodeController.text = school['code'];
      _selectedSchoolName = school['name'];
    });
  }

  void _fillDemoCredentials(String email, String roleName, String schoolCode, String schoolName) {
    setState(() {
      _loginController.text = email;
      _passwordController.text = 'password123';
      _schoolCodeController.text = schoolCode;
      _selectedSchoolName = schoolName;
    });
  }

  Future<void> _handleLogin() async {
    final success = await ref.read(authProvider.notifier).login(
          login: _loginController.text.trim(),
          password: _passwordController.text,
          schoolCode: _schoolCodeController.text.trim().isEmpty ? null : _schoolCodeController.text.trim(),
        );

    if (!success && mounted) {
      final error = ref.read(authProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Authentication failed'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 960;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.xxl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1140),
            child: isDesktop ? _buildDesktopLayout(authState) : _buildMobileLayout(authState),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(AuthState authState) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: _buildBrandingAndDiscoveryPanel(),
        ),
        const SizedBox(width: AppSpacing.xxxl),
        Expanded(
          flex: 6,
          child: _buildLoginAndDemoPanel(authState),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(AuthState authState) {
    return Column(
      children: [
        _buildBrandingAndDiscoveryPanel(),
        const SizedBox(height: AppSpacing.xxl),
        _buildLoginAndDemoPanel(authState),
      ],
    );
  }

  Widget _buildBrandingAndDiscoveryPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top System Monogram & Badge
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: AppRadius.mdBorderRadius,
              ),
              child: const Center(
                child: Icon(Icons.school, color: Colors.white, size: 22),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Linways-Grade ERP',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  'Academic & Institutional Management',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text(
          'Unified Campus\nOperating System',
          style: GoogleFonts.outfit(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
            height: 1.15,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'A reliable multi-tenant platform delivering outcome-based education (OBE), fee billing, period attendance, examination broadsheets, and stakeholder portals.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textMedium,
            height: 1.5,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),

        // Institutional Directory Card
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.mdBorderRadius,
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.subtle,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.apartment_outlined, size: 18, color: AppColors.primaryAccent),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Institution Directory',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${_discoveredSchools.length} verified campuses',
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 38,
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.inter(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search by institution name or code...',
                    prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textMuted),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    suffixIcon: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  onChanged: (val) => _fetchSchools(val),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_discoveredSchools.isEmpty && !_isSearching)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Center(
                    child: Text('No schools match your search query', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _discoveredSchools.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, idx) {
                    final s = _discoveredSchools[idx];
                    final isSelected = _schoolCodeController.text == s['code'];

                    return InkWell(
                      onTap: () => _selectSchool(s),
                      borderRadius: AppRadius.smBorderRadius,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primaryAccentSubtle : AppColors.surfaceVariant,
                          borderRadius: AppRadius.smBorderRadius,
                          border: Border.all(
                            color: isSelected ? AppColors.primaryAccent : AppColors.border,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primaryAccent : Colors.white,
                                borderRadius: AppRadius.xsBorderRadius,
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Center(
                                child: Text(
                                  (s['code'] as String).substring(0, 2),
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : AppColors.textDark,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s['name'],
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? AppColors.primaryAccent : AppColors.textDark,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Code: ${s['code']} • Status: ${s['status'] ?? "ACTIVE"}',
                                    style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle, size: 16, color: AppColors.primaryAccent),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoginAndDemoPanel(AuthState authState) {
    return Column(
      children: [
        // Main Sign In Card
        Container(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.mdBorderRadius,
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Workstation Sign In',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Access institutional records, grading, and portal',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  if (_schoolCodeController.text.isNotEmpty)
                    StatusBadge(
                      label: _selectedSchoolName != null ? '$_selectedSchoolName (${_schoolCodeController.text})' : _schoolCodeController.text,
                      variant: BadgeVariant.info,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: AppSpacing.lg),

              Text('Email or Username', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              const SizedBox(height: 6),
              TextField(
                controller: _loginController,
                style: GoogleFonts.inter(fontSize: 13),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.person_outline, size: 18),
                  hintText: 'admin@oakridge.edu',
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              Text('Password', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              const SizedBox(height: 6),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: GoogleFonts.inter(fontSize: 13),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.lock_outline, size: 18),
                  hintText: '••••••••',
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              Text('Campus Code (Optional for Superadmin)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              const SizedBox(height: 6),
              TextField(
                controller: _schoolCodeController,
                style: GoogleFonts.inter(fontSize: 13),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.tag, size: 18),
                  hintText: 'e.g. OAK01 or STX02',
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: authState.isLoading ? null : _handleLogin,
                  child: authState.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'Authenticate & Launch Workspace',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // Quick Role Evaluation Profiles
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.mdBorderRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bolt, color: AppColors.warning, size: 18),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Pre-Configured Role Workstations',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Select any of the 8 enterprise roles below to load verified database credentials:',
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildDemoChip('Platform Owner', 'superadmin@erp.com', 'PLATFORM_OWNER', 'OAK01', 'Oakridge International'),
                  _buildDemoChip('School Admin', 'admin@oakridge.edu', 'SCHOOL_ADMIN', 'OAK01', 'Oakridge International'),
                  _buildDemoChip('Principal', 'principal@oakridge.edu', 'PRINCIPAL', 'OAK01', 'Oakridge International'),
                  _buildDemoChip('Office Staff', 'office@oakridge.edu', 'OFFICE', 'OAK01', 'Oakridge International'),
                  _buildDemoChip('Class Teacher', 'teacher.smith@oakridge.edu', 'CLASS_TEACHER', 'OAK01', 'Oakridge International'),
                  _buildDemoChip('Subject Teacher', 'teacher.jones@oakridge.edu', 'SUBJECT_TEACHER', 'OAK01', 'Oakridge International'),
                  _buildDemoChip('Parent', 'parent.doe@gmail.com', 'PARENT', 'OAK01', 'Oakridge International'),
                  _buildDemoChip('Student', 'student.john@oakridge.edu', 'STUDENT', 'OAK01', 'Oakridge International'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDemoChip(String title, String email, String role, String code, String schoolName) {
    final isCurrent = _loginController.text == email;
    return InkWell(
      onTap: () => _fillDemoCredentials(email, role, code, schoolName),
      borderRadius: AppRadius.smBorderRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isCurrent ? AppColors.primaryAccentSubtle : AppColors.surfaceVariant,
          borderRadius: AppRadius.smBorderRadius,
          border: Border.all(
            color: isCurrent ? AppColors.primaryAccent : AppColors.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCurrent) ...[
              const Icon(Icons.check, size: 12, color: AppColors.primaryAccent),
              const SizedBox(width: 4),
            ],
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                color: isCurrent ? AppColors.primaryAccent : AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
