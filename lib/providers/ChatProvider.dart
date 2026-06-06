import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cryptography/cryptography.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:file_picker/file_picker.dart';
import '../services/supabase_service.dart';
import '../services/encryption_service.dart';
import 'dart:math';

class ChatProvider extends ChangeNotifier {
  final _supabase = SupabaseService();
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _pendingMessages = [];
  bool _loading = false;
  StreamSubscription? _msgSubscription;
  RealtimeChannel? _messagesChannel;
  String? _currentConversationId;
  SecretKey? _sharedSecret;
  DateTime? _chatClearedAt;

  RealtimeChannel? _typingChannel;
  bool _isPartnerTyping = false;
  bool _isCurrentlyTyping = false;
  Timer? _typingTimer;
  Timer? _localCleanupTimer;

  List<Map<String, dynamic>> get messages {
    final messageIds = _messages.map((m) => m['id']).toSet();
    final uniquePending = _pendingMessages.where((p) => !messageIds.contains(p['id'])).toList();
    return [..._messages, ...uniquePending];
  }
  bool get loading => _loading;
  bool get isPartnerTyping => _isPartnerTyping;
  SecretKey? get sharedSecret => _sharedSecret;

  Future<void> initializeSharedSecret(String partnerPublicKey) async {
    try {
      _sharedSecret = await EncryptionService().deriveSharedSecret(partnerPublicKey);
      if (_currentConversationId != null && _sharedSecret != null) {
        _startMessageStream(_currentConversationId!);
      }
    } catch (e) {
      print('Error initializing shared secret: $e');
    }
  }

  void setConversationId(String? conversationId, String? partnerPublicKey) {
    if (_currentConversationId == conversationId) return;
    
    // Clean up typing for old conversation
    _cleanTyping();

    _currentConversationId = conversationId;
    _msgSubscription?.cancel();
    _messagesChannel?.unsubscribe();
    _messagesChannel = null;
    _sharedSecret = null;
    
    if (conversationId != null) {
      _loading = _messages.isEmpty;
      SharedPreferences.getInstance().then((prefs) {
        final clearedAtStr = prefs.getString('chat_cleared_at_$conversationId');
        if (clearedAtStr != null) {
          _chatClearedAt = DateTime.parse(clearedAtStr);
        } else {
          _chatClearedAt = null;
        }
      });
      _loadCachedMessages(conversationId);
      _startLocalCleanupTimer();
      _pruneOldMessages();
      
      if (partnerPublicKey != null) {
        EncryptionService().deriveSharedSecret(partnerPublicKey).then((secret) {
          _sharedSecret = secret;
          _startMessageStream(conversationId);
        }).catchError((err) {
          print('Error deriving secret: $err');
          _startMessageStream(conversationId);
        });
      } else {
        _startMessageStream(conversationId);
      }
      _setupTypingChannel(conversationId);
    } else {
      _localCleanupTimer?.cancel();
      _messages = [];
      _loading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> _decryptMessage(Map<String, dynamic> msg) async {
    final msgCopy = Map<String, dynamic>.from(msg);
    if (_sharedSecret == null) return msgCopy;
    try {
      if (msgCopy['encrypted_payload'] != null && msgCopy['nonce'] != 'mock_nonce') {
        final decrypted = await EncryptionService().decryptPayload(
          msgCopy['encrypted_payload'], 
          _sharedSecret!
        );
        msgCopy['encrypted_payload'] = decrypted;
      }
      if (msgCopy['encrypted_reactions'] != null) {
        final decryptedReactions = await EncryptionService().decryptPayload(
          msgCopy['encrypted_reactions'],
          _sharedSecret!
        );
        msgCopy['encrypted_reactions'] = decryptedReactions;
      }
    } catch (e) {
      print('DECRYPTION FAILURE: $e for message ID: ${msg['id']}');
      msgCopy['encrypted_payload'] = '[Decryption Failed]';
    }
    return msgCopy;
  }

  void _startMessageStream(String conversationId) async {
    _msgSubscription?.cancel();
    _messagesChannel?.unsubscribe();
    
    _loading = _messages.isEmpty;
    notifyListeners();
    
    _msgSubscription = _supabase.streamMessages(conversationId, _sharedSecret).listen((messages) {
      if (_chatClearedAt != null) {
        _messages = messages.where((m) {
          try {
            final sentAt = DateTime.parse(m['sent_at'] ?? m['created_at']);
            return sentAt.isAfter(_chatClearedAt!);
          } catch (_) {
            return true;
          }
        }).toList();
      } else {
        _messages = messages;
      }
      
      // Immediately clear typing indicator if the message is from the partner
      final currentUserId = _supabase.client.auth.currentUser?.id;
      if (_messages.isNotEmpty) {
        final lastMsg = _messages.last;
        if (lastMsg['sender_id'] != currentUserId) {
          _isPartnerTyping = false;
        }
      }
      
      _loading = false;
      notifyListeners();
      _saveMessagesToCache(conversationId, _messages);
      _supabase.markMessagesAsRead(conversationId);
    }, onError: (err) {
      print('Error in message stream: $err');
      _loading = false;
      notifyListeners();
    });
  }

  Future<void> _loadCachedMessages(String conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'chat_cache_$conversationId';
      final cachedData = prefs.getString(cacheKey);
      if (cachedData != null) {
        final List<dynamic> decoded = jsonDecode(cachedData);
        final now = DateTime.now().toUtc();
        
        final filteredMessages = decoded.map((e) => Map<String, dynamic>.from(e)).where((msg) {
          final dateStr = msg['sent_at'] ?? msg['created_at'];
          if (dateStr == null) return true;
          final sentAt = DateTime.tryParse(dateStr);
          if (sentAt == null) return true;
          return now.difference(sentAt).inHours < 24;
        }).toList();

        _messages = filteredMessages;
        _loading = false;
        notifyListeners();
      }
    } catch (e) {
      print('Error loading chat cache: $e');
    }
  }

  Future<void> _saveMessagesToCache(String conversationId, List<Map<String, dynamic>> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'chat_cache_$conversationId';
      
      final now = DateTime.now().toUtc();
      final filtered = messages.where((msg) {
        final dateStr = msg['sent_at'] ?? msg['created_at'];
        if (dateStr == null) return true;
        final sentAt = DateTime.tryParse(dateStr);
        if (sentAt == null) return true;
        return now.difference(sentAt).inHours < 24;
      }).toList();

      await prefs.setString(cacheKey, jsonEncode(filtered));
    } catch (e) {
      print('Error saving chat cache: $e');
    }
  }

