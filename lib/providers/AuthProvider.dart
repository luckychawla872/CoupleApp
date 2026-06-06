import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/encryption_service.dart';

class AuthProvider extends ChangeNotifier {
  final _supabase = SupabaseService();
  User? _user;
  Map<String, dynamic>? _profile;
  bool _loading = false;

  User? get user => _user;
  Map<String, dynamic>? get profile => _profile;
  bool get loading => _loading;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _init();
  }

  void _init() {
    _user = _supabase.client.auth.currentUser;
    _supabase.client.auth.onAuthStateChange.listen((data) async {
      _user = data.session?.user;
      if (_user != null) {
        await EncryptionService().loadKeysFromStorage();
        await fetchProfile();
      } else {
        _profile = null;
      }
      notifyListeners();
    });
  }

  Future<void> fetchProfile() async {
    _profile = await _supabase.getCurrentProfile();
    notifyListeners();
  }

  Future<void> signUp({
    required String username,
    required String password,
    required String name,
    required String gender,
    required String dob,
    required String recoveryPhrase,
  }) async {
    _loading = true;
    notifyListeners();
    try {
      await _supabase.signUp(
        username: username,
        password: password,
        name: name,
        gender: gender,
        dob: dob,
        recoveryPhrase: recoveryPhrase,
      );
      await fetchProfile();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> signIn({
    required String username,
    required String password,
    String? recoveryPhrase,
  }) async {
    _loading = true;
    notifyListeners();
    try {
      final encryption = EncryptionService();
      
      if (recoveryPhrase != null && recoveryPhrase.isNotEmpty) {
        await encryption.initializeKeysFromPhrase(recoveryPhrase);
      } else {
        final hasKeys = await encryption.loadKeysFromStorage();
        if (!hasKeys) {
          throw Exception('E2EE Keys not found. Please provide your 16-word recovery phrase to log in on this device.');
        }
      }

      await _supabase.signIn(username: username, password: password);
      await fetchProfile();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _loading = true;
    notifyListeners();
    try {
      await EncryptionService().clearKeys();
      await _supabase.signOut();
      _user = null;
      _profile = null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> recoverAccount({
    required String username,
    required String recoveryPhrase,
    required String newPassword,
  }) async {
    _loading = true;
    notifyListeners();
    try {
      await _supabase.recoverPassword(
        username: username,
        recoveryPhrase: recoveryPhrase,
        newPassword: newPassword,
      );
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
