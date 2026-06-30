import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../models/event_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../utils/theme.dart';

class EventChatScreen extends StatefulWidget {
  final EventModel event;

  const EventChatScreen({super.key, required this.event});

  @override
  State<EventChatScreen> createState() => _EventChatScreenState();
}

class _EventChatScreenState extends State<EventChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  void _sendMessage(UserModel currentUser) async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);

    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.event.id)
          .collection('chats')
          .add({
        'senderId': currentUser.uid,
        'senderName': currentUser.displayName,
        'senderPhotoUrl': currentUser.photoUrl,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
      });
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

  void _onAvatarTap(BuildContext context, String senderId, String currentUserId) {
    if (senderId == currentUserId) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Connect with this user?', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.chat_bubble, color: Colors.white),
              label: Text('Send Private Message', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(context);
                final chatId = currentUserId.compareTo(senderId) < 0 
                  ? '${currentUserId}_$senderId' 
                  : '${senderId}_$currentUserId';
                
                context.push('/chat/$chatId', extra: senderId);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final firestore = context.read<FirestoreService>();
    final currentUserRef = auth.currentUser;
    if (currentUserRef == null) return const Scaffold();

    return StreamBuilder<UserModel?>(
      stream: firestore.streamUser(currentUserRef.uid),
      builder: (context, userSnap) {
        if (!userSnap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final currentUser = userSnap.data!;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.white,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Event Community', style: GoogleFonts.poppins(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 18)),
                Text(widget.event.title, style: GoogleFonts.inter(color: AppColors.textMid, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textDark),
              onPressed: () => context.pop(),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('events')
                      .doc(widget.event.id)
                      .collection('chats')
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
                            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text('Be the first to say hi!', style: GoogleFonts.poppins(color: AppColors.textLight)),
                          ],
                        ),
                      );
                    }

                    final docs = snapshot.data!.docs;

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final bool isMe = data['senderId'] == currentUser.uid;
                        
                        final String senderName = data['senderName'] ?? 'Athlete';
                        final String senderPhotoUrl = data['senderPhotoUrl'] ?? '';
                        final String initials = senderName.isNotEmpty ? senderName[0].toUpperCase() : 'A';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (!isMe)
                                GestureDetector(
                                  onTap: () => _onAvatarTap(context, data['senderId'], currentUser.uid),
                                  child: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: AppColors.primary,
                                    backgroundImage: senderPhotoUrl.isNotEmpty ? CachedNetworkImageProvider(senderPhotoUrl) : null,
                                    child: senderPhotoUrl.isEmpty ? Text(initials, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)) : null,
                                  ),
                                ),
                              if (!isMe) const SizedBox(width: 8),
                              
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
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (!isMe)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 4),
                                          child: Text(senderName, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                        ),
                                      Text(
                                        data['text'] ?? '',
                                        style: GoogleFonts.inter(
                                          color: isMe ? Colors.white : AppColors.textDark,
                                          fontSize: 14,
                                        ),
                                      ),
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
}