  void _startLocalCleanupTimer() {
    _localCleanupTimer?.cancel();
    _localCleanupTimer = Timer.periodic(const Duration(hours: 24), (_) {
      _pruneOldMessages();
    });
  }

  void _pruneOldMessages() {
    final now = DateTime.now().toUtc();
    final beforeCount = _messages.length;
    
    _messages.removeWhere((msg) {
      final dateStr = msg['sent_at'] ?? msg['created_at'];
      if (dateStr == null) return false;
      final sentAt = DateTime.tryParse(dateStr);
      if (sentAt == null) return false;
      return now.difference(sentAt).inHours >= 24;
    });
    
    if (_messages.length != beforeCount) {
      notifyListeners();
      if (_currentConversationId != null) {
        _saveMessagesToCache(_currentConversationId!, _messages);
      }
    }
    
    if (_currentConversationId != null) {
      _supabase.deleteOldMessages();
    }
  }

  void _setupTypingChannel(String conversationId) {
    final currentUserId = _supabase.client.auth.currentUser?.id;
    _isPartnerTyping = false;
    
    _typingChannel = _supabase.client.channel('typing:$conversationId');
    _typingChannel!.onBroadcast(
      event: 'typing',
      callback: (payload) {
        final senderId = payload['sender_id'];
        final isTyping = payload['is_typing'] == true;
        if (senderId != currentUserId) {
          _isPartnerTyping = isTyping;
          notifyListeners();
        }
      },
    );
    _typingChannel!.subscribe();
  }

  void _cleanTyping() {
    _typingTimer?.cancel();
    if (_isCurrentlyTyping) {
      _sendTypingEvent(false);
    }
    _typingChannel?.unsubscribe();
    _typingChannel = null;
    _isPartnerTyping = false;
  }

  void _sendTypingEvent(bool isTyping) {
    if (_currentConversationId == null || _typingChannel == null) return;
    _isCurrentlyTyping = isTyping;
    final currentUserId = _supabase.client.auth.currentUser?.id;
    _typingChannel!.sendBroadcastMessage(
      event: 'typing',
      payload: {
        'sender_id': currentUserId,
        'is_typing': isTyping,
      },
    );
  }

