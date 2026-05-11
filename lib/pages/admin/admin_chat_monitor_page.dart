// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin Chat Monitor Page  (Wave 30)
//
//  Conversation-centric moderation view.  Each row is a *single*
//  chat thread between a guest and an owner — admins tap a row to
//  open the full thread in `AdminChatConversationPage` instead of
//  scrolling a flat firehose of every message in the platform.
//
//  Three tabs:
//
//    • بها مفلترة  — conversations that contain at least one
//      auto-flagged message.  Drain this queue first.
//    • بها مخفية   — conversations that contain at least one
//      hidden message (useful for reverting moderation).
//    • الكل        — every conversation, newest activity first.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../../services/chat_admin_service.dart';
import '../../utils/api_client.dart';
import '../../utils/error_handler.dart';
import '../../widgets/constants.dart';
import 'admin_chat_conversation_page.dart';

const _kOcean = Color(0xFFFF6B35);
const _kRed = Color(0xFFEF5350);
const _kAmber = Color(0xFFFFB300);

class AdminChatMonitorPage extends StatefulWidget {
  const AdminChatMonitorPage({super.key});
  @override
  State<AdminChatMonitorPage> createState() =>
      _AdminChatMonitorPageState();
}

class _AdminChatMonitorPageState extends State<AdminChatMonitorPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  bool _loading = true;
  List<ChatConversationRow> _flagged = [];
  List<ChatConversationRow> _hidden = [];
  List<ChatConversationRow> _all = [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ChatAdminService.listConversations(flaggedOnly: true, limit: 300),
        ChatAdminService.listConversations(hiddenOnly: true, limit: 300),
        ChatAdminService.listConversations(limit: 300),
      ]);
      _flagged = results[0];
      _hidden = results[1];
      _all = results[2];
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('فشل التحميل: $e', _kRed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(ChatConversationRow c) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminChatConversationPage(conversation: c),
      ),
    );
    if (mounted) _load();
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        backgroundColor: _kOcean,
        elevation: 0,
        title: const Text('مراقبة المحادثات',
            style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.white,
                fontSize: 17)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tab,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            unselectedLabelColor: Colors.white.withValues(alpha: 0.65),
            unselectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            tabs: [
              Tab(text: 'بها مفلترة (${_flagged.length})'),
              Tab(text: 'بها مخفية (${_hidden.length})'),
              Tab(text: 'الكل (${_all.length})'),
            ],
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kOcean))
          : TabBarView(
              controller: _tab,
              children: [
                _buildList(_flagged,
                    emptyMsg: 'لا توجد محادثات بها رسائل مفلترة 🎉'),
                _buildList(_hidden,
                    emptyMsg: 'لا توجد محادثات بها رسائل مخفية'),
                _buildList(_all, emptyMsg: 'لا توجد محادثات'),
              ],
            ),
    );
  }

  Widget _buildList(List<ChatConversationRow> rows,
      {required String emptyMsg}) {
    return RefreshIndicator(
      color: _kOcean,
      onRefresh: _load,
      child: rows.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 100),
                Icon(Icons.chat_bubble_outline_rounded,
                    size: 64,
                    color: context.kSub.withValues(alpha: 0.4)),
                const SizedBox(height: 16),
                Center(
                    child: Text(emptyMsg,
                        style: TextStyle(
                            color: context.kSub,
                            fontSize: 14,
                            fontWeight: FontWeight.w600))),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _conversationTile(rows[i]),
            ),
    );
  }

  Widget _conversationTile(ChatConversationRow c) {
    final accent = c.hiddenCount > 0
        ? _kRed
        : (c.flaggedCount > 0 ? _kAmber : _kOcean);
    final timeStr = c.lastMessageAt == null
        ? '—'
        : intl.DateFormat('y/MM/dd HH:mm')
            .format(c.lastMessageAt!.toLocal());
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _open(c),
        child: Container(
          decoration: BoxDecoration(
            color: context.kCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.4)),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    c.hiddenCount > 0
                        ? Icons.visibility_off_rounded
                        : (c.flaggedCount > 0
                            ? Icons.flag_rounded
                            : Icons.chat_rounded),
                    color: accent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${c.guestName ?? "guest #${c.guestId}"}  ↔  ${c.ownerName ?? "owner #${c.ownerId}"}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: context.kText)),
                      const SizedBox(height: 2),
                      Text(
                          c.propertyName == null
                              ? 'محادثة #${c.id}'
                              : '${c.propertyName} • محادثة #${c.id}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: context.kSub)),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(timeStr,
                    style: TextStyle(
                        fontSize: 10,
                        color: context.kSub,
                        fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 10),
              if ((c.lastMessagePreview ?? '').isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.kSand.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(c.lastMessagePreview!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: context.kText)),
                ),
              const SizedBox(height: 8),
              Row(children: [
                _miniChip(Icons.chat_bubble_rounded,
                    '${c.messageCount}', _kOcean),
                if (c.flaggedCount > 0) ...[
                  const SizedBox(width: 6),
                  _miniChip(Icons.flag_rounded,
                      '${c.flaggedCount}', _kAmber),
                ],
                if (c.hiddenCount > 0) ...[
                  const SizedBox(width: 6),
                  _miniChip(Icons.visibility_off_rounded,
                      '${c.hiddenCount}', _kRed),
                ],
                const Spacer(),
                Icon(Icons.chevron_left_rounded,
                    color: context.kSub, size: 20),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w800)),
      ]),
    );
  }

}
