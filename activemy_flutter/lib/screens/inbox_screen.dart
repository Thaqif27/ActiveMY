import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';
import '../utils/theme.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final currentUserRef = auth.currentUser;
    if (currentUserRef == null) return const Scaffold();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text('Messages', style: GoogleFonts.poppins(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 20)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textDark),
          onPressed: () => context.pop(),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('private_chats')
            .where('participants', arrayContains: currentUserRef.uid)
            .orderBy('lastTimestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SelectableText(
                  'Error loading messages:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: Colors.red),
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No messages yet', style: GoogleFonts.poppins(color: AppColors.textLight)),
                ],
              ),
            );
          }

          final chats = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: chats.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey[100]),
            itemBuilder: (context, index) {
              final data = chats[index].data() as Map<String, dynamic>;
              final chatId = chats[index].id;
              
              final participants = List<String>.from(data['participants'] ?? []);
              final otherUserId = participants.firstWhere((id) => id != currentUserRef.uid, orElse: () => '');
              if (otherUserId.isEmpty) return const SizedBox.shrink();

              final lastMessage = data['lastMessage'] ?? '';
              final Timestamp? timestamp = data['lastTimestamp'];
              final timeString = timestamp != null ? timeago.format(timestamp.toDate(), locale: 'en_short') : '';

              final bool lastMessageIsRead = data['lastMessageIsRead'] ?? true;
              final String lastMessageSenderId = data['lastMessageSenderId'] ?? '';
              final bool isUnread = !lastMessageIsRead && lastMessageSenderId == otherUserId;

              return _ChatListTile(
                chatId: chatId,
                otherUserId: otherUserId,
                lastMessage: lastMessage,
                timeString: timeString,
                isUnread: isUnread,
              );
            },
          );
        },
      ),
    );
  }
}

class _ChatListTile extends StatelessWidget {
  final String chatId;
  final String otherUserId;
  final String lastMessage;
  final String timeString;
  final bool isUnread;

  const _ChatListTile({
    required this.chatId,
    required this.otherUserId,
    required this.lastMessage,
    required this.timeString,
    this.isUnread = false,
  });

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();

    return StreamBuilder<UserModel?>(
      stream: firestore.streamUser(otherUserId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 72);
        
        final otherUser = snapshot.data!;
        final name = otherUser.displayName.isNotEmpty ? otherUser.displayName : 'Athlete';
        final photoUrl = otherUser.photoUrl;
        final initials = name.isNotEmpty ? name[0].toUpperCase() : 'A';

        return InkWell(
          onTap: () => context.push('/chat/$chatId', extra: otherUserId),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage: photoUrl.isNotEmpty ? CachedNetworkImageProvider(photoUrl) : null,
                  child: photoUrl.isEmpty 
                    ? Text(initials, style: GoogleFonts.poppins(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.bold)) 
                    : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timeString,
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textLight),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lastMessage,
                              style: GoogleFonts.inter(
                                fontSize: 14, 
                                color: isUnread ? AppColors.textDark : AppColors.textMid,
                                fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isUnread) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }
}