  void handleUserTyping() {
    if (!_isCurrentlyTyping) {
      _sendTypingEvent(true);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _sendTypingEvent(false);
    });
  }

  Future<List<String>> uploadImagesToImgBB(List<PlatformFile> files) async {
    final apiKey = dotenv.env['IMGBB_API_KEY'];
    final endpoint = dotenv.env['IMGBB_ENDPOINT'] ?? 'https://api.imgbb.com/1/upload';
    
    if (apiKey == null) {
      throw Exception('IMGBB API Key not configured');
    }

    List<String> uploadedUrls = [];
    
    for (var file in files) {
      if (file.path == null) continue;
      
      try {
        final imageBytes = await File(file.path!).readAsBytes();
        final base64Image = base64Encode(imageBytes);
        
        final response = await http.post(
          Uri.parse(endpoint),
          body: {
            'key': apiKey,
            'image': base64Image,
          },
        );
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          uploadedUrls.add(data['data']['url']);
        } else {
          print('ImgBB upload failed: ${response.body}');
        }
      } catch (e) {
        print('Error uploading to ImgBB: $e');
      }
    }
    
    return uploadedUrls;
  }

  String _generateUuid() {
    final rand = Random();
    String _hexPattern(int length) {
      String result = '';
      for (int i = 0; i < length; i++) {
        result += rand.nextInt(16).toRadixString(16);
      }
      return result;
    }
    return '${_hexPattern(8)}-${_hexPattern(4)}-4${_hexPattern(3)}-a${_hexPattern(3)}-${_hexPattern(12)}';
  }

  Future<void> sendMessage(String text, {List<PlatformFile>? imageFiles, String? replyToId}) async {
    if (_currentConversationId == null) return;
    
    _typingTimer?.cancel();
    if (_isCurrentlyTyping) {
      _sendTypingEvent(false);
    }
    
    final currentUserId = _supabase.client.auth.currentUser?.id;
    final pendingId = _generateUuid();
    final pendingMsg = {
      'id': pendingId,
      'sender_id': currentUserId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'encrypted_payload': jsonEncode({
        't': text,
        'i': imageFiles?.map((f) => f.path ?? '').toList(),
      }),
      'reply_to': replyToId,
      'is_pending': true,
    };
    
    _pendingMessages.add(pendingMsg);
    notifyListeners();

    try {
      List<String>? uploadedImages;
      if (imageFiles != null && imageFiles.isNotEmpty) {
        uploadedImages = await uploadImagesToImgBB(imageFiles);
      }

      await _supabase.sendMessage(
        conversationId: _currentConversationId!,
        text: text,
        images: uploadedImages,
        replyToId: replyToId,
        sharedSecret: _sharedSecret,
        messageId: pendingId,
      );
    } finally {
      _pendingMessages.removeWhere((m) => m['id'] == pendingId);
      notifyListeners();
    }
  }

  Future<void> editMessage(String messageId, String newText, {List<String>? images}) async {
    await _supabase.editMessage(messageId, newText, images: images);
  }

  Future<void> toggleReaction(String messageId, String emoji) async {
    try {
      final msg = _messages.firstWhere((m) => m['id'] == messageId);
      Map<String, dynamic> currentReactions = {};
      if (msg['encrypted_reactions'] != null) {
        currentReactions = jsonDecode(msg['encrypted_reactions']) as Map<String, dynamic>;
      }
      
      // Optimistic Update
      final userId = _supabase.client.auth.currentUser?.id;
      if (userId != null) {
        Map<String, dynamic> updatedReactions = Map<String, dynamic>.from(currentReactions);
        bool removedSameEmoji = false;
        
        for (final key in updatedReactions.keys.toList()) {
          final userList = List.from(updatedReactions[key] as List);
          if (userList.contains(userId)) {
            userList.remove(userId);
            if (key == emoji) {
              removedSameEmoji = true;
            }
            if (userList.isEmpty) {
              updatedReactions.remove(key);
            } else {
              updatedReactions[key] = userList;
            }
          }
        }

        if (!removedSameEmoji) {
          updatedReactions[emoji] = [...(updatedReactions[emoji] ?? []), userId];
        }
        
        msg['encrypted_reactions'] = updatedReactions.isNotEmpty ? jsonEncode(updatedReactions) : null;
        notifyListeners();
      }

      await _supabase.toggleReaction(messageId, emoji, currentReactions);
    } catch (e) {
      debugPrint('Error toggling reaction: $e');
    }
  }

  Future<void> deleteMessage(String messageId) async {
    // Optimistic UI Update: Hide instantly
    _messages.removeWhere((m) => m['id'] == messageId);
    notifyListeners();

    try {
      await _supabase.deleteMessage(messageId);
    } catch (e) {
      debugPrint('Error deleting message: $e');
      // If failed, reload to restore message
      if (_currentConversationId != null) {
        _startMessageStream(_currentConversationId!);
      }
    }
  }

  Future<void> clearChatHistory() async {
    if (_currentConversationId == null) return;
    
    // Optimistic UI Update: Clear instantly
    _messages.clear();
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('chat_cache_$_currentConversationId');
      final now = DateTime.now().toUtc();
      await prefs.setString('chat_cleared_at_$_currentConversationId', now.toIso8601String());
      _chatClearedAt = now;
      
      await _supabase.clearChatHistory(_currentConversationId!);
    } catch (e) {
      debugPrint('Error clearing chat history: $e');
      // If failed, reload to restore messages
      _startMessageStream(_currentConversationId!);
    }
  }

  @override
  void dispose() {
    _cleanTyping();
    _localCleanupTimer?.cancel();
    _msgSubscription?.cancel();
    _messagesChannel?.unsubscribe();
    super.dispose();
  }
}
