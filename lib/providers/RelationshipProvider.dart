import 'dart:async';
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class RelationshipProvider extends ChangeNotifier {
  final _supabase = SupabaseService();
  Map<String, dynamic>? _conversation;
  Map<String, dynamic>? _partner;
  bool _loading = false;
  String? _activeCode;
  DateTime? _codeExpiresAt;
  Map<String, dynamic>? _pendingRequest;
  
  StreamSubscription? _convSubscription;
  StreamSubscription? _partnerSubscription;
  StreamSubscription? _pairingSubscription;
  StreamSubscription? _unreadMessagesSubscription;

  Map<String, dynamic>? get conversation => _conversation;
  Map<String, dynamic>? get partner => _partner;
  bool get loading => _loading;
  String? get activeCode => _activeCode;
  DateTime? get codeExpiresAt => _codeExpiresAt;
  Map<String, dynamic>? get pendingRequest => _pendingRequest;
  bool get isPaired => _conversation != null && _conversation!['is_verified'] == true;

  final Completer<void> _initCompleter = Completer<void>();
  bool _isInitialized = false;

  RelationshipProvider() {
    _startStreams();
  }

  Future<void> waitForInitialization() async {
    try {
      final conv = await _supabase.getActiveConversation();
      if (conv != null) {
        _conversation = conv;
        _partner = await _supabase.getPartner();
      }
    } catch (_) {}
    
    _isInitialized = true;
    if (!_initCompleter.isCompleted) {
      _initCompleter.complete();
    }
  }

  void _startStreams() {
    _convSubscription = _supabase.streamActiveConversation().listen((conv) async {
      _conversation = conv;
      if (conv != null) {
        // Stream partner details
        _activeCode = null;
        _codeExpiresAt = null;
        _pendingRequest = null;
        _pairingSubscription?.cancel();
        
        final p = await _supabase.getPartner();
        if (p != null) {
          _partnerSubscription?.cancel();
          
          _partnerSubscription = _supabase.streamPartnerProfile(p['id']).listen((pProfile) {
            _partner = pProfile;
            if (!_isInitialized) {
              _isInitialized = true;
              _initCompleter.complete();
            }
            notifyListeners();
          });

          // Global unread messages listener for delivered ticks
          _unreadMessagesSubscription?.cancel();
          _unreadMessagesSubscription = _supabase.client.from('messages')
            .stream(primaryKey: ['id'])
            .eq('conversation_id', conv['id'])
            .listen((msgs) {
              final userId = _supabase.client.auth.currentUser?.id;
              if (userId == null) return;
              final unread = msgs.where((m) => m['sender_id'] != userId && m['status'] == 'sent').toList();
              if (unread.isNotEmpty) {
                _supabase.client.from('messages').update({'status': 'delivered'})
                  .eq('conversation_id', conv['id'])
                  .eq('status', 'sent')
                  .neq('sender_id', userId)
                  .then((_) {});
              }
            });
        } else {
          if (!_isInitialized) {
            _isInitialized = true;
            _initCompleter.complete();
          }
          notifyListeners();
        }
      } else {
        _partner = null;
        _partnerSubscription?.cancel();
        _unreadMessagesSubscription?.cancel();
        if (!_isInitialized) {
          _isInitialized = true;
          _initCompleter.complete();
        }
        notifyListeners();
      }
    });
  }

  void _listenToPairingRequest(String code) {
    _pairingSubscription?.cancel();
    _pairingSubscription = _supabase.streamPairingRequest(code).listen((requests) {
      if (requests.isEmpty) {
        _pendingRequest = null;
      } else {
        final req = requests.first;
        if (req['status'] == 'pending_acceptance') {
          _pendingRequest = req;
        } else {
          _pendingRequest = null;
        }
      }
      notifyListeners();
    });
  }

  Future<void> generateCode() async {
    _loading = true;
    notifyListeners();
    try {
      _activeCode = await _supabase.generatePairingCode();
      _codeExpiresAt = DateTime.now().add(const Duration(minutes: 3));
      _listenToPairingRequest(_activeCode!);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void clearCode() {
    _activeCode = null;
    _codeExpiresAt = null;
    notifyListeners();
  }

  Future<Map<String, dynamic>?> fetchProfileByCode(String code) async {
    _loading = true;
    notifyListeners();
    try {
      return await _supabase.getProfileByPairingCode(code);
    } catch (e) {
      _loading = false;
      notifyListeners();
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> connectWithCode(String code) async {
    _loading = true;
    notifyListeners();
    try {
      await _supabase.verifyPairingCode(code);
    } catch (e) {
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> acceptRequest() async {
    if (_pendingRequest == null) return;
    _loading = true;
    notifyListeners();
    try {
      await _supabase.acceptPairingRequest(
        _pendingRequest!['id'], 
        _pendingRequest!['sender_id'], 
        _pendingRequest!['receiver_id']
      );
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> rejectRequest() async {
    if (_pendingRequest == null) return;
    _loading = true;
    notifyListeners();
    try {
      await _supabase.rejectPairingRequest(_pendingRequest!['id']);
      _pendingRequest = null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> requestDisconnect() async {
    _loading = true;
    notifyListeners();
    try {
      await _supabase.requestDisconnect();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> cancelDisconnect() async {
    _loading = true;
    notifyListeners();
    try {
      await _supabase.cancelDisconnect();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> confirmDisconnect() async {
    _loading = true;
    notifyListeners();
    try {
      await _supabase.confirmDisconnect();
      _conversation = null;
      _partner = null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _convSubscription?.cancel();
    _partnerSubscription?.cancel();
    _pairingSubscription?.cancel();
    _unreadMessagesSubscription?.cancel();
    super.dispose();
  }
}
