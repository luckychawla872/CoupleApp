import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/RelationshipProvider.dart';
import '../providers/AuthProvider.dart';
import 'ChatScreen.dart';
import 'AuthScreen.dart';
import 'ProfileScreen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/supabase_service.dart';
import '../providers/SecurityProvider.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> with SingleTickerProviderStateMixin {
  final _codeController = TextEditingController();
  late AnimationController _heartController;
  late Animation<double> _heartScale;
  bool _waitingForPartner = false;
  Map<String, dynamic>? _partnerProfilePreview;
  final Stream<Map<String, dynamic>?> _profileStream = SupabaseService().streamCurrentProfile();

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _heartScale = Tween<double>(begin: 0.9, end: 1.15).animate(
      CurvedAnimation(parent: _heartController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _heartController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _checkPairing(RelationshipProvider relation) {
    if (relation.isPaired) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ChatScreen()),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final relation = Provider.of<RelationshipProvider>(context);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    _checkPairing(relation);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          StreamBuilder<Map<String, dynamic>?>(
            stream: _profileStream,
            builder: (context, snapshot) {
              Widget iconWidget;
              if (snapshot.hasData && snapshot.data != null) {
                final profile = snapshot.data!;
                if (profile['profile_image'] != null) {
                  iconWidget = CircleAvatar(
                    radius: 16,
                    backgroundImage: CachedNetworkImageProvider(profile['profile_image']),
                  );
                } else {
                  final displayName = (profile['name']?.toString().trim().isNotEmpty == true) 
                      ? profile['name'].toString().trim() 
                      : (profile['username']?.toString().trim() ?? 'U');
                  iconWidget = CircleAvatar(
                    radius: 16,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      displayName[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }
              } else {
                iconWidget = CircleAvatar(
                  radius: 16,
                  backgroundColor: theme.colorScheme.tertiaryContainer,
                  child: Icon(Icons.person, size: 18, color: theme.colorScheme.onTertiaryContainer),
                );
              }
              return IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                },
                icon: iconWidget,
                tooltip: 'Profile',
              );
            },
          ),
          IconButton(
            onPressed: () async {
              await Provider.of<SecurityProvider>(context, listen: false).removePin();
              await auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                );
              }
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          )
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _heartScale,
                  child: Icon(
                    Icons.favorite,
                    size: 80,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Connect with Partner',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Couple uses an exclusive relationship lock. You can only pair with exactly one partner.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onBackground.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 32),

                // Pending Request UI (Generator side)
                if (relation.pendingRequest != null)
                  Card(
                    elevation: 4,
                    color: theme.colorScheme.primaryContainer,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.0)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(Icons.person_add, size: 48, color: theme.colorScheme.onPrimaryContainer),
                          const SizedBox(height: 16),
                          Text(
                            'Partner Request!',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Someone has entered your code and wants to pair with you. Do you accept?',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(height: 24),
                          relation.loading 
                            ? const Center(child: CircularProgressIndicator()) 
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  TextButton(
                                    onPressed: () => relation.rejectRequest(),
                                    child: Text('Reject', style: TextStyle(color: theme.colorScheme.error)),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => relation.acceptRequest(),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: theme.colorScheme.primary,
                                      foregroundColor: theme.colorScheme.onPrimary,
                                    ),
                                    child: const Text('Accept Connection'),
                                  ),
                                ],
                              )
                        ],
                      ),
                    ),
                  )
                else if (_waitingForPartner)
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.0)),
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 24),
                          Text(
                            'Request Sent!',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Waiting for your partner to accept...',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 24),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _waitingForPartner = false;
                                _codeController.clear();
                              });
                            },
                            child: const Text('Cancel'),
                          )
                        ],
                      ),
                    ),
                  )
                else
                  // Standard Code Generation & Entry UI
                  Column(
                    children: [
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.0)),
                        color: theme.colorScheme.surfaceVariant,
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Option 1: Share Your Code',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 12),
                              relation.activeCode == null
                                  ? ElevatedButton(
                                      onPressed: relation.loading
                                          ? null
                                          : () => relation.generateCode(),
                                      child: const Text('Generate Couple Code'),
                                    )
                                  : Container(
                                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surface,
                                        borderRadius: BorderRadius.circular(16.0),
                                        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            relation.activeCode!,
                                            style: theme.textTheme.headlineLarge?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 4.0,
                                              color: theme.colorScheme.primary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Waiting for partner...',
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: theme.colorScheme.onBackground.withOpacity(0.5),
                                            ),
                                          ),
                                          if (relation.codeExpiresAt != null) ...[
                                            const SizedBox(height: 8),
                                            CountdownText(
                                              expiresAt: relation.codeExpiresAt!,
                                              onExpire: () {
                                                relation.clearCode();
                                              },
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text('OR', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                          ),
                          Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.0)),
                        color: theme.colorScheme.surface,
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                "Option 2: Enter Partner's Code",
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              if (_partnerProfilePreview == null) ...[
                                TextField(
                                  controller: _codeController,
                                  decoration: InputDecoration(
                                    labelText: '6-Digit Code',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.0)),
                                  ),
                                  keyboardType: TextInputType.number,
                                  maxLength: 6,
                                ),
                                const SizedBox(height: 8),
                                relation.loading
                                    ? const Center(child: CircularProgressIndicator())
                                    : ElevatedButton(
                                        onPressed: () async {
                                          if (_codeController.text.length == 6) {
                                            try {
                                              final profile = await relation.fetchProfileByCode(_codeController.text);
                                              if (mounted) {
                                                setState(() {
                                                  _partnerProfilePreview = profile;
                                                });
                                              }
                                            } catch (e) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text(e.toString())),
                                                );
                                              }
                                            }
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Please enter a valid 6-digit code')),
                                            );
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: theme.colorScheme.primary,
                                          foregroundColor: theme.colorScheme.onPrimary,
                                        ),
                                        child: const Text('Find Partner'),
                                      ),
                              ] else ...[
                                // Show profile card
                                Card(
                                  color: theme.colorScheme.primaryContainer,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      children: [
                                        CircleAvatar(
                                          radius: 40,
                                          backgroundImage: _partnerProfilePreview!['profile_image'] != null
                                              ? CachedNetworkImageProvider(_partnerProfilePreview!['profile_image'])
                                              : null,
                                          backgroundColor: theme.colorScheme.surface,
                                          child: _partnerProfilePreview!['profile_image'] == null
                                              ? Icon(Icons.person, size: 40, color: theme.colorScheme.onSurface)
                                              : null,
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                _partnerProfilePreview!['name'] ?? 'Unknown',
                                                style: theme.textTheme.titleLarge?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: theme.colorScheme.onPrimaryContainer,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (_partnerProfilePreview!['is_verified'] == true) ...[
                                              const SizedBox(width: 4),
                                              Icon(Icons.verified, color: theme.colorScheme.primary, size: 20),
                                            ],
                                          ],
                                        ),
                                        Text(
                                          '@${_partnerProfilePreview!['username'] ?? 'unknown'}',
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8),
                                          ),
                                        ),
                                        if (_partnerProfilePreview!['gender'] != null)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4.0),
                                            child: Text(
                                              _partnerProfilePreview!['gender'],
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: theme.colorScheme.onPrimaryContainer.withOpacity(0.6),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                relation.loading
                                    ? const Center(child: CircularProgressIndicator())
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          TextButton(
                                            onPressed: () {
                                              setState(() {
                                                _partnerProfilePreview = null;
                                                _codeController.clear();
                                              });
                                            },
                                            child: Text('Cancel', style: TextStyle(color: theme.colorScheme.error)),
                                          ),
                                          ElevatedButton(
                                            onPressed: () async {
                                              try {
                                                await relation.connectWithCode(_codeController.text);
                                                if (mounted) {
                                                  setState(() {
                                                    _waitingForPartner = true;
                                                    _partnerProfilePreview = null;
                                                  });
                                                }
                                              } catch (e) {
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text(e.toString())),
                                                  );
                                                }
                                              }
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: theme.colorScheme.primary,
                                              foregroundColor: theme.colorScheme.onPrimary,
                                            ),
                                            child: const Text('Send Request'),
                                          ),
                                        ],
                                      ),
                              ]
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CountdownText extends StatefulWidget {
  final DateTime expiresAt;
  final VoidCallback onExpire;

  const CountdownText({super.key, required this.expiresAt, required this.onExpire});

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  late Timer _timer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  void _updateTime() {
    final now = DateTime.now();
    if (widget.expiresAt.isAfter(now)) {
      if (mounted) {
        setState(() {
          _timeLeft = widget.expiresAt.difference(now);
        });
      }
    } else {
      _timer.cancel();
      widget.onExpire();
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _timeLeft.inMinutes;
    final seconds = _timeLeft.inSeconds % 60;
    return Text(
      'Expires in $minutes:${seconds.toString().padLeft(2, '0')}',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.error,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
