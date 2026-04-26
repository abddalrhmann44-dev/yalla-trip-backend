// ═══════════════════════════════════════════════════════════════
//  TALAA — Chat Inbox Page
//  Lists the current user's conversations (pulled from /chats).
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart' show appSettings, userProvider;
import '../utils/auth_guard.dart';
import '../models/chat_model.dart';
import '../services/chat_service.dart';
import '../utils/api_client.dart';
import '../utils/error_handler.dart';
import '../widgets/constants.dart';
import 'chat_page.dart';

class ChatInboxPage extends StatefulWidget {
  final bool embedded;
  const ChatInboxPage({super.key, this.embedded = false});

  @override
  State<ChatInboxPage> createState() => _ChatInboxPageState();
}

class _ChatInboxPageState extends State<ChatInboxPage> {
  List<Conversation> _convs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (!widget.embedded) {
      AuthGuard.requireOrPop(context, feature: 'تتواصل مع الملاك');
    }
    appSettings.addListener(_onLangChange);
    _load();
  }

  @override
  void dispose() {
    appSettings.removeListener(_onLangChange);
    super.dispose();
  }

  void _onLangChange() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ChatService.listConversations();
      if (!mounted) return;
      setState(() {
        _convs = list;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = ErrorHandler.getMessage(e);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'حدث خطأ غير متوقع';
          _loading = false;
        });
      }
    }
  }

  void _openConversation(Conversation c) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => ChatPage(conversationId: c.id),
          ),
        )
        .then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final isAr = appSettings.arabic;
    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        backgroundColor: context.kCard,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: !widget.embedded,
        leading: widget.embedded
            ? null
            : IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: context.kText),
                onPressed: () => Navigator.pop(context),
              ),
        title: Text(
          isAr ? 'الرسائل' : 'Messages',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: context.kText,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: context.kText),
            onPressed: _load,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: _buildBody(isAr),
      ),
    );
  }

  Widget _buildBody(bool isAr) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _load);
    }
    if (_convs.isEmpty) {
      return _EmptyState(isAr: isAr);
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: _convs.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        thickness: 0.5,
        color: AppColors.border,
        indent: 78,
      ),
      itemBuilder: (_, i) => _ConversationTile(
        conversation: _convs[i],
        onTap: () => _openConversation(_convs[i]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  CONVERSATION TILE
// ═════════════════════════════════════════════════════════════

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;
  const _ConversationTile({required this.conversation, required this.onTap});

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inDays == 0 && now.day == local.day) {
      return DateFormat('HH:mm').format(local);
    }
    if (diff.inDays < 7) return DateFormat.E('ar').format(local);
    return DateFormat('d MMM').format(local);
  }

  @override
  Widget build(BuildContext context) {
    final meId = userProvider.user?.id ?? 0;
    final other = conversation.otherParticipant(meId);
    final hasUnread = conversation.unreadCount > 0;
    final preview = conversation.lastMessagePreview?.trim().isNotEmpty == true
        ? conversation.lastMessagePreview!.trim()
        : 'ابدأ المحادثة 👋';
    final time = _formatTime(conversation.lastMessageAt);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Avatar ──
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              backgroundImage: (other.avatarUrl != null && other.avatarUrl!.isNotEmpty)
                  ? NetworkImage(other.avatarUrl!)
                  : null,
              child: (other.avatarUrl == null || other.avatarUrl!.isEmpty)
                  ? Text(
                      other.name.isNotEmpty
                          ? other.name.characters.first.toUpperCase()
                          : '؟',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          fontSize: 18),
                    )
                  : null,
            ),
            const SizedBox(width: 12),

            // ── Name + preview ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          other.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                hasUnread ? FontWeight.w900 : FontWeight.w700,
                            color: context.kText,
                          ),
                        ),
                      ),
                      if (other.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded,
                            size: 14, color: AppColors.primary),
                      ],
                      const Spacer(),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 11,
                          color: hasUnread
                              ? AppColors.primary
                              : context.kSub,
                          fontWeight:
                              hasUnread ? FontWeight.w800 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (conversation.property != null) ...[
                        Icon(Icons.home_work_outlined,
                            size: 12, color: context.kSub),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            conversation.property!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11,
                                color: context.kSub,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(' · ',
                            style:
                                TextStyle(fontSize: 11, color: context.kSub)),
                      ],
                      Expanded(
                        child: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: hasUnread ? context.kText : context.kSub,
                            fontWeight:
                                hasUnread ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(minWidth: 20),
                          child: Text(
                            conversation.unreadCount > 99
                                ? '99+'
                                : '${conversation.unreadCount}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
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
}

// ═════════════════════════════════════════════════════════════
//  EMPTY / ERROR states
// ═════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final bool isAr;
  const _EmptyState({required this.isAr});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Center(
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded,
                size: 40, color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            isAr ? 'مفيش محادثات لسه' : 'No conversations yet',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: context.kText),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            isAr
                ? 'اضغط زر «تواصل» في صفحة أي عقار لتبدأ محادثة مع المالك'
                : 'Tap "Contact" on any property to start a chat with the owner',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: context.kSub, height: 1.5),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: context.kSub),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.kSub, fontSize: 14),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('إعادة المحاولة'),
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
