import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:mainproj/theme_notifier.dart';
import 'package:provider/provider.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  String _userName = 'Unknown';
  String _userEmail = 'No email';
  String _searchQuery = '';
  // The user's account creation time.
  Timestamp? _userCreationTimestamp;

  @override
  void initState() {
    super.initState();
    _getUserInfo();
    final user = _auth.currentUser;
    if (user != null && user.metadata.creationTime != null) {
      // Use the account creation time.
      _userCreationTimestamp = Timestamp.fromDate(user.metadata.creationTime!);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _getUserInfo() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      setState(() {
        _userName = userDoc.data()?['fullName'] ?? 'Unknown';
        _userEmail = user.email ?? 'No email';
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) return;

    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final messageRef = _firestore.collection('community_chat').doc();
      await messageRef.set({
        'messageId': messageRef.id,
        'userName': _userName,
        'userEmail': _userEmail,
        'userId': user.uid,
        'message': _messageController.text,
        'timestamp': FieldValue.serverTimestamp(),
        'edited': false,
        'likes': 0,
        'likedBy': [],
        'replies': [],
      });
      _messageController.clear();
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  Future<void> _editMessage(String messageId, String currentMessage) async {
    final TextEditingController editController =
        TextEditingController(text: currentMessage);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          title: const Text(
            'Edit Message',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: editController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Enter new message',
              hintStyle: TextStyle(color: Colors.grey),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await _firestore
                      .collection('community_chat')
                      .doc(messageId)
                      .update({
                    'message': editController.text,
                    'edited': true,
                  });
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to edit message: $e')),
                    );
                  }
                }
              },
              child: const Text(
                'Save',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteMessage(String messageId) async {
    final bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.black,
            title: const Text(
              'Delete Message',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Are you sure you want to delete this message?',
              style: TextStyle(color: Colors.white),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      try {
        await _firestore.collection('community_chat').doc(messageId).delete();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete message: $e')),
          );
        }
      }
    }
  }

  Future<void> _likeMessage(String messageId, List<dynamic> likedBy) async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (likedBy.contains(user.uid)) {
      // User already liked the message.
      return;
    }

    try {
      await _firestore.collection('community_chat').doc(messageId).update({
        'likes': FieldValue.increment(1),
        'likedBy': FieldValue.arrayUnion([user.uid]),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to like message: $e')),
        );
      }
    }
  }

  Future<void> _replyToMessage(String messageId, String reply) async {
    try {
      await _firestore.collection('community_chat').doc(messageId).update({
        'replies': FieldValue.arrayUnion([reply]),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reply to message: $e')),
        );
      }
    }
  }

  Widget _buildMessageBubble(Map<String, dynamic> messageData) {
    final bool isCurrentUser = messageData['userEmail'] == _userEmail;
    final timestamp = (messageData['timestamp'] as Timestamp?)?.toDate();
    final timeString = timestamp != null
        ? DateFormat('MMM d, h:mm a').format(timestamp)
        : 'Just now';

    return GestureDetector(
      onLongPress: isCurrentUser
          ? () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.black,
                builder: (context) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.edit, color: Colors.white),
                        title: const Text(
                          'Edit',
                          style: TextStyle(color: Colors.white),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          _editMessage(
                              messageData['messageId'], messageData['message']);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.delete, color: Colors.red),
                        title: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          _deleteMessage(messageData['messageId']);
                        },
                      ),
                    ],
                  );
                },
              );
            }
          : null,
      child: Align(
        alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
          padding: const EdgeInsets.all(12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: isCurrentUser ? Colors.blue[800] : Colors.grey[800],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: isCurrentUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.grey[300],
                    child: Text(
                      messageData['userName'][0],
                      style: const TextStyle(color: Colors.black),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    messageData['userName'] ?? 'Unknown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (messageData['edited'] == true) ...[
                    const SizedBox(width: 4),
                    Text(
                      '(edited)',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                messageData['message'] ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.thumb_up,
                        size: 16, color: Colors.white),
                    onPressed: () => _likeMessage(
                        messageData['messageId'], messageData['likedBy'] ?? []),
                  ),
                  Text(
                    '${messageData['likes'] ?? 0}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon:
                        const Icon(Icons.reply, size: 16, color: Colors.white),
                    onPressed: () {
                      final TextEditingController replyController =
                          TextEditingController();
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            backgroundColor: Colors.black,
                            title: const Text(
                              'Reply to Message',
                              style: TextStyle(color: Colors.white),
                            ),
                            content: TextField(
                              controller: replyController,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: 'Type your reply...',
                                hintStyle: TextStyle(color: Colors.grey),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.grey),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white),
                                ),
                              ),
                              autofocus: true,
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  _replyToMessage(messageData['messageId'],
                                      replyController.text);
                                  Navigator.of(context).pop();
                                },
                                child: const Text(
                                  'Send',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
              Text(
                timeString,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeNotifier.backgroundColor,
      appBar: AppBar(
        title:
            const Text('Community Chat', style: TextStyle(color: Colors.white)),
        backgroundColor: themeNotifier.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            onPressed: () async {
              await _auth.signOut();
              if (mounted) {
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search messages...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('community_chat')
                  // Use a fallback timestamp so that if _userCreationTimestamp is null,
                  // all messages are shown.
                  .where('timestamp',
                      isGreaterThanOrEqualTo: _userCreationTimestamp ??
                          Timestamp.fromMillisecondsSinceEpoch(0))
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }

                final messages = snapshot.data!.docs.where((doc) {
                  final message = doc['message'] as String;
                  return message
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase());
                }).toList();

                return ListView.builder(
                  controller: _scrollController,
                  reverse: false,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    DocumentSnapshot document = messages[index];
                    return _buildMessageBubble(
                        document.data() as Map<String, dynamic>);
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Colors.grey),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                    autofocus: true,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
