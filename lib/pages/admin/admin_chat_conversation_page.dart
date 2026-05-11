// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin Chat Conversation Detail
//
//  Opened from the chat-monitor list when an admin taps a single
//  conversation card.  Shows every message in that thread (oldest →
//  newest) with the same Hide / Unhide / Clear-flag actions as the
//  flat firehose page.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;

import '../../services/chat_admin_service.dart';
import '../../utils/api_client.dart';
import '../../utils/error_handler.dart';
import '../../widgets/constants.dart';

const _kOcean = Color(0xFFFF6B35);
const _kRed = Color(0xFFEF5350);
const _kGreen = Color(0xFF4CAF50);
const _kAmber = Color(0xFFFFB300);

class AdminChatConversationPage extends StatefulWidget {
  final ChatConversationRow conversation;
  const AdminChatConversationPage({super.key, required this.conversation});

  @override
  State<AdminChatConversationPage> createState() =>
      _AdminChatConversationPageState();
}

class _AdminChatConversationPageState
    extends State<AdminChatConversationPage> {
  bool _loading = true;
  List<ChatMessageRow> _messages = [];
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await ChatAdminService.list(
        conversationId: widget.conversation.id,
        limit: 500,
      );
      _messages = rows;
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('فشل التحميل: $e', _kRed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _hide(ChatMessageRow m) async {
    final note = await _askNote(
        title: 'إخفاء الرسالة',
        hint: 'سبب الإخفاء (اختياري)',
        cta: 'إخفاء',
        ctaColor: _kRed);
    if (note == null) return;
    HapticFeedback.lightImpact();
    setState(() => _busy.add(m.id));
    try {
      await ChatAdminService.hide(m.id, note: note);
      if (!mounted) return;
      _snack('تم إخفاء الرسالة', _kGreen);
      await _load();
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('فشل: $e', _kRed);
    } finally {
      if (mounted) setState(() => _busy.remove(m.id));
    }
  }

  Future<void> _unhide(ChatMessageRow m) async {
    setState(() => _busy.add(m.id));
    try {
      await ChatAdminService.unhide(m.id);
      if (!mounted) return;
      _snack('تم إلغاء الإخفاء', _kGreen);
      await _load();
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('فشل: $e', _kRed);
    } finally {
      if (mounted) setState(() => _busy.remove(m.id));
    }
  }

  Future<void> _clearFlag(ChatMessageRow m) async {
    setState(() => _busy.add(m.id));
    try {
      await ChatAdminService.clearFlag(m.id);
      if (!mounted) return;
      _snack('تم تجاهل التنبيه', _kGreen);
      await _load();
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('فشل: $e', _kRed);
    } finally {
      if (mounted) setState(() => _busy.remove(m.id));
    }
  }

  Future<String?> _askNote({
    required String title,
    required String hint,
    required String cta,
    required Color ctaColor,
  }) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style:
                TextStyle(fontWeight: FontWeight.w900, color: ctaColor)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          maxLength: 200,
          decoration: InputDecoration(
            hintText: hint,
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء',
                style: TextStyle(
                    color: context.kSub, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: ctaColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(cta,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
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
    final c = widget.conversation;
    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        backgroundColor: _kOcean,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('محادثة #${c.id}',
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    fontSize: 16)),
            const SizedBox(height: 2),
            Text(
                '${c.guestName ?? "guest #${c.guestId}"} ↔ ${c.ownerName ?? "owner #${c.ownerId}"}',
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(c),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _kOcean))
                : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ChatConversationRow c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: context.kCard,
        border: Border(
          bottom: BorderSide(
              color: context.kSub.withValues(alpha: 0.15)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (c.propertyName != null)
            Row(children: [
              const Icon(Icons.home_work_rounded,
                  size: 14, color: _kOcean),
              const SizedBox(width: 6),
              Expanded(
                child: Text(c.propertyName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: context.kText)),
              ),
            ]),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chip('${c.messageCount} رسالة', _kOcean),
              if (c.flaggedCount > 0)
                _chip('🚩 ${c.flaggedCount} مفلترة', _kAmber),
              if (c.hiddenCount > 0)
                _chip('⚫ ${c.hiddenCount} مخفية', _kRed),
              _chip(c.status, context.kSub),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(text,
          style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w800)),
    );
  }

  Widget _buildList() {
    if (_messages.isEmpty) {
      return RefreshIndicator(
        color: _kOcean,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 100),
            Icon(Icons.chat_bubble_outline_rounded,
                size: 64,
                color: context.kSub.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Center(
                child: Text('لا توجد رسائل',
                    style: TextStyle(
                        color: context.kSub,
                        fontSize: 14,
                        fontWeight: FontWeight.w600))),
          ],
        ),
      );
    }

    final guestId = widget.conversation.guestId;
    return RefreshIndicator(
      color: _kOcean,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _messages.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final m = _messages[i];
          final isGuest = m.senderId == guestId;
          return _bubble(m, isGuest);
        },
      ),
    );
  }

  Widget _bubble(ChatMessageRow m, bool isGuest) {
    final accent = m.isHidden
        ? _kRed
        : (m.isFlagged ? _kAmber : (isGuest ? _kOcean : _kGreen));
    return Align(
      alignment: isGuest ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
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
                Icon(
                  m.isHidden
                      ? Icons.visibility_off_rounded
                      : (m.isFlagged
                          ? Icons.flag_rounded
                          : (isGuest
                              ? Icons.person_rounded
                              : Icons.store_rounded)),
                  color: accent,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                      '${m.senderName ?? "user #${m.senderId}"} • ${isGuest ? "ضيف" : "مالك"}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          color: context.kSub,
                          fontWeight: FontWeight.w700)),
                ),
                Text(
                    intl.DateFormat('HH:mm  y/MM/dd')
                        .format(m.createdAt.toLocal()),
                    style: TextStyle(
                        fontSize: 10,
                        color: context.kSub,
                        fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.kSand.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                    m.isHidden
                        ? '⚫ تم إخفاء هذه الرسالة'
                        : (m.body.isEmpty
                            ? '— ${m.kind} —'
                            : m.body),
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: context.kText,
                        fontStyle:
                            m.isHidden ? FontStyle.italic : null)),
              ),
              if ((m.flagReason ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.info_outline_rounded,
                      color: _kAmber, size: 12),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(m.flagReason!,
                        style: const TextStyle(
                            color: _kAmber,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700)),
                  ),
                ]),
              ],
              const SizedBox(height: 10),
              Row(children: [
                if (m.isFlagged && !m.isHidden)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy.contains(m.id)
                          ? null
                          : () => _clearFlag(m),
                      icon: const Icon(Icons.check_rounded,
                          color: _kGreen, size: 16),
                      label: const Text('false positive',
                          style: TextStyle(
                              color: _kGreen,
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: _kGreen.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                if (m.isFlagged && !m.isHidden) const SizedBox(width: 6),
                if (!m.isHidden)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy.contains(m.id)
                          ? null
                          : () => _hide(m),
                      icon: const Icon(Icons.visibility_off_rounded,
                          color: _kRed, size: 16),
                      label: const Text('إخفاء',
                          style: TextStyle(
                              color: _kRed,
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: _kRed.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                if (m.isHidden)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy.contains(m.id)
                          ? null
                          : () => _unhide(m),
                      icon: const Icon(Icons.visibility_rounded,
                          color: _kGreen, size: 16),
                      label: const Text('إظهار',
                          style: TextStyle(
                              color: _kGreen,
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: _kGreen.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
