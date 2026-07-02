import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';
import '../utils/theme.dart';

class PrivateChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;

  const PrivateChatScreen({super.key, required this.chatId, required this.otherUserId});

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  void _sendMessage(UserModel currentUser) async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);

    try {
      await FirebaseFirestore.instance
          .collection('private_chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
        'senderId': currentUser.uid,
        'senderName': currentUser.displayName,
        'senderPhotoUrl': currentUser.photoUrl,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
      
      // Update latest message in chat metadata
      await FirebaseFirestore.instance
          .collection('private_chats')
          .doc(widget.chatId)
          .set({
        'lastMessage': text,
        'lastTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSenderId': currentUser.uid,
        'lastMessageIsRead': false,
        'participants': [currentUser.uid, widget.otherUserId],
      }, SetOptions(merge: true));

      _controller.clear();
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final firestore = context.read<FirestoreService>();
    final currentUserRef = auth.currentUser;
    if (currentUserRef == null) return const Scaffold();

    return StreamBuilder<UserModel?>(
      stream: firestore.streamUser(widget.otherUserId),
      builder: (context, otherUserSnap) {
        final otherUser = otherUserSnap.data;
        final String titleName = otherUser?.displayName ?? 'Athlete';
        final String photoUrl = otherUser?.photoUrl ?? '';
        final String initials = titleName.isNotEmpty ? titleName[0].toUpperCase() : 'A';

        return StreamBuilder<UserModel?>(
          stream: firestore.streamUser(currentUserRef.uid),
          builder: (context, userSnap) {
            if (!userSnap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
            final currentUser = userSnap.data!;

            return Scaffold(
              backgroundColor: AppColors.background,
              appBar: AppBar(
                backgroundColor: Colors.white,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textDark),
                  onPressed: () => context.pop(),
                ),
                title: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primary,
                      backgroundImage: photoUrl.isNotEmpty ? CachedNetworkImageProvider(photoUrl) : null,
                      child: photoUrl.isEmpty ? Text(initials, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(titleName, style: GoogleFonts.poppins(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('Private Chat', style: GoogleFonts.inter(color: AppColors.textMid, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              body: Column(
                children: [
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('private_chats')
                          .doc(widget.chatId)
                          .collection('messages')
                          .orderBy('timestamp', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.forum_outlined, size: 64, color: Colors.grey[300]),
                                const SizedBox(height: 16),
                                Text('Say hi to $titleName!', style: GoogleFonts.poppins(color: AppColors.textLight)),
                              ],
                            ),
                          );
                        }

                        final docs = snapshot.data!.docs;

                        // Mark unread incoming messages as read
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          bool updatedAny = false;
                          for (var doc in docs) {
                            final data = doc.data() as Map<String, dynamic>;
                            if (data['senderId'] != currentUser.uid && (data['isRead'] == null || data['isRead'] == false)) {
                              doc.reference.update({'isRead': true});
                              updatedAny = true;
                            }
                          }
                          if (updatedAny) {
                            FirebaseFirestore.instance
                                .collection('private_chats')
                                .doc(widget.chatId)
                                .set({'lastMessageIsRead': true}, SetOptions(merge: true));
                          }
                        });

                        return ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          padding: const EdgeInsets.all(16),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final data = docs[index].data() as Map<String, dynamic>;
                            final bool isMe = data['senderId'] == currentUser.uid;
                            final bool isRead = data['isRead'] ?? false;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (!isMe) ...[
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                      backgroundImage: photoUrl.isNotEmpty ? CachedNetworkImageProvider(photoUrl) : null,
                                      child: photoUrl.isEmpty ? Text(initials, style: GoogleFonts.poppins(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)) : null,
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: isMe ? AppColors.primary : Colors.white,
                                        borderRadius: BorderRadius.circular(20).copyWith(
                                          bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
                                          bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.05),
                                            blurRadius: 5,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              data['text'] ?? '',
                                              style: GoogleFonts.inter(
                                                color: isMe ? Colors.white : AppColors.textDark,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          if (isMe) ...[
                                            const SizedBox(width: 8),
                                            Icon(
                                              Icons.done_all,
                                              size: 14,
                                              color: isRead ? Colors.blue[300] : Colors.white70,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  
                  // Chat Input
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
                    ),
                    child: SafeArea(
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) {
                                if (!_isSending) _sendMessage(currentUser);
                              },
                              decoration: InputDecoration(
                                hintText: 'Type a message...',
                                hintStyle: GoogleFonts.inter(color: AppColors.textLight),
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: AppColors.primary,
                            child: IconButton(
                              icon: _isSending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                              onPressed: _isSending ? null : () => _sendMessage(currentUser),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        );
      }
    );
  }
}
