import 'package:flutter/material.dart';
import '../services/socket_service.dart';
import 'package:intl/intl.dart' as intl;
import 'dart:convert';
import 'dart:async';
import '../theme/flat_theme.dart';

class ChatWidget extends StatefulWidget {
  final String roomCode;
  final String playerName;
  final List<Map<String, dynamic>> initialMessages;

  const ChatWidget({
    super.key,
    required this.roomCode,
    required this.playerName,
    required this.initialMessages,
  });

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _chatSub;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    SocketService().isChatOpen = true;
    _chatSub = SocketService().chatStream.listen((msg) {
      if (mounted) {
        setState(() {}); // SocketService already updated the global list
        _scrollToBottom();
      }
    });
    _scrollToBottom();

    // Periodically refresh UI to catch connection status changes
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (t) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    SocketService().isChatOpen = false;
    _chatSub?.cancel();
    _statusTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Use centralized service for robust broadcasting and local echo
    SocketService().sendMessage(text);

    _scrollToBottom();
    _messageController.clear();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: FlatColors.bg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(35),
          topRight: Radius.circular(35),
        ),
      ),
      child: Column(
        children: [
          // Elegant Handle/Header
          Container(
            margin: const EdgeInsets.only(top: 15, bottom: 5),
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: FlatColors.border,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: FlatColors.tilePastels[1],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: FlatColors.ink,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Text(
                      'غرفة الدردشة',
                      style: flatCairo(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: FlatColors.ink,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: SocketService().isConnected
                                ? FlatColors.mintDark
                                : FlatColors.playerRed,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                          SocketService().isConnected
                              ? 'متصل'
                              : 'فارغ من الاتصال',
                          style: flatCairo(
                            fontSize: 10,
                            color: FlatColors.ink.withValues(alpha: 0.6),
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    ],
                  ),
                ),
                if (!SocketService().isConnected)
                  IconButton(
                    icon: const Icon(
                      Icons.sync_problem_rounded,
                      color: Color(0xFF9C6E00),
                    ),
                    onPressed: () {
                      SocketService().initSocket();
                      SocketService().forceRoomSync();
                    },
                    tooltip: 'إعادة الاتصال',
                  ),
                IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: FlatColors.ink.withValues(alpha: 0.4)),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: FlatColors.border, height: 1, thickness: 2),

          // Messages List with Premium Styling
          Expanded(
            child: SocketService().chatMessages.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      // Fix Overflow
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(30),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: FlatColors.border, width: 2),
                            ),
                            child: Icon(
                              Icons.chat_bubble_rounded,
                              size: 70,
                              color: FlatColors.tilePastels[1]
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 25),
                          Text(
                            'المكان فاضي يا وحش!\nابدأ المحادثة ووريهم مين القائد 🚀',
                            textAlign: TextAlign.center,
                            style: flatCairo(
                              color: FlatColors.ink.withValues(alpha: 0.45),
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 25,
                    ),
                    itemCount: SocketService().chatMessages.length,
                    itemBuilder: (context, index) {
                      final msg = SocketService().chatMessages[index];
                      if (msg['isSystem'] == true) {
                        return _buildSystemMessage(msg);
                      }

                      // Robust identity check
                      final sender =
                          (msg['playerName'] ??
                                  msg['name'] ??
                                  msg['sender'] ??
                                  '')
                              .toString()
                              .trim()
                              .toLowerCase();
                      final isMe =
                          sender == widget.playerName.trim().toLowerCase();
                      return _buildMessageBubble(msg, isMe);
                    },
                  ),
          ),

          // High-End Input Area
          Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 15,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: FlatColors.border, width: 2),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: FlatColors.bg,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: FlatColors.border, width: 2),
                    ),
                    child: TextField(
                      controller: _messageController,
                      style: flatCairo(color: FlatColors.ink, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'اكتب حاجة عظمة...',
                        hintStyle: flatCairo(
                          color: FlatColors.ink.withValues(alpha: 0.35),
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 25,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                _buildSendButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    return GestureDetector(
      onTap: _sendMessage,
      child: Container(
        height: 52,
        width: 52,
        decoration: const BoxDecoration(
          color: FlatColors.playerBlue,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.send_rounded, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe) {
    String timeStr = '';
    try {
      if (msg['timestamp'] != null) {
        timeStr = intl.DateFormat(
          'hh:mm',
        ).format(DateTime.parse(msg['timestamp']));
      }
    } catch (_) {
      timeStr = '';
    }

    // Improved sender info extraction
    var senderName =
        (msg['playerName']?.toString() ??
                msg['name']?.toString() ??
                msg['sender']?.toString() ??
                (msg['user'] is Map ? msg['user']['name']?.toString() : null) ??
                'لاعب')
            .trim();
    if (senderName.isEmpty) senderName = 'لاعب';

    final avatarData =
        msg['avatar']?.toString() ??
        (msg['user'] is Map ? msg['user']['avatar']?.toString() : null);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) _buildAvatar(senderName, avatarBase64: avatarData),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    left: 10,
                    right: 10,
                    bottom: 5,
                  ),
                  child: Text(
                    isMe ? 'أنت' : senderName,
                    style: flatCairo(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: isMe ? FlatColors.playerBlue : const Color(0xFF9C6E00),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? FlatColors.playerBlue : Colors.white,
                    border: isMe
                        ? null
                        : Border.all(color: FlatColors.border, width: 2),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(22),
                      topRight: const Radius.circular(22),
                      bottomLeft: Radius.circular(isMe ? 22 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 22),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg['message'] ?? '',
                        style: flatCairo(
                          color:
                              isMe ? Colors.white : FlatColors.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        timeStr,
                        style: flatCairo(
                          color: isMe
                              ? Colors.white70
                              : FlatColors.ink.withValues(alpha: 0.45),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (isMe)
            _buildAvatar(senderName, isSelf: true, avatarBase64: avatarData),
        ],
      ),
    );
  }

  Widget _buildSystemMessage(Map<String, dynamic> msg) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: FlatDecor.tag(),
        child: Text(
          msg['message'] ?? '',
          style: flatCairo(
            fontSize: 11,
            color: FlatColors.ink.withValues(alpha: 0.6),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String? _getAvatarForPlayer(String name) {
    if (SocketService().currentPlayers.isEmpty) return null;
    final normalized = name.trim().toLowerCase();

    try {
      final player = SocketService().currentPlayers.firstWhere(
        (p) =>
            (p['playerName'] ?? p['name'] ?? '')
                .toString()
                .trim()
                .toLowerCase() ==
            normalized,
      );
      return player['avatar']?.toString();
    } catch (_) {
      return null;
    }
  }

  Widget _buildAvatar(
    String name, {
    bool isSelf = false,
    String? avatarBase64,
  }) {
    // If we have base64 data, render it
    var data = avatarBase64;

    // Fallback seek in global player list if missing
    if ((data == null || data.isEmpty) && !isSelf) {
      data = _getAvatarForPlayer(name);
    }

    // Special handling for self if missing
    if ((data == null || data.isEmpty) && isSelf) {
      data = SocketService().currentAvatar;
    }

    if (data != null && data.isNotEmpty) {
      try {
        // Clean prefix if exists (e.g. data:image/png;base64,...)
        if (data.contains(',')) {
          data = data.split(',').last.trim();
        }

        return Container(
          width: 35,
          height: 35,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelf
                  ? FlatColors.playerBlue.withValues(alpha: 0.4)
                  : FlatColors.border,
              width: 1.5,
            ),
          ),
          child: ClipOval(
            child: Image.memory(
              base64Decode(data),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildInitialsAvatar(name, isSelf);
              },
            ),
          ),
        );
      } catch (e) {
        debugPrint('Error decoding chat avatar: $e');
        return _buildInitialsAvatar(name, isSelf);
      }
    }

    return _buildInitialsAvatar(name, isSelf);
  }

  Widget _buildInitialsAvatar(String name, bool isSelf) {
    final firstChar = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: 35,
      height: 35,
      decoration: BoxDecoration(
        color: isSelf ? FlatColors.playerBlue : FlatColors.ink,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Center(
        child: Text(
          firstChar,
          style: flatCairo(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
