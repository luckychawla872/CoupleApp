import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/AuthProvider.dart';
import '../providers/RelationshipProvider.dart';
import 'ConnectionScreen.dart';
import 'ChatScreen.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum AuthMode { login, register, recover }

class _AuthScreenState extends State<AuthScreen> {
  AuthMode _mode = AuthMode.login;
  final _formKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _recoveryPhraseController = TextEditingController();

  String? _selectedGender;
  DateTime? _selectedDob;

  Future<void> _selectDob(BuildContext context) async {
    final initialDate = DateTime.now().subtract(const Duration(days: 365 * 18));
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDob = picked;
      });
    }
  }

  List<String> _generatedWords = [];
  bool _copiedPhrase = false;
  bool _isNewDevice = false;

  void _generateRecoveryPhrase() {
    const wordList = [
      'apple',
      'banana',
      'cherry',
      'date',
      'elderberry',
      'fig',
      'grape',
      'honeydew',
      'kiwi',
      'lemon',
      'mango',
      'nectarine',
      'orange',
      'papaya',
      'quince',
      'raspberry',
      'strawberry',
      'tangerine',
      'ugli',
      'vanilla',
      'watermelon',
      'xenon',
      'yellow',
      'zebra',
      'alpha',
      'bravo',
      'charlie',
      'delta',
      'echo',
      'foxtrot',
      'golf',
      'hotel',
      'india',
      'juliet',
      'kilo',
      'lima',
      'mike',
      'november',
      'oscar',
      'papa',
      'quebec',
      'romeo',
      'sierra',
      'tango',
      'uniform',
      'victor',
      'whiskey',
      'xray',
      'yankee',
      'zulu',
    ];
    final random = Random();
    _generatedWords = List.generate(
      16,
      (_) => wordList[random.nextInt(wordList.length)],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);

    try {
      if (_mode == AuthMode.login) {
        await auth.signIn(
          username: _usernameController.text,
          password: _passwordController.text,
          recoveryPhrase: _isNewDevice ? _recoveryPhraseController.text : null,
        );
      } else if (_mode == AuthMode.register) {
        if (_selectedGender == null || _selectedDob == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select gender and date of birth'),
            ),
          );
          return;
        }

        _generateRecoveryPhrase();
        final phraseStr = _generatedWords.join(' ');

        await auth.signUp(
          username: _usernameController.text,
          password: _passwordController.text,
          name: _nameController.text,
          gender: _selectedGender!,
          dob: DateFormat('yyyy-MM-dd').format(_selectedDob!),
          recoveryPhrase: phraseStr,
        );

        Directory? directory;
        if (Platform.isAndroid) {
          directory = Directory('/storage/emulated/0/Download');
        } else {
          try {
            directory = await getDownloadsDirectory();
          } catch (e) {
            directory = null;
          }
        }

        if (directory != null) {
          final fileName =
              'Recovery Phrases - @${_usernameController.text} - Couple App.md';
          final file = File('${directory.path}/$fileName');
          await file.writeAsString(
            '# Couple Messenger Recovery Phrase\n\nKeep this safe! You will need it to log into new devices and recover your E2EE keys.\n\n**$phraseStr**\n',
          );
        }

        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('Account Created!'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'We have saved a recovery file to your device Downloads folder. Please keep it safe.',
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      phraseStr,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    final fileName =
                        'Recovery Phrases - @${_usernameController.text} - Couple App.md';

                    if (Platform.isAndroid) {
                      final directory = Directory(
                        '/storage/emulated/0/Download',
                      );
                      final file = File('${directory.path}/$fileName');
                      await file.writeAsString(
                        '# Couple Messenger Recovery Phrase\n\nKeep this safe! You will need it to log into new devices and recover your E2EE keys.\n\n**$phraseStr**\n',
                      );
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Saved to Downloads folder!'),
                          ),
                        );
                      }
                    } else {
                      String? outputFile = await FilePicker.saveFile(
                        dialogTitle: 'Save Recovery Phrase',
                        fileName: fileName,
                      );

                      if (outputFile != null) {
                        final customFile = File(outputFile);
                        await customFile.writeAsString(
                          '# Couple Messenger Recovery Phrase\n\nKeep this safe! You will need it to log into new devices and recover your E2EE keys.\n\n**$phraseStr**\n',
                        );
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Saved to custom folder!'),
                            ),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Save Again'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text("I've Saved It, Continue"),
                ),
              ],
            ),
          );
        }
      } else {
        await auth.recoverAccount(
          username: _usernameController.text,
          recoveryPhrase: _recoveryPhraseController.text,
          newPassword: _passwordController.text,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password recovered successfully! Please login.'),
          ),
        );
        setState(() {
          _mode = AuthMode.login;
        });
        return;
      }

      if (mounted && auth.isAuthenticated) {
        final relation = Provider.of<RelationshipProvider>(
          context,
          listen: false,
        );
        if (relation.isPaired) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ChatScreen()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ConnectionScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _pickRecoveryPhraseFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['md', 'txt'],
      );
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        
        // Extract the phrase which should be between ** and **
        final RegExp phraseRegex = RegExp(r'\*\*([a-z ]+)\*\*');
        final match = phraseRegex.firstMatch(content);
        
        setState(() {
          if (match != null && match.groupCount >= 1) {
             _recoveryPhraseController.text = match.group(1)!;
          } else {
             _recoveryPhraseController.text = content.trim(); // fallback if not found
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recovery phrase loaded from file')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to read file: $e')),
        );
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 32.0,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Branding / Logo
                  Icon(
                    Icons.favorite_rounded,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _mode == AuthMode.login
                        ? 'Welcome back'
                        : _mode == AuthMode.register
                        ? 'Create Account'
                        : 'Recover Account',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _mode == AuthMode.login
                        ? 'Enter your details to continue'
                        : _mode == AuthMode.register
                        ? 'Sign up to get started'
                        : 'Follow the steps to recover your account',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Form(
                    key: _formKey,
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_mode == AuthMode.register) ...[
                            TextFormField(
                              controller: _nameController,
                              decoration: _inputDecoration(
                                theme,
                                'Name',
                                Icons.badge_outlined,
                              ),
                              validator: (val) =>
                                  val == null || val.trim().isEmpty
                                  ? 'Enter your name'
                                  : null,
                            ),
                            const SizedBox(height: 20),
                          ],
                          TextFormField(
                            controller: _usernameController,
                            decoration: _inputDecoration(
                              theme,
                              'Username',
                              Icons.person_outline_rounded,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[a-zA-Z0-9._]'),
                              ),
                            ],
                            validator: (val) =>
                                val == null || val.trim().isEmpty
                                ? 'Enter a username'
                                : null,
                          ),
                          if (_mode == AuthMode.register) ...[
                            const SizedBox(height: 20),
                            DropdownButtonFormField<String>(
                              decoration: _inputDecoration(
                                theme,
                                'Gender',
                                Icons.wc_outlined,
                              ),
                              value: _selectedGender,
                              items: const [
                                DropdownMenuItem(
                                  value: 'Male',
                                  child: Text('Male'),
                                ),
                                DropdownMenuItem(
                                  value: 'Female',
                                  child: Text('Female'),
                                ),
                                DropdownMenuItem(
                                  value: 'Other',
                                  child: Text('Other'),
                                ),
                              ],
                              onChanged: (val) =>
                                  setState(() => _selectedGender = val),
                              validator: (val) =>
                                  val == null ? 'Select your gender' : null,
                            ),
                            const SizedBox(height: 20),
                            InkWell(
                              onTap: () => _selectDob(context),
                              borderRadius: BorderRadius.circular(16.0),
                              child: InputDecorator(
                                decoration: _inputDecoration(
                                  theme,
                                  'Date of Birth',
                                  Icons.cake_outlined,
                                ),
                                child: Text(
                                  _selectedDob == null
                                      ? 'Select Date of Birth'
                                      : DateFormat(
                                          'MMMM d, yyyy',
                                        ).format(_selectedDob!),
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: _selectedDob == null
                                        ? theme.colorScheme.onSurfaceVariant
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (_mode == AuthMode.recover) ...[
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _recoveryPhraseController,
                              decoration: _inputDecoration(
                                theme,
                                '16-Word Recovery Phrase',
                                Icons.vpn_key_outlined,
                              ).copyWith(
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.file_upload),
                                  onPressed: _pickRecoveryPhraseFile,
                                  tooltip: 'Upload .md file',
                                ),
                              ),
                              maxLines: 2,
                              validator: (val) =>
                                  val == null || val.trim().isEmpty
                                  ? 'Enter recovery phrase'
                                  : null,
                            ),
                          ],
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: _inputDecoration(
                              theme,
                              _mode == AuthMode.login
                                  ? 'Password'
                                  : 'New Password',
                              Icons.lock_outline_rounded,
                            ),
                            validator: (val) => val == null || val.length < 6
                                ? 'Password must be at least 6 characters'
                                : null,
                          ),
                          if (_mode == AuthMode.login) ...[
                            const SizedBox(height: 12),
                            SwitchListTile(
                              title: const Text('Logging in on a new device?'),
                              subtitle: const Text(
                                'Required to recover your E2EE keys',
                                style: TextStyle(fontSize: 12),
                              ),
                              value: _isNewDevice,
                              onChanged: (val) {
                                setState(() {
                                  _isNewDevice = val;
                                });
                              },
                            ),
                            if (_isNewDevice) ...[
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _recoveryPhraseController,
                                decoration: _inputDecoration(
                                  theme,
                                  '16-Word Recovery Phrase',
                                  Icons.vpn_key_outlined,
                                ),
                                maxLines: 2,
                                validator: (val) =>
                                    val == null || val.trim().isEmpty
                                    ? 'Enter recovery phrase to restore keys'
                                    : null,
                              ),
                            ],
                          ],
                          if (_mode == AuthMode.register) ...[
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: false,
                              decoration: _inputDecoration(
                                theme,
                                'Confirm Password',
                                Icons.lock_open_rounded,
                              ),
                              validator: (val) =>
                                  val != _passwordController.text
                                  ? 'Passwords do not match'
                                  : null,
                            ),
                          ],
                          const SizedBox(height: 32),
                          auth.loading
                              ? const Center(child: CircularProgressIndicator())
                              : FilledButton(
                                  onPressed: _submit,
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16.0,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16.0),
                                    ),
                                  ),
                                  child: Text(
                                    _mode == AuthMode.login
                                        ? 'Login'
                                        : _mode == AuthMode.register
                                        ? 'Sign Up'
                                        : 'Recover Account',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_mode == AuthMode.login) ...[
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _mode = AuthMode.register;
                                      _generatedWords = [];
                                    });
                                  },
                                  child: const Text("Create account"),
                                ),
                                Text(
                                  '•',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.5),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _mode = AuthMode.recover;
                                    });
                                  },
                                  child: const Text("Forgot password?"),
                                ),
                              ] else ...[
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _mode = AuthMode.login;
                                    });
                                  },
                                  child: const Text("Back to Login"),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    ThemeData theme,
    String label,
    IconData icon,
  ) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
      filled: true,
      fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }
}
