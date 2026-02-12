enum AppRole { nonAssigne, chef, admin, direction }

extension AppRoleX on AppRole {
  String get label {
    switch (this) {
      case AppRole.nonAssigne:
        return 'Non assigné';
      case AppRole.chef:
        return 'Chef';
      case AppRole.admin:
        return 'Admin';
      case AppRole.direction:
        return 'Direction';
    }
  }

  static AppRole fromDb(String? v) {
    switch ((v ?? '').toLowerCase()) {
      case 'chef':
        return AppRole.chef;
      case 'admin':
        return AppRole.admin;
      case 'direction':
        return AppRole.direction;
      case 'non_assigne':
      default:
        return AppRole.nonAssigne;
    }
  }
}
