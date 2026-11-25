import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:shared_preferences/shared_preferences.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  io.Socket? _socket;
  bool _initialized = false;
  int _lastPlayerSyncTime = 0; // Sequence tracker
  int _lastPlayerProcessTime = 0; // Throttling timer

  static const String _serverUrl = 'https://elshla-production.up.railway.app';

  String? currentRoomCode;
  String? currentPlayerName;
  String? currentAvatar;
  final List<Map<String, dynamic>> chatMessages = [];
  bool isChatOpen = false;

  // Global player list for synchronization
  List<Map<String, dynamic>> currentPlayers = [];
  final _playersController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  Stream<List<Map<String, dynamic>>> get playersStream =>
      _playersController.stream;

  // Reaction handling
  final _reactionController = StreamController<String>.broadcast();
  Stream<String> get reactionStream => _reactionController.stream;

  // Chat broadcasting for previews
  final _chatController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get chatStream => _chatController.stream;

  factory SocketService() => _instance;
  SocketService._internal();

  /// Test seam: when set, [socket] returns this instance and [initSocket]
  /// never creates a real connection. Use a socket built with
  /// {'autoConnect': false, 'reconnection': false} so no timers are pending.
  @visibleForTesting
  static io.Socket? debugSocket;

  /// Test seam: when true, screens skip periodic socket timers that widget
  /// tests cannot cancel.
  @visibleForTesting
  static bool isTesting = false;

  io.Socket get socket {
    if (debugSocket != null) return debugSocket!;
    if (_socket == null) {
      _init();
    }
    return _socket!;
  }

  bool get isConnected => _socket?.connected ?? false;

  Future<void> setRoomContext(
    String code,
    String name, {
    String? avatar,
  }) async {
    // If room changed, clear stale data immediately
    if (currentRoomCode != code) {
      currentPlayers.clear();
      chatMessages.clear();
      _playersController.add([]);
    }

    currentRoomCode = code;
    currentPlayerName = name;
    currentAvatar = avatar;

    // Persist for smart reconnect
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_room_code', code);
    await prefs.setString('last_player_name', name);
    if (avatar != null) await prefs.setString('last_avatar', avatar);
    await prefs.setInt(
      'last_session_time',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> clearRoomContext() async {
    currentRoomCode = null;
    currentPlayerName = null;
    currentAvatar = null;
    chatMessages.clear();
    currentPlayers.clear();
    _playersController.add([]);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_room_code');
    await prefs.remove('last_player_name');
    await prefs.remove('last_avatar');
    await prefs.remove('last_session_time');
  }

  Map<String, dynamic> buildRoomPayload(Map<String, dynamic> base) {
    if (currentRoomCode == null) return base;
    
    final code = currentRoomCode!;
    final int? codeInt = int.tryParse(code.toString());
    
    return {
      ...base,
      'roomCode': code,
      'room_code': code,
      'room': code,
      'roomId': code,
      'room_id': code,
      'roomName': code,
      'room_name': code,
      if (codeInt != null) ...{
        'roomCodeInt': codeInt,
        'roomIdInt': codeInt,
        'room_id_int': codeInt,
        'id': codeInt,
      },
    };
  }

  void emitReaction(String emoji) {
    if (currentRoomCode != null) {
      _reactionController.add(emoji);

      final payload = buildRoomPayload({
        'emoji': emoji,
        'text': emoji,
        'type': 'emoji',
      });

      // Broadcast to all known reaction/emoji events for max compatibility
      socket.emit('send_reaction', payload);
      socket.emit('reaction', payload);
      socket.emit('emoji', payload);
      socket.emit('room_emoji', payload);
      socket.emit('room_reaction', payload);
      socket.emit('new_reaction', payload);
      socket.emit('reaction_received', payload);

      // BRUTAL V2 FIX: Also emit as a generic game move since we know that works for some servers
      socket.emit('game_move', {
        'roomCode': currentRoomCode,
        'moveData': {'type': 'emoji', ...payload},
      });
    }
  }

  void sendMessage(String text) {
    if (currentRoomCode == null) return;

    final String msgId =
        '${DateTime.now().millisecondsSinceEpoch}_${currentPlayerName}_local';
    final msgPayload = buildRoomPayload({
      'message': text,
      'text': text,
      'msg': text,
      'playerName': currentPlayerName,
      'name': currentPlayerName,
      'avatar': currentAvatar,
      'timestamp': DateTime.now().toIso8601String(),
      'msgId': msgId,
    });

    // 1. Local Echo for immediate feedback
    if (!chatMessages.any((m) => m['msgId'] == msgId)) {
      chatMessages.add(msgPayload);
      _chatController.add(msgPayload);
    }

    // 2. Broadcast to all possible event names for max compatibility
    socket.emit('chat_message', msgPayload);
    socket.emit('send_message', msgPayload);
    socket.emit('message', msgPayload);
    socket.emit('chat', msgPayload);

    // 3. Generic game move for specific server patterns
    socket.emit('game_move', {
      'roomCode': currentRoomCode,
      'moveData': {'type': 'chat', ...msgPayload},
    });
  }

  void initSocket() {
    if (debugSocket != null) return;
    if (_initialized && _socket != null) {
      if (!_socket!.connected) {
        _socket!.connect();
      }
      return;
    }
    _init();
  }

  void _init() {
    _initialized = true;

    // Try to load last session from SharedPreferences for auto-recovery
    _loadStoredSession();

    _socket = io.io(_serverUrl, <String, dynamic>{
      'transports': ['websocket'], // FORCED V2: Avoid polling upgrade issues
      'autoConnect': true,
      'forceNew': true,
      'multiplex': false,
      'reconnection': true,
      'reconnectionAttempts': 100, // Reasonable cap
      'reconnectionDelay': 1000,
      'timeout': 20000,
      'extraHeaders': {
        'connection': 'keep-alive',
        'x-client-platform': kIsWeb ? 'web' : 'mobile',
      },
    });

    _socket!.onConnect((_) {
      debugPrint('Socket Connected: ${_socket!.id}');
      _performJoin();
      _addSystemMessage('متصل بالسيرفر ✅');
    });

    // Player update events
    final List<String> playerEvents = [
      'players_updated',
      'update_players',
      'room_players',
      'players',
      'player_list',
      'player_left',
      'room_users',
      'list_players',
      'sync_players',
      'host_joined',
      'host_info',
    ];

    for (var event in playerEvents) {
      _socket!.on(event, (data) {
        // Implement a 200ms throttle for incoming player updates
        _processIncomingPlayers(data);
      });
    }

    final List<String> reactionEvents = [
      'receive_reaction',
      'reaction',
      'new_reaction',
      'emoji',
      'reaction_received',
      'room_reaction',
      'room_emoji',
      'receive_emoji',
    ];
    for (var event in reactionEvents) {
      _socket!.on(event, (data) {
        final emoji = data['emoji']?.toString() ?? data['text']?.toString();
        if (emoji != null) {
          _reactionController.add(emoji);
        }
      });
    }

    // --- REFINED CHAT LISTENERS ---
    final List<String> chatEvents = [
      'receive_chat_message', 'chat_message', 'message', 'new_chat_message',
      'receive_message', 'send_message', 'new_message', 'chat', 'msg',
      'game_move', // Added for generic server compatibility
    ];

    for (var event in chatEvents) {
      _socket!.on(event, (data) => _processIncomingChat(data));
    }

    _socket!.onAny((event, data) {
      if ([
        'connect',
        'disconnect',
        'reconnect',
        'ping',
        'pong',
      ].contains(event)) {
        return;
      }
      debugPrint('SOCKET_ANY: $event -> $data');
      // If we see an unknown event, let the user know for debugging
      if (!chatEvents.contains(event) && !playerEvents.contains(event)) {
        // _addSystemMessage('حدث مستلم: $event'); // Can be noisy, keep for deep debug
      }
    });

    // Removed redundant onConnect listener

    _socket!.onReconnect((_) {
      debugPrint('Socket Reconnected');
      revalidateSession();
      _addSystemMessage('تمت إعادة الاتصال 🔄');
    });

    _socket!.onDisconnect((data) {
      debugPrint('Socket Disconnected: $data');
      _addSystemMessage('فُقد الاتصال ⚠️');
    });

    _socket!.onConnectError((data) {
      debugPrint('Socket Connect Error: $data');
      _addSystemMessage('فشل الاتصال: $data ❌');
      // If stuck in connect error, try a hard reset after delay
      Timer(const Duration(seconds: 5), () {
        if (!_socket!.connected) {
          debugPrint('Stuck in error, forcing hard reconnect...');
          _socket!.connect();
        }
      });
    });
    _socket!.onError((data) {
      debugPrint('Socket Error: $data');
      _addSystemMessage('خطأ تقني: $data ⚠️');
    });

    // Keep-alive mechanism (Reduced to 12s to stay within Railway/Render timeouts)
    Timer.periodic(const Duration(seconds: 12), (timer) {
      if (_socket != null && _socket!.connected) {
        _socket!.emit('heartbeat', {
          'timestamp': DateTime.now().toIso8601String(),
          'roomId': currentRoomCode,
        });
      } else if (_socket != null && !_socket!.connected) {
        // Preventive reconnect try
        _socket!.connect();
      }
    });

    _socket!.connect();
  }

  Future<void> _loadStoredSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCode = prefs.getString('last_room_code');
      final lastName = prefs.getString('last_player_name');
      final lastAvatar = prefs.getString('last_avatar');
      final lastTime = prefs.getInt('last_session_time') ?? 0;

      // Only recover if session is less than 30 minutes old
      final now = DateTime.now().millisecondsSinceEpoch;
      if (lastCode != null && lastName != null && (now - lastTime < 1800000)) {
        currentRoomCode = lastCode;
        currentPlayerName = lastName;
        currentAvatar = lastAvatar;
        debugPrint('Recovered session for room: $currentRoomCode');

        // If socket is already connected but we weren't in the room, re-join
        if (_socket != null && _socket!.connected) {
          _performJoin();
        }
      }
    } catch (e) {
      debugPrint('Error loading stored session: $e');
    }
  }

  void _addSystemMessage(String text) {
    final msg = {
      'message': text,
      'playerName': 'النظام',
      'isSystem': true,
      'timestamp': DateTime.now().toIso8601String(),
    };
    chatMessages.add(msg);
    // Hard cap for production: Keep only the latest 100 messages to prevent OOM
    if (chatMessages.length > 100) {
      chatMessages.removeAt(0);
    }
    _chatController.add(msg);
  }

  void forceRoomSync() {
    revalidateSession();
  }

  void revalidateSession() {
    if (currentRoomCode != null && isConnected) {
      debugPrint('Re-validating session for room $currentRoomCode');
      _performJoin();
    }
  }

  void _performJoin() {
    if (currentRoomCode != null && currentPlayerName != null) {
      final dynamic code = currentRoomCode;
      final int? codeInt = int.tryParse(code.toString());
      final Map<String, dynamic> joinPayload = {
        'roomCode': code,
        'room_code': code,
        'room': code,
        'roomId': code,
        'room_id': code,
        'roomName': code,
        'room_name': code,
        if (codeInt != null) ...{
          'roomCodeInt': codeInt,
          'roomIdInt': codeInt,
          'room_id_int': codeInt,
          'id': codeInt,
        },
        'playerName': currentPlayerName,
        'name': currentPlayerName,
        'nickname': currentPlayerName,
        'username': currentPlayerName,
        'avatar': currentAvatar,
      };
      _socket!.emit('join_room', joinPayload);
      _socket!.emit('join', joinPayload);
      _socket!.emit('joinRoom', joinPayload);

      debugPrint('Socket Emitted Join for $code');
    }
  }

  void _processIncomingPlayers(dynamic rawData) {
    if (rawData == null) return;

    final int now = DateTime.now().millisecondsSinceEpoch;
    // Throttle: Max 1 update per 200ms to keep UI smooth under load
    if (now - _lastPlayerProcessTime < 200) return;
    _lastPlayerProcessTime = now;

    // Production stability: Ignore stale updates if they arrive out of order
    if (now < _lastPlayerSyncTime) return;
    _lastPlayerSyncTime = now;

    try {
      final Map<String, dynamic> normalizedData;
      if (rawData is List) {
        // If the server sends a raw list of players, wrap it in a map for consistent processing
        normalizedData = <String, dynamic>{'players': rawData};
      } else if (rawData is Map) {
        normalizedData = Map<String, dynamic>.from(rawData);
      } else {
        return;
      }

      final List<dynamic> rawPlayers =
          normalizedData['players'] ??
          normalizedData['playerList'] ??
          normalizedData['users'] ??
          [];

      currentPlayers = rawPlayers.map((p) {
        final Map<String, dynamic> player = Map<String, dynamic>.from(p);
        // Normalize isHost to boolean
        final rawHost =
            player['isHost'] ?? player['host'] ?? player['isAdmin'] ?? false;
        player['isHost'] =
            (rawHost == true ||
            rawHost == 1 ||
            rawHost == 'true' ||
            rawHost == '1');
        return player;
      }).toList();

      _playersController.add(currentPlayers);
    } catch (e) {
      debugPrint('Error parsing players: $e');
    }
  }

  void _processIncomingChat(dynamic data) {
    if (data == null) return;

    Map<String, dynamic> msg = {};
    try {
      if (data is Map) {
        // Handle game_move structure: { roomCode: ..., moveData: { ... } }
        if (data.containsKey('moveData') && data['moveData'] is Map) {
          final moveData = Map<String, dynamic>.from(data['moveData']);
          // Only process if it looks like a chat or has a message
          if (moveData['type'] == 'chat' ||
              moveData.containsKey('message') ||
              moveData.containsKey('text')) {
            msg = moveData;
          } else {
            return; // Ignore other game moves
          }
        } else {
          msg = Map<String, dynamic>.from(data);
        }
      } else if (data is String) {
        try {
          final decoded = jsonDecode(data);
          if (decoded is Map) {
            msg = Map<String, dynamic>.from(decoded);
          } else {
            msg = {'message': decoded.toString()};
          }
        } catch (_) {
          msg = {'message': data};
        }
      } else {
        msg = {'message': data.toString()};
      }
    } catch (e) {
      debugPrint('Error parsing chat message: $e');
      return;
    }

    if (msg.isEmpty) return;

    // Robust text extraction
    final rawText =
        msg['message']?.toString() ??
        msg['text']?.toString() ??
        msg['msg']?.toString() ??
        msg['content']?.toString() ??
        msg['body']?.toString() ??
        '';

    if (rawText.isEmpty && msg['type'] != 'chat') {
      return; // Skip empty non-chat messages
    }

    // Robust name extraction
    final rawName =
        msg['playerName']?.toString() ??
        msg['name']?.toString() ??
        msg['senderName']?.toString() ??
        msg['sender']?.toString() ??
        msg['nickname']?.toString() ??
        msg['username']?.toString() ??
        (msg['user'] is Map
            ? (msg['user']['name'] ?? msg['user']['nickname'])?.toString()
            : null) ??
        'لاعب';

    final String? msgId = (msg['msgId'] ?? msg['id'] ?? msg['messageId'])
        ?.toString();
    final String textLower = rawText.trim().toLowerCase();
    final String nameLower = rawName.trim().toLowerCase();

    // 1. Check by msgId (Primary)
    if (msgId != null) {
      bool exists = chatMessages.any(
        (m) => (m['msgId'] ?? m['id'])?.toString() == msgId,
      );
      if (exists) {
        debugPrint('DEDUPLICATION: Skipping message by ID: $msgId');
        return;
      }
    }

    // 2. Check by content + sender (Fallback for servers that strip msgId)
    final now = DateTime.now();
    bool contentExists = chatMessages.any((m) {
      if (m['isSystem'] == true) return false;
      final mText = (m['message'] ?? m['text'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final mName = (m['playerName'] ?? m['name'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      // Use logical cross-check: if it has a timestamp, use it, otherwise assume it's recent
      String? mTimestamp = m['timestamp'];
      DateTime mTime = (mTimestamp != null)
          ? DateTime.tryParse(mTimestamp) ?? now
          : now;

      return mText == textLower &&
          mName == nameLower &&
          now.difference(mTime).inSeconds.abs() < 2;
    });

    if (contentExists) {
      debugPrint('DEDUPLICATION: Skipping message by content/sender proximity');
      return;
    }

    debugPrint('CHAT_MESSAGE RECEIVED: $msg');

    // Robust avatar extraction
    final rawAvatar =
        msg['avatar']?.toString() ??
        (msg['user'] is Map ? msg['user']['avatar']?.toString() : null);

    msg['playerName'] = rawName;
    msg['name'] = rawName;
    msg['message'] = rawText;
    msg['text'] = rawText;
    if (rawAvatar != null) msg['avatar'] = rawAvatar;

    if (msg['timestamp'] == null) {
      msg['timestamp'] = DateTime.now().toIso8601String();
    }

    chatMessages.add(msg);
    _chatController.add(msg);
  }
}
