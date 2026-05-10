// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin Chat Monitor Page  (Wave 30)
//
//  Live moderation feed of every chat ``Message`` in the platform.
//  Three tabs:
//
//    • مفلترة تلقائياً  — auto-flagged by the keyword scanner
//      (phone numbers, off-platform payment, profanity).  This is
//      the queue admins should drain first.
//    • مخفية           — messages an admin already hid; useful
//      when reverting a false-positive moderation.
//    • الأحدث          — unfiltered firehose of all messages,
//      newest first.  Used for spot-checks.
//
//  Actions per row: Hide / Unhide / Clear flag.  All three audit-log.
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
  List<ChatMessageRow> _flagged = [];
  List<ChatMessageRow> _hidden = [];
  List<ChatMessageRow> _all = [];
  final Set<int> _busy = {};

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
        ChatAdminService.list(flaggedOnly: true, limit: 200),
        ChatAdminService.list(hiddenOnly: true, limit: 200),
        ChatAdminService.list(limit: 200),
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
              Tab(text: 'مفلترة (${_flagged.length})'),
              Tab(text: 'مخفية (${_hidden.length})'),
              Tab(text: 'الأحدث (${_all.length})'),
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
                    emptyMsg: 'لا توجد رسائل مفلترة 🎉'),
                _buildList(_hidden,
                    emptyMsg: 'لا توجد رسائل مخفية'),
                _buildList(_all, emptyMsg: 'لا توجد رسائل'),
              ],
            ),
    );
  }

  Widget _buildList(List<ChatMessageRow> rows, {required String emptyMsg}) {
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
              itemBuilder: (_, i) {
                final m = rows[i];
                final accent = m.isHidden
                    ? _kRed
                    : (m.isFlagged ? _kAmber : _kOcean);
                return Container(
                  decoration: BoxDecoration(
                    color: context.kCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: accent.withValues(alpha: 0.4)),
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
                                  : Icons.chat_bubble_rounded),
                          color: accent,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                              '${m.senderName ?? "user #${m.senderId}"} • محادثة #${m.conversationId}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: context.kSub,
                                  fontWeight: FontWeight.w700)),
                        ),
                        Text(
                            intl.DateFormat('y/MM/dd HH:mm')
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
                                : m.body,
                            style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: context.kText,
                                fontStyle: m.isHidden
                                    ? FontStyle.italic
                                    : null)),
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
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        if (m.isFlagged && !m.isHidden)
                          const SizedBox(width: 6),
                        if (!m.isHidden)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _busy.contains(m.id)
                                  ? null
                                  : () => _hide(m),
                              icon: const Icon(
                                  Icons.visibility_off_rounded,
                                  color: _kRed,
                                  size: 16),
                              label: const Text('إخفاء',
                                  style: TextStyle(
                                      color: _kRed,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11.5)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                    color: _kRed.withValues(alpha: 0.5)),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        if (m.isHidden)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _busy.contains(m.id)
                                  ? null
                                  : () => _unhide(m),
                              icon: const Icon(
                                  Icons.visibility_rounded,
                                  color: _kGreen,
                                  size: 16),
                              label: const Text('إظهار',
                                  style: TextStyle(
                                      color: _kGreen,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11.5)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                    color: _kGreen.withValues(alpha: 0.5)),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                      ]),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
