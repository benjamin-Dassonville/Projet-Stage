enum AppRole {
  chef,
  admin,
  direction,
}

extension AppRoleX on AppRole {
  String get label {
    switch (this) {
      case AppRole.chef:
        return 'Chef d\'équipe';
      case AppRole.admin:
        return 'Admin';
      case AppRole.direction:
        return 'Direction';
    }
  }

  static AppRole? fromString(String? value) {
    if (value == null) return null;
    for (final r in AppRole.values) {
      if (r.name == value) return r;
    }
    return null;
  }
}
