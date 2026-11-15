/// The eight roles issued by the backend (`UserSchoolMembership.defaultRole`).
class AppRoles {
  AppRoles._();

  static const platformOwner = 'PLATFORM_OWNER';
  static const schoolAdmin = 'SCHOOL_ADMIN';
  static const office = 'OFFICE';
  static const principal = 'PRINCIPAL';
  static const classTeacher = 'CLASS_TEACHER';
  static const subjectTeacher = 'SUBJECT_TEACHER';
  static const parent = 'PARENT';
  static const student = 'STUDENT';

  static const all = [
    platformOwner,
    schoolAdmin,
    office,
    principal,
    classTeacher,
    subjectTeacher,
    parent,
    student,
  ];

  static bool isKnown(String? role) => role != null && all.contains(role);

  static String label(String? role) {
    switch (role) {
      case platformOwner:
        return 'Platform Owner';
      case schoolAdmin:
        return 'School Admin';
      case office:
        return 'Office';
      case principal:
        return 'Principal';
      case classTeacher:
        return 'Class Teacher';
      case subjectTeacher:
        return 'Subject Teacher';
      case parent:
        return 'Parent';
      case student:
        return 'Student';
      default:
        return role == null || role.isEmpty ? 'No role' : role;
    }
  }
}
