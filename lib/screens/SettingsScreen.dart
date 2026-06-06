import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/RelationshipProvider.dart';
import '../providers/AuthProvider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../providers/SecurityProvider.dart';
import '../providers/ThemeProvider.dart';
import 'AuthScreen.dart';
import 'ProfileScreen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final relation = Provider.of<RelationshipProvider>(context);
    final auth = Provider.of<AuthProvider>(context);

    final partnerName = relation.partner?['name'] ?? relation.partner?['username'] ?? 'Partner';
    final dissolutionState = relation.conversation?['dissolution_state'] ?? 'none';
    final isPending = dissolutionState == 'pending';

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Logout Session',
            onPressed: () async {
              await Provider.of<SecurityProvider>(context, listen: false).removePin();
              await auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          // User profile section
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
            child: InkWell(
              borderRadius: BorderRadius.circular(24.0),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                  Hero(
                    tag: 'profile_avatar_hero',
                    child: CircleAvatar(
                      radius: 30,
                      backgroundColor: theme.colorScheme.primary,
                      backgroundImage: auth.profile?['profile_image'] != null 
                          ? CachedNetworkImageProvider(auth.profile!['profile_image']) 
                          : null,
                      child: auth.profile?['profile_image'] == null 
                          ? Text(
                              auth.profile?['name']?.substring(0, 1)?.toUpperCase() ?? 'U',
                              style: TextStyle(color: theme.colorScheme.onPrimary, fontSize: 24, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            auth.profile?['name'] ?? 'User Name',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (auth.profile?['is_verified'] == true) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.verified, color: theme.colorScheme.primary, size: 18),
                          ],
                        ],
                      ),
                      Text(
                        '@${auth.profile?['username'] ?? 'username'}',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          ),
          const SizedBox(height: 20),

          // Active Relationship section
          Text('Your Forever Bond', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.colorScheme.primaryContainer.withOpacity(0.6), theme.colorScheme.surface],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2), width: 1),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Card(
              elevation: 0,
              color: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.favorite, color: Colors.pinkAccent, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Soulmate: $partnerName',
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (relation.partner?['is_verified'] == true) ...[
                                const SizedBox(width: 4),
                                Icon(Icons.verified, color: theme.colorScheme.primary, size: 18),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.pinkAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('Forever', style: TextStyle(color: Colors.pinkAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                  if (isPending) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning, color: theme.colorScheme.error),
                              const SizedBox(width: 8),
                              const Text('Disconnect Pending', style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text('A 24-hour cooling-off period is active. You can cancel this request at any time.'),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: relation.loading ? null : () => relation.cancelDisconnect(),
                                child: const Text('Cancel Disconnect'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: relation.loading ? null : () async {
                                  await relation.confirmDisconnect();
                                  if (context.mounted) {
                                    Navigator.of(context).popUntil((route) => route.isFirst);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.error,
                                  foregroundColor: theme.colorScheme.onError,
                                ),
                                child: const Text('Confirm Immediately'),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ] else ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.heart_broken, color: theme.colorScheme.error),
                      title: const Text('Unpair Connection'),
                      subtitle: const Text('Starts a 24-hour cooling-off period'),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Disconnect Partner?'),
                            content: const Text('Are you sure you want to disconnect? This will place the relationship in a 24-hour transition state.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  relation.requestDisconnect();
                                  Navigator.pop(context);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.error,
                                  foregroundColor: theme.colorScheme.onError,
                                ),
                                child: const Text('Disconnect'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Security & Device section
          Text('Privacy & Security', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.timer_outlined),
                    title: Text('Account Auto-Deletion'),
                    subtitle: Text('Accounts inactive for 90 days are permanently erased.'),
                  ),
                  const Divider(height: 20),
                  FutureBuilder<String>(
                    future: _getDeviceName(),
                    builder: (context, snapshot) {
                      final deviceName = snapshot.data ?? 'Detecting...';
                      final platformName = kIsWeb ? 'Web' : Platform.operatingSystem;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.devices),
                        title: const Text('Active Session'),
                        subtitle: Text('Device: $deviceName\nPlatform: $platformName'),
                      );
                    }
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Appearance section
          Text('Appearance', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Consumer<ThemeProvider>(
                builder: (context, themeProvider, child) {
                  return Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.dark_mode),
                        title: const Text('App Theme'),
                        trailing: DropdownButton<ThemeMode>(
                          value: themeProvider.themeMode,
                          underline: const SizedBox(),
                          focusColor: Colors.transparent,
                          items: const [
                            DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                            DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                            DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                          ],
                          onChanged: (ThemeMode? newMode) {
                            if (newMode != null) {
                              themeProvider.setThemeMode(newMode);
                            }
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Stealth Mode (Android Only)
          if (!kIsWeb && Platform.isAndroid) ...[
            Text('Stealth Mode', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Consumer<SecurityProvider>(
                  builder: (context, security, child) {
                    return Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.pin),
                          title: const Text('App Lock PIN'),
                          subtitle: Text(security.isPinSet ? 'PIN is active' : 'No PIN set'),
                          trailing: ElevatedButton(
                            onPressed: () {
                              if (security.isPinSet) {
                                security.removePin();
                              } else {
                                _showSetPinDialog(context, security);
                              }
                            },
                            child: Text(security.isPinSet ? 'Remove' : 'Set PIN'),
                          ),
                        ),
                        if (security.isPinSet) ...[
                          const Divider(height: 20),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            secondary: const Icon(Icons.fingerprint),
                            title: const Text('Biometric Unlock'),
                            value: security.isBiometricEnabled,
                            onChanged: (val) => security.toggleBiometric(val),
                          ),
                        ],
                        const Divider(height: 20),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.masks),
                          title: const Text('App Disguise'),
                          subtitle: const Text('Change icon and name'),
                          onTap: () => _showDisguiseDialog(context, security),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // About App
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              leading: const Icon(Icons.info_outline),
              title: const Text('About App'),
              subtitle: const Text('Version, features, and developer info'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showAboutAppDialog(context, theme),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<String> _getDeviceName() async {
    if (kIsWeb) return 'Web Browser';
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        return '${info.brand} ${info.model}';
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        return info.name;
      } else if (Platform.isWindows) {
        final info = await deviceInfo.windowsInfo;
        return info.computerName;
      } else if (Platform.isMacOS) {
        final info = await deviceInfo.macOsInfo;
        return info.computerName;
      } else if (Platform.isLinux) {
        final info = await deviceInfo.linuxInfo;
        return info.prettyName;
      }
    } catch (e) {
      return 'Unknown Device';
    }
    return 'Unknown Device';
  }

  void _showSetPinDialog(BuildContext context, SecurityProvider security) {
    String tempPin = '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set 4-Digit PIN'),
        content: TextField(
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          onChanged: (val) => tempPin = val,
          decoration: const InputDecoration(hintText: 'Enter PIN'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (tempPin.length == 4) {
                security.setPin(tempPin);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDisguiseDialog(BuildContext context, SecurityProvider security) {
    final disguises = [
      {'alias': 'com.couple.messenger.MainActivity', 'name': 'Default Chatty', 'icon': Icons.chat},
      {'alias': 'com.couple.messenger.MainActivityCalculator', 'name': 'Calculator', 'icon': Icons.calculate},
      {'alias': 'com.couple.messenger.MainActivityNotes', 'name': 'Quick Notes', 'icon': Icons.notes},
      {'alias': 'com.couple.messenger.MainActivityWeather', 'name': 'Weather', 'icon': Icons.cloud},
      {'alias': 'com.couple.messenger.MainActivityClock', 'name': 'Alarm Clock', 'icon': Icons.access_time},
    ];

    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Disguise'),
        contentPadding: const EdgeInsets.all(16.0),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.0,
            ),
            itemCount: disguises.length,
            itemBuilder: (ctx, i) {
              final d = disguises[i];
              return Card(
                elevation: 0,
                color: theme.colorScheme.surfaceVariant,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    security.changeAppDisguise(d['alias'] as String);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Disguise set to ${d['name']}! Home screen may take a moment to update.')));
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(d['icon'] as IconData, size: 48, color: theme.colorScheme.primary),
                      const SizedBox(height: 12),
                      Text(
                        d['name'] as String,
                        style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showAboutAppDialog(BuildContext context, ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
          title: Row(
            children: [
              Icon(Icons.favorite, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              const Text('About Couple'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Version: 1.0.0 (Material 3)', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                const SizedBox(height: 16),
                Text('Features:', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                const SizedBox(height: 8),
                Text('• Secure real-time messaging\n• End-to-end encryption\n• Adaptive Material 3 Dynamic UI\n• Biometric App Lock & Stealth Mode\n• Live online/offline status updates', style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
                const SizedBox(height: 16),
                Text('Developer:', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                const SizedBox(height: 8),
                Text('Developed with passion by Lucky Chawla.', style: theme.textTheme.bodyMedium),
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceVariant,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const Icon(Icons.email, color: Colors.blueAccent),
                    title: const Text('Email Me'),
                    subtitle: const Text('luckychawla872@gmail.com', style: TextStyle(fontSize: 12)),
                    onTap: () async {
                      final Uri url = Uri.parse('mailto:luckychawla872@gmail.com');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceVariant,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const Icon(Icons.message, color: Colors.green),
                    title: const Text('WhatsApp Me'),
                    subtitle: const Text('+91 9568902453', style: TextStyle(fontSize: 12)),
                    onTap: () async {
                      final Uri url = Uri.parse('https://wa.me/919568902453');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
