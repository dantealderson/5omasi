import 'dart:async';
import 'package:flutter/material.dart';
import 'package:khomasi/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:khomasi/l10n/app_localizations.dart';
import 'package:khomasi/pages/player_profile_page.dart';
import 'package:khomasi/pages/root_page.dart';
import 'package:khomasi/services/push_notification_sender.dart';

class MatchChatPage extends StatefulWidget {
  final String matchId;
  final String userId;
  final String userName;
  final String? userPhotoUrl;

  const MatchChatPage({
    super.key,
    required this.matchId,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
  });

  @override
  State<MatchChatPage> createState() => _MatchChatPageState();
}

class _MatchChatPageState extends State<MatchChatPage> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  // Read receipts: userId -> { lastReadMessageId, photoUrl, name }
  Map<String, Map<String, dynamic>> _readReceipts = {};
  StreamSubscription? _receiptsSubscription;

  DocumentReference get _matchRef => FirebaseFirestore.instance
      .collection('matches')
      .doc(widget.matchId);

  CollectionReference get _chatRef => _matchRef.collection('chat');

  CollectionReference get _receiptsRef => _matchRef.collection('chatReadReceipts');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenToReadReceipts();
  }

  void _listenToReadReceipts() {
    _receiptsSubscription = _receiptsRef.snapshots().listen((snapshot) {
      if (!mounted) return;
      final receipts = <String, Map<String, dynamic>>{};
      for (final doc in snapshot.docs) {
        if (doc.id == widget.userId) continue; // Skip own receipt
        receipts[doc.id] = doc.data() as Map<String, dynamic>;
      }
      setState(() => _readReceipts = receipts);
    });
  }

  void _updateReadReceipt(String lastMessageId) {
    _receiptsRef.doc(widget.userId).set({
      'lastReadMessageId': lastMessageId,
      'photoUrl': widget.userPhotoUrl ?? '',
      'name': widget.userName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      await _chatRef.add({
        'senderId': widget.userId,
        'senderName': widget.userName,
        'senderPhotoUrl': widget.userPhotoUrl,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
      });
      _forceScrollToBottom();

      // Send push notification to other players
      PushNotificationSender.notifyMatchPlayers(
        matchId: widget.matchId,
        excludeUserId: widget.userId,
        title: widget.userName,
        body: text.length > 100 ? '${text.substring(0, 100)}...' : text,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'error'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final currentScroll = _scrollController.position.pixels;
        if (maxScroll - currentScroll < 150) {
          _scrollController.animateTo(
            maxScroll,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  void _forceScrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
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
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _receiptsSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Build a map: messageId -> list of users whose lastReadMessageId == that messageId
  Map<String, List<Map<String, dynamic>>> _buildReadReceiptsByMessage() {
    final result = <String, List<Map<String, dynamic>>>{};
    for (final entry in _readReceipts.entries) {
      final msgId = entry.value['lastReadMessageId'] as String?;
      if (msgId == null) continue;
      result.putIfAbsent(msgId, () => []);
      result[msgId]!.add({
        'userId': entry.key,
        'photoUrl': entry.value['photoUrl'] ?? '',
        'name': entry.value['name'] ?? '',
      });
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'matchChat')),
        backgroundColor: isDark ? AppColors.dSurface : AppColors.brand,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatRef.orderBy('timestamp').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text(tr(context, 'error')));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          tr(context, 'noChatMessages'),
                          style: TextStyle(color: Colors.grey[500], fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                // Mark last message as read
                final lastMsgId = messages.last.id;
                _updateReadReceipt(lastMsgId);

                final receiptsByMsg = _buildReadReceiptsByMessage();

                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final doc = messages[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == widget.userId;
                    final timestamp = data['timestamp'] as Timestamp?;
                    final time = timestamp != null
                        ? '${timestamp.toDate().hour.toString().padLeft(2, '0')}:${timestamp.toDate().minute.toString().padLeft(2, '0')}'
                        : '';

                    final showName = !isMe &&
                        (index == 0 ||
                            (messages[index - 1].data() as Map<String, dynamic>)['senderId'] != data['senderId']);

                    final readers = receiptsByMsg[doc.id] ?? [];

                    return _buildMessageBubble(
                      text: data['text'] ?? '',
                      senderId: data['senderId'] ?? '',
                      senderName: data['senderName'] ?? '',
                      senderPhotoUrl: data['senderPhotoUrl'] as String?,
                      time: time,
                      isMe: isMe,
                      showName: showName,
                      isDark: isDark,
                      readers: readers,
                    );
                  },
                );
              },
            ),
          ),
          _buildInputBar(isDark),
        ],
      ),
    );
  }

  void _navigateToProfile(String senderId, String senderName) {
    HapticFeedback.lightImpact();
    if (senderId == widget.userId) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const RootPage(initialIndex: 3)));
    } else {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => PlayerProfilePage(oderId: senderId, playerName: senderName),
      ));
    }
  }

  Widget _buildReadReceipts(List<Map<String, dynamic>> readers, bool isMe) {
    if (readers.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(
        top: 4,
        left: isMe ? 0 : 40,
        right: isMe ? 0 : 0,
      ),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: readers.take(5).map((reader) {
          final photoUrl = reader['photoUrl'] as String? ?? '';
          final name = reader['name'] as String? ?? '';
          final userId = reader['userId'] as String? ?? '';

          return Padding(
            padding: const EdgeInsets.only(left: 2),
            child: GestureDetector(
              onTap: () => _navigateToProfile(userId, name),
              child: CircleAvatar(
                radius: 8,
                backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                backgroundColor: AppColors.brand,
                child: photoUrl.isEmpty
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMessageBubble({
    required String text,
    required String senderId,
    required String senderName,
    required String? senderPhotoUrl,
    required String time,
    required bool isMe,
    required bool showName,
    required bool isDark,
    required List<Map<String, dynamic>> readers,
  }) {
    final avatar = GestureDetector(
      onTap: () => _navigateToProfile(senderId, senderName),
      child: CircleAvatar(
        radius: 16,
        backgroundImage: senderPhotoUrl != null && senderPhotoUrl.isNotEmpty
            ? NetworkImage(senderPhotoUrl)
            : null,
        backgroundColor: AppColors.brand,
        child: senderPhotoUrl == null || senderPhotoUrl.isEmpty
            ? Text(senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))
            : null,
      ),
    );

    return Padding(
      padding: EdgeInsets.only(
        top: showName ? 12 : 2,
        bottom: 2,
        left: isMe ? 48 : 0,
        right: isMe ? 0 : 48,
      ),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMe && showName) avatar,
              if (!isMe && !showName) const SizedBox(width: 32),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (showName)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 4),
                        child: Text(
                          senderName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.brand,
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isMe
                            ? AppColors.brand
                            : (isDark ? AppColors.dRaised : Colors.grey[200]),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isMe ? 16 : 4),
                          bottomRight: Radius.circular(isMe ? 4 : 16),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            text,
                            style: TextStyle(
                              color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            time,
                            style: TextStyle(
                              fontSize: 10,
                              color: isMe ? Colors.white60 : Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Read receipts - small pfps below the message
          _buildReadReceipts(readers, isMe),
        ],
      ),
    );
  }

  Widget _buildInputBar(bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.dSurface : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              maxLines: 4,
              minLines: 1,
              decoration: InputDecoration(
                hintText: tr(context, 'typeMessage'),
                hintStyle: TextStyle(color: Colors.grey[500]),
                filled: true,
                fillColor: isDark ? AppColors.dRaised : Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: AppColors.brand,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: _isSending ? null : _sendMessage,
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  Icons.send,
                  color: _isSending ? Colors.white54 : Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
