import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/SecurityProvider.dart';
import '../providers/AuthProvider.dart';

class LockScreen extends StatefulWidget {
  final Widget child;

  const LockScreen({super.key, required this.child});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _enteredPin = '';
  bool _isError = false;
  late List<String> _shuffledNumbers;

  @override
  void initState() {
    super.initState();
    _shuffledNumbers = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0']..shuffle();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final security = Provider.of<SecurityProvider>(context, listen: false);
      if (security.isLocked && security.isBiometricEnabled) {
        security.authenticateWithBiometrics();
      }
    });
  }

  void _onKeyPress(String digit) {
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += digit;
        _isError = false;
      });

      if (_enteredPin.length == 4) {
        _verifyPin();
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _isError = false;
      });
    }
  }

  Future<void> _verifyPin() async {
    final security = Provider.of<SecurityProvider>(context, listen: false);
    final success = await security.verifyPin(_enteredPin);
    if (!success) {
      setState(() {
        _isError = true;
        _enteredPin = '';
      });
    }
  }

  Widget _buildNumpadButton(String number, ThemeData theme) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Material(
          type: MaterialType.transparency,
          child: Ink(
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _onKeyPress(number),
              splashColor: theme.colorScheme.primary.withOpacity(0.5),
              highlightColor: theme.colorScheme.primary.withOpacity(0.3),
              child: Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                child: Text(
                  number,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFingerprintButton(SecurityProvider security, ThemeData theme) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: security.isBiometricEnabled
            ? Material(
                type: MaterialType.transparency,
                child: Ink(
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => security.authenticateWithBiometrics(),
                    splashColor: theme.colorScheme.primary.withOpacity(0.5),
                    highlightColor: theme.colorScheme.primary.withOpacity(0.3),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      child: Icon(Icons.fingerprint, size: 32, color: theme.colorScheme.primary),
                    ),
                  ),
                ),
              )
            : const SizedBox(),
      ),
    );
  }

  Widget _buildBackspaceButton(ThemeData theme) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Material(
          type: MaterialType.transparency,
          child: Ink(
            decoration: const BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _onBackspace,
              splashColor: theme.colorScheme.error.withOpacity(0.5),
              highlightColor: theme.colorScheme.error.withOpacity(0.3),
              child: Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                child: Icon(Icons.backspace_outlined, size: 32, color: theme.colorScheme.onBackground),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final security = Provider.of<SecurityProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    if (!security.isLocked || !auth.isAuthenticated) {
      return widget.child; // Not locked or not authenticated, show normal app
    }

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Icon(Icons.lock_outline, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 24),
            Text(
              'Enter PIN',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.onBackground,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            // PIN Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < _enteredPin.length
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceVariant,
                    border: Border.all(
                      color: _isError ? theme.colorScheme.error : Colors.transparent,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),
            if (_isError) ...[
              const SizedBox(height: 16),
              Text(
                'Incorrect PIN',
                style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600),
              )
            ],
            const Spacer(),
            // Numpad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  Row(children: _shuffledNumbers.sublist(0, 3).map((n) => _buildNumpadButton(n, theme)).toList()),
                  Row(children: _shuffledNumbers.sublist(3, 6).map((n) => _buildNumpadButton(n, theme)).toList()),
                  Row(children: _shuffledNumbers.sublist(6, 9).map((n) => _buildNumpadButton(n, theme)).toList()),
                  Row(
                    children: [
                      _buildFingerprintButton(security, theme),
                      _buildNumpadButton(_shuffledNumbers[9], theme),
                      _buildBackspaceButton(theme),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
