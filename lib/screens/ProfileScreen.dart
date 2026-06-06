import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/supabase_service.dart';
import '../services/imagekit_service.dart';
import 'package:provider/provider.dart';
import '../providers/SecurityProvider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = SupabaseService();
  final _imageKit = ImageKitService();

  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  
  String? _gender;
  String? _profileImageUrl;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isVerified = false;

  int _dobChanges = 0;
  int _genderChanges = 0;
  
  bool _canChangeUsername = true;
  int _daysUntilUsernameChange = 0;

  String _initialUsername = '';
  String _initialName = '';
  String _initialDob = '';
  String? _initialGender;

  bool get _hasChanges {
    return _usernameController.text.trim() != _initialUsername ||
           _nameController.text.trim() != _initialName ||
           _dobController.text.trim() != _initialDob ||
           _gender != _initialGender;
  }

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_onTextChanged);
    _nameController.addListener(_onTextChanged);
    _dobController.addListener(_onTextChanged);
    _loadProfile();
  }

  void _onTextChanged() {
    setState(() {});
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final profile = await _supabase.getCurrentProfile();
    if (profile != null && mounted) {
      setState(() {
        _usernameController.text = profile['username'] ?? '';
        _nameController.text = profile['name'] ?? '';
        _dobController.text = profile['dob'] ?? '';
        _gender = profile['gender'];
        _profileImageUrl = profile['profile_image'];

        _initialUsername = _usernameController.text;
        _initialName = _nameController.text;
        _initialDob = _dobController.text;
        _initialGender = _gender;
        _isVerified = profile['is_verified'] == true;
        _dobChanges = profile['dob_changes'] ?? 0;
        _genderChanges = profile['gender_changes'] ?? 0;
        
        final lastChangeStr = profile['last_username_change'];
        if (lastChangeStr != null) {
          final lastChange = DateTime.parse(lastChangeStr);
          final diffDays = DateTime.now().toUtc().difference(lastChange).inDays;
          if (diffDays < 14) {
            _canChangeUsername = false;
            _daysUntilUsernameChange = 14 - diffDays;
          }
        }
        
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    Provider.of<SecurityProvider>(context, listen: false).ignoreNextLock();
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.image,
    );

    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      
      setState(() => _isSaving = true);
      
      String fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      String? uploadedUrl = await _imageKit.uploadImage(file, fileName);

      if (uploadedUrl != null) {
        await _supabase.updateProfile(profileImage: uploadedUrl);
        setState(() {
          _profileImageUrl = uploadedUrl;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile image updated!')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload image. Check .env config.')),
          );
        }
      }
      
      setState(() => _isSaving = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final currentProfile = await _supabase.getCurrentProfile();
      if (currentProfile == null) return;

      final currentUsername = currentProfile['username'];
      final currentName = currentProfile['name'];
      final currentDob = currentProfile['dob'];
      final currentGender = currentProfile['gender'];

      String? newUsername = _usernameController.text.trim();
      if (newUsername == currentUsername || newUsername.isEmpty) newUsername = null;

      String? newName = _nameController.text.trim();
      if (newName == currentName || newName.isEmpty) newName = null;

      String? newDob = _dobController.text.trim();
      bool incrementDob = false;
      if (newDob != currentDob && newDob.isNotEmpty) {
        if (_dobChanges >= 3) {
          newDob = null; // Don't save
        } else {
          incrementDob = true;
          _dobChanges++;
        }
      } else {
        newDob = null;
      }

      String? newGender = _gender;
      bool incrementGender = false;
      if (newGender != currentGender && newGender != null) {
        if (_genderChanges >= 1) {
          newGender = null;
        } else {
          incrementGender = true;
          _genderChanges++;
        }
      } else {
        newGender = null;
      }

      await _supabase.updateProfile(
        username: newUsername,
        name: newName,
        dob: newDob,
        gender: newGender,
        incrementDob: incrementDob,
        incrementGender: incrementGender,
      );

      setState(() {
        _initialUsername = _usernameController.text.trim();
        _initialName = _nameController.text.trim();
        _initialDob = _dobController.text.trim();
        _initialGender = _gender;
        _isSaving = false;
      });     
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')),
        );
      }
    }
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  children: [
                    // Avatar
                    Hero(
                      tag: 'profile_avatar_hero',
                      child: Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.hardEdge,
                        child: InkWell(
                          onTap: _isSaving ? null : _pickAndUploadImage,
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 60,
                                backgroundColor: theme.colorScheme.primaryContainer,
                                backgroundImage: _profileImageUrl != null 
                                  ? CachedNetworkImageProvider(_profileImageUrl!) 
                                  : null,
                                child: _profileImageUrl == null
                                  ? Icon(Icons.person, size: 60, color: theme.colorScheme.onPrimaryContainer)
                                  : null,
                              ),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.camera_alt, color: theme.colorScheme.onPrimary, size: 20),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Name Field
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        prefixIcon: const Icon(Icons.badge),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Username Field
                    TextField(
                      controller: _usernameController,
                      enabled: _canChangeUsername,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        prefixIcon: const Icon(Icons.alternate_email),
                        suffixIcon: _isVerified ? Icon(Icons.verified, color: theme.colorScheme.primary) : null,
                        helperText: _canChangeUsername 
                          ? 'You can change this once every 14 days' 
                          : 'Can change again in $_daysUntilUsernameChange days',
                        helperStyle: TextStyle(
                          color: !_canChangeUsername ? theme.colorScheme.error : null
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // DOB Field
                    TextField(
                      controller: _dobController,
                      enabled: _dobChanges < 3,
                      decoration: InputDecoration(
                        labelText: 'Date of Birth (YYYY-MM-DD)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        prefixIcon: const Icon(Icons.cake),
                        helperText: 'Changes remaining: ${3 - _dobChanges}',
                        helperStyle: TextStyle(
                          color: _dobChanges >= 3 ? theme.colorScheme.error : null
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Gender Field
                    DropdownButtonFormField<String>(
                      value: _gender,
                      decoration: InputDecoration(
                        labelText: 'Gender',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        prefixIcon: const Icon(Icons.wc),
                        helperText: 'Changes remaining: ${1 - _genderChanges}',
                        helperStyle: TextStyle(
                          color: _genderChanges >= 1 ? theme.colorScheme.error : null
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(value: 'Female', child: Text('Female')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: _genderChanges >= 1 ? null : (val) {
                        setState(() => _gender = val);
                      },
                    ),
                    const SizedBox(height: 48),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving || !_hasChanges ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                        ),
                        child: _isSaving
                          ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: theme.colorScheme.onPrimary, strokeWidth: 2))
                          : const Text('Save Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nameController.dispose();
    _dobController.dispose();
    super.dispose();
  }
}
