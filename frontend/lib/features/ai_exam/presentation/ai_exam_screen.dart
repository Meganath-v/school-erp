import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/auth/roles.dart';
import 'admin/admin_home.dart';
import 'student/student_home.dart';
import 'teacher/teacher_home.dart';

/// AI Examination entry point; the inner navigation depends on the signed-in role.
class AiExamScreen extends ConsumerWidget {
  const AiExamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider).activeRole;
    if (role == AppRoles.student) return const StudentAiExamHome();
    if (role == AppRoles.schoolAdmin || role == AppRoles.principal) return const AdminAiExamHome();
    return const TeacherAiExamHome();
  }
}
