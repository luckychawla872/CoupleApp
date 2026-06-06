import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class SecurityProvider extends ChangeNotifier with WidgetsBindingObserver {
  final _storage = const FlutterSecureStorage();
  final _localAuth = LocalAuthentication();
  static const MethodChannel _platform = MethodChannel('com.chatty/stealth');

  bool _isLocked = false;
  bool _isPinSet = false;
  bool _isBiometricEnabled = false;
  bool _ignoreNextLock = false;

  bool get isLocked => _isLocked;
  bool get isPinSet => _isPinSet;
  bool get isBiometricEnabled => _isBiometricEnabled;

  void ignoreNextLock() {
    _ignoreNextLock = true;
  }

  SecurityProvider() {
    WidgetsBinding.instance.addObserver(this);
    _initSecurity();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Timer? _lockTimer;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden || state == AppLifecycleState.detached) {
      if (_ignoreNextLock) {
        // Do not lock.
      } else if (_isPinSet) {
        _lockTimer?.cancel();
        _lockTimer = Timer(const Duration(seconds: 3), () {
          _isLocked = true;
          notifyListeners();
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      _lockTimer?.cancel();
      if (_ignoreNextLock) {
        _ignoreNextLock = false;
      } else if (_isPinSet && _isLocked) {
        // App is resumed and locked, wait for user to unlock
      }
    }
  }

  Future<void> _initSecurity() async {
    final pin = await _storage.read(key: 'app_pin');
    final biometric = await _storage.read(key: 'biometric_enabled');
    
    _isPinSet = pin != null && pin.isNotEmpty;
    _isBiometricEnabled = biometric == 'true';
    
    if (_isPinSet) {
      _isLocked = true;
    }
    notifyListeners();
  }

  Future<void> setPin(String pin) async {
    await _storage.write(key: 'app_pin', value: pin);
    _isPinSet = true;
    notifyListeners();
  }

  Future<void> removePin() async {
    await _storage.delete(key: 'app_pin');
    await _storage.delete(key: 'biometric_enabled');
    _isPinSet = false;
    _isBiometricEnabled = false;
    _isLocked = false;
    notifyListeners();
  }

  Future<bool> verifyPin(String pin) async {
    final storedPin = await _storage.read(key: 'app_pin');
    if (storedPin == pin) {
      _isLocked = false;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> toggleBiometric(bool enable) async {
    if (enable) {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      if (!canCheck || !isSupported) return;
    }
    await _storage.write(key: 'biometric_enabled', value: enable.toString());
    _isBiometricEnabled = enable;
    notifyListeners();
  }

  Future<bool> authenticateWithBiometrics() async {
    if (!_isBiometricEnabled) return false;
    
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to unlock Chatty',
        persistAcrossBackgrounding: true,
        biometricOnly: true,
      );
      
      if (authenticated) {
        _isLocked = false;
        notifyListeners();
      }
      return authenticated;
    } catch (e) {
      return false;
    }
  }

  Future<bool> changeAppDisguise(String aliasName) async {
    try {
      final result = await _platform.invokeMethod<bool>('changeAppIcon', {'aliasName': aliasName});
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }
}
