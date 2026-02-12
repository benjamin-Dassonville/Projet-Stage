import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'app_role.dart';

class AuthState extends ChangeNotifier {
  bool _ready = false;

  sb.Session? _session;
  sb.User? _user;

  AppRole _role = AppRole.nonAssigne;
  String _displayName = 'Utilisateur';

  StreamSubscription<sb.AuthState>? _sub;

  bool get ready => _ready;
  bool get isLoggedIn => _session != null && _user != null;

  AppRole get role => _role;
  String get displayName => _displayName;

  String? get userId => _user?.id;
  String? get email => _getEmailFromUser(_user);
  String? get accessToken => _session?.accessToken;

  Future<void> refreshProfile() async {
    final user = _user;
    if (user == null) return;
    await _syncProfile(user);
    notifyListeners();
  }

  Future<void> init() async {
    final supa = sb.Supabase.instance.client;

    _session = supa.auth.currentSession;
    _user = _session?.user;

    _sub = supa.auth.onAuthStateChange.listen((data) async {
      _session = data.session;
      _user = data.session?.user;

      if (_user != null) {
        await _syncProfile(_user!);
      } else {
        _role = AppRole.nonAssigne;
        _displayName = 'Utilisateur';
      }

      _ready = true;
      notifyListeners();
    });

    if (_user != null) {
      await _syncProfile(_user!);
    }

    _ready = true;
    notifyListeners();
  }

  String? _getEmailFromUser(sb.User? user) {
    if (user == null) return null;

    // Supabase peut mettre email null avec Azure → on récupère via claims
    final meta = user.userMetadata ?? {};
    final candidates = <Object?>[
      user.email,
      meta['email'],
      meta['preferred_username'], // souvent l'UPN: prenom.nom@domaine
      meta['upn'],
      meta['unique_name'],
      meta['name'],
    ];

    for (final c in candidates) {
      final s = (c ?? '').toString().trim();
      if (s.isNotEmpty && s.contains('@')) return s;
    }
    return null;
  }


  /// ✅ Construit "Prénom Nom" si dispo dans user_metadata, sinon fallback.
  String _buildDisplayNameFromUser(sb.User user, {String? fallbackFullName}) {
    final meta = user.userMetadata ?? {};

    final given = (meta['given_name'] ?? meta['first_name'] ?? '').toString().trim();
    final family = (meta['family_name'] ?? meta['last_name'] ?? '').toString().trim();

    final fromParts = ('$given $family').trim();
    if (fromParts.isNotEmpty) return fromParts;

    final fb = (fallbackFullName ?? '').toString().trim();
    if (fb.isNotEmpty) return fb;

    final emailValue = _getEmailFromUser(user);
    if (emailValue != null && emailValue.trim().isNotEmpty) return emailValue.trim();

    return user.id;
  }

  /// ✅ Retourne un full_name "propre" à stocker en DB (priorité: given+family)
  String _buildFullNameForDb(sb.User user) {
    final meta = user.userMetadata ?? {};

    final given = (meta['given_name'] ?? meta['first_name'] ?? '').toString().trim();
    final family = (meta['family_name'] ?? meta['last_name'] ?? '').toString().trim();
    final fromParts = ('$given $family').trim();
    if (fromParts.isNotEmpty) return fromParts;

    // Azure / OIDC selon tenant
    final other = (meta['full_name'] ??
            meta['name'] ??
            meta['displayName'] ??
            meta['preferred_username'] ??
            '')
        .toString()
        .trim();

    // Évite d'écrire l'email dans full_name
    if (other.isNotEmpty && !other.contains('@')) return other;

    return '';
  }

  Future<void> _syncProfile(sb.User user) async {
    final supa = sb.Supabase.instance.client;

    final emailValue = _getEmailFromUser(user);
    final fullNameForDb = _buildFullNameForDb(user);

    // ✅ IMPORTANT : ne pas envoyer des champs null qui cassent des contraintes
    final payload = <String, dynamic>{
      'id': user.id,
      if (emailValue != null) 'email': emailValue,
      if (fullNameForDb.isNotEmpty) 'full_name': fullNameForDb,
    };

    await supa.from('profiles').upsert(payload);

    final row = await supa
        .from('profiles')
        .select('role, full_name, email')
        .eq('id', user.id)
        .maybeSingle();

    _role = AppRoleX.fromDb((row?['role'] ?? 'non_assigne').toString());

    final dbName = (row?['full_name'] ?? '').toString().trim();

    // ✅ DisplayName = Prénom Nom si possible, sinon DB full_name, sinon email.
    _displayName = _buildDisplayNameFromUser(user, fallbackFullName: dbName);
  }

  Future<void> signInWithMicrosoft({required String webRedirectTo}) async {
    final supa = sb.Supabase.instance.client;

    await supa.auth.signInWithOAuth(
      sb.OAuthProvider.azure,
      redirectTo: webRedirectTo,
    );
  }

  Future<void> logout() async {
    await sb.Supabase.instance.client.auth.signOut();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}