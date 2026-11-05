import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

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
          content: Text(error ?? 'Login failed'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
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
        // Left Column: Branding & Tenant Search
        Expanded(
          flex: 5,
          child: _buildBrandingAndDiscoveryPanel(),
        ),
        const SizedBox(width: 32),
        // Right Column: Sign In Card & 1-Click Demo Profiles
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
        const SizedBox(height: 24),
        _buildLoginAndDemoPanel(authState),
      ],
    );
  }

  Widget _buildBrandingAndDiscoveryPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified, size: 16, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                'SaaS Enterprise Release 2.0',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Multi-Tenant\nSchool ERP Platform',
          style: GoogleFonts.outfit(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Complete campus operating system for platform owners, school administrators, principals, teachers, and parents.',
          style: GoogleFonts.inter(
            fontSize: 15,
            color: AppTheme.textMuted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        // Tenant Directory Search
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.school, color: AppTheme.primary, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Find Your School',
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by school name, city, or code...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  onChanged: (val) => _fetchSchools(val),
                ),
                const SizedBox(height: 16),
                Text(
                  'Available School Campuses:',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 8),
                if (_discoveredSchools.isEmpty && !_isSearching)
                  Text('No schools found matching query.', style: GoogleFonts.inter(color: AppTheme.textMuted))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _discoveredSchools.map((s) {
                      final isSelected = _schoolCodeController.text == s['code'];
                      return InkWell(
                        onTap: () => _selectSchool(s),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primary.withOpacity(0.08) : Colors.white,
                            border: Border.all(
                              color: isSelected ? AppTheme.primary : AppTheme.border,
                              width: isSelected ? 1.8 : 1,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: isSelected ? AppTheme.primary : const Color(0xFFE2E8F0),
                                child: Text(
                                  (s['code'] as String).substring(0, 2),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : AppTheme.textDark,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s['name'],
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? AppTheme.primary : AppTheme.textDark,
                                    ),
                                  ),
                                  Text(
                                    'Code: ${s['code']}',
                                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginAndDemoPanel(AuthState authState) {
    return Column(
      children: [
        // Main Login Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Account Sign In',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                    if (_schoolCodeController.text.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.secondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.secondary.withOpacity(0.3)),
                        ),
                        child: Text(
                          _schoolCodeController.text,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.secondary,
                          ),
                        ),
                      ),
                  ],
                ),
                if (_selectedSchoolName != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Campus: $_selectedSchoolName',
                    style: GoogleFonts.inter(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w500),
                  ),
                ],
                const SizedBox(height: 20),
                Text('Email, Username or Phone', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                TextField(
                  controller: _loginController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.person_outline, size: 20),
                    hintText: 'e.g. admin@oakridge.edu',
                  ),
                ),
                const SizedBox(height: 16),
                Text('Password', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.lock_outline, size: 20),
                    hintText: '••••••••',
                  ),
                ),
                const SizedBox(height: 16),
                Text('School Code (Optional)', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                TextField(
                  controller: _schoolCodeController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.tag, size: 20),
                    hintText: 'e.g. OAK01 or STX02',
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: authState.isLoading ? null : _handleLogin,
                    child: authState.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            'Sign In to ERP Portal',
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        // 1-Click Demo Roles Card
        Card(
          color: const Color(0xFFF8FAFC),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt, color: AppTheme.warning, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '1-Click Demo Evaluation Profiles',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Select any role below to pre-populate credentials and test end-to-end workflows:',
                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildDemoChip('👑 Platform Owner', 'superadmin@erp.com', 'PLATFORM_OWNER', 'OAK01', 'Oakridge International'),
                    _buildDemoChip('🏫 School Admin', 'admin@oakridge.edu', 'SCHOOL_ADMIN', 'OAK01', 'Oakridge International'),
                    _buildDemoChip('🎓 Principal', 'principal@oakridge.edu', 'PRINCIPAL', 'OAK01', 'Oakridge International'),
                    _buildDemoChip('👩‍🏫 Class Teacher', 'teacher.smith@oakridge.edu', 'CLASS_TEACHER', 'OAK01', 'Oakridge International'),
                    _buildDemoChip('🔬 Subject Teacher', 'teacher.jones@oakridge.edu', 'SUBJECT_TEACHER', 'OAK01', 'Oakridge International'),
                    _buildDemoChip('👨‍👩‍👦 Parent (Multi-Child)', 'parent.doe@gmail.com', 'PARENT', 'OAK01', 'Oakridge International'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDemoChip(String title, String email, String role, String code, String schoolName) {
    final isCurrent = _loginController.text == email;
    return ActionChip(
      avatar: isCurrent ? const Icon(Icons.check, size: 16, color: AppTheme.primary) : null,
      label: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
          color: isCurrent ? AppTheme.primary : AppTheme.textDark,
        ),
      ),
      backgroundColor: isCurrent ? AppTheme.primary.withOpacity(0.12) : Colors.white,
      side: BorderSide(color: isCurrent ? AppTheme.primary : AppTheme.border),
      onPressed: () => _fillDemoCredentials(email, role, code, schoolName),
    );
  }
}
