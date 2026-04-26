// ═══════════════════════════════════════════════════════════════
//  TALAA — Chat Page
//  Real-time (polling) chat backed by /chats/{id}/messages API.
// ═══════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart' show appSettings, userProvider;
import '../models/chat_model.dart';
import '../services/chat_service.dart';
import '../services/property_service.dart';
import '../utils/api_client.dart';
import '../utils/app_strings.dart';
import '../utils/error_handler.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/constants.dart';
import 'payment_page.dart';

/// Opens either by **conversationId** (from inbox) or by **propertyId**
/// (from the "negotiate price" CTA on property details — we create /
/// fetch the conversation lazily on open).
///
/// When opened by property, the caller may pass an initial
/// [checkIn] / [checkOut] / [guests] to seed the booking intent.  If
/// they are omitted we prompt the user for the trip window before
/// starting the thread, since every negotiation is scoped to a concrete
/// date range.
class ChatPage extends StatefulWidget {
  final int? conversationId;
  final int? propertyId;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final int? guests;

  const ChatPage({
    super.key,
    this.conversationId,
    this.propertyId,
    this.checkIn,
    this.checkOut,
    this.guests,
  }) : assert(conversationId != null || propertyId != null,
            'Provide either conversationId or propertyId');

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();

  Conversation? _conv;
  final List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  String _warningText = '';
  bool _showWarning = false;

  Timer? _poll;
  bool _foreground = true;

  // ── Phone / contact regex (carried over from the prototype) ─────
  static final RegExp _contactPattern = RegExp(
    r'(\+?[\d\s\-]{8,}|01[0125]\d{8}|'
    r'(واتس|واتساب|whatsapp|telegram|تيليجرام|تلفون|رقم|number|call|اتصل|تليفون))',
    caseSensitive: false,
  );

  int get _meId => userProvider.user?.id ?? 0;

  @override
  void initState() {
    super.initState();
    appSettings.addListener(_onLangChange);
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    appSettings.removeListener(_onLangChange);
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && _conv != null) _refreshMessages();
  }

  void _onLangChange() {
    if (mounted) setState(() {});
  }

  // ── Initial load ────────────────────────────────────────────────
  Future<void> _bootstrap() async {
    try {
      final Conversation conv;
      if (widget.conversationId != null) {
        conv = await ChatService.getConversation(widget.conversationId!);
      } else {
        // Starting a new thread requires trip intent so the backend
        // knows the scope of the negotiation.  If the caller didn't
        // pre-fill it, prompt the user right now.
        var ci = widget.checkIn;
        var co = widget.checkOut;
        var gs = widget.guests;
        if (ci == null || co == null || gs == null) {
          final trip = await _askTripWindow();
          if (trip == null) {
            if (mounted) Navigator.pop(context);
            return;
          }
          ci = trip.$1;
          co = trip.$2;
          gs = trip.$3;
        }
        conv = await ChatService.startConversation(
          widget.propertyId!,
          checkIn: ci,
          checkOut: co,
          guests: gs,
        );
      }
      if (!mounted) return;
      setState(() => _conv = conv);
      await _loadMessages(initial: true);
      await _markRead();
      _startPolling();
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
          _error = 'حدث خطأ أثناء فتح المحادثة';
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMessages({bool initial = false}) async {
    if (_conv == null) return;
    try {
      final (items, _) = await ChatService.listMessages(_conv!.id);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(items);
        _loading = false;
      });
      if (initial) _scrollToBottom(animate: false);
    } catch (_) {
      if (mounted && initial) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _refreshMessages() async {
    if (_conv == null || !_foreground) return;
    try {
      final (items, _) = await ChatService.listMessages(_conv!.id);
      if (!mounted) return;
      final prevCount = _messages.length;
      final sameLastId = prevCount > 0 &&
          items.isNotEmpty &&
          _messages.last.id == items.last.id;
      if (sameLastId && prevCount == items.length) return; // no changes
      setState(() {
        _messages
          ..clear()
          ..addAll(items);
      });
      // if a new incoming message arrived, mark-read + scroll
      final newestMine = items.isNotEmpty && items.last.senderId == _meId;
      if (!newestMine) {
        _markRead();
        _scrollToBottom();
      }
    } catch (_) {
      // swallow — next tick will retry
    }
  }

  Future<void> _markRead() async {
    if (_conv == null) return;
    try {
      final updated = await ChatService.markRead(_conv!.id);
      if (mounted) setState(() => _conv = updated);
    } catch (_) {/* best-effort */}
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshMessages(),
    );
  }

  // ── Send a message ─────────────────────────────────────────────
  Future<void> _sendMessage() async {
    if (_conv == null || _sending) return;
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    if (_contactPattern.hasMatch(text)) {
      setState(() {
        _showWarning = true;
        _warningText =
            '⚠️ تبادل أرقام التواصل غير مسموح. أكمل الحجز أولاً ثم يمكنك التواصل المباشر.';
      });
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) setState(() => _showWarning = false);
      });
      return;
    }

    setState(() {
      _sending = true;
      _showWarning = false;
    });

    // Optimistic insert.
    final temp = ChatMessage(
      id: -DateTime.now().millisecondsSinceEpoch,
      conversationId: _conv!.id,
      senderId: _meId,
      body: text,
      createdAt: DateTime.now(),
    );
    setState(() {
      _messages.add(temp);
      _msgController.clear();
    });
    _scrollToBottom();

    try {
      final sent = await ChatService.sendMessage(_conv!.id, text);
      if (!mounted) return;
      setState(() {
        // replace temp with server-confirmed message
        final idx = _messages.indexWhere((m) => m.id == temp.id);
        if (idx >= 0) _messages[idx] = sent;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id == temp.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الإرسال: ${ErrorHandler.getMessage(e)}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _messages.removeWhere((m) => m.id == temp.id));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom({bool animate = true}) {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  // ── Build ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final other = _conv?.otherParticipant(_meId);
    final name = other?.name ?? 'المحادثة';
    final property = _conv?.property;

    return AppBar(
      backgroundColor: AppColors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            size: 18, color: AppColors.primary),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            backgroundImage:
                (other?.avatarUrl != null && other!.avatarUrl!.isNotEmpty)
                    ? NetworkImage(other.avatarUrl!)
                    : null,
            child: (other?.avatarUrl == null || other!.avatarUrl!.isEmpty)
                ? Text(
                    name.isNotEmpty ? name.characters.first.toUpperCase() : '؟',
                    style: const TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.w800),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                  ),
                  if (other?.isVerified == true) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.verified_rounded,
                        size: 14, color: AppColors.primary),
                  ],
                ]),
                if (property != null)
                  Text(property.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600))
                else
                  Row(children: const [
                    Icon(Icons.circle, size: 8, color: AppColors.success),
                    SizedBox(width: 4),
                    Text('Online',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.success,
                            fontWeight: FontWeight.w600)),
                  ]),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon:
              const Icon(Icons.info_outline_rounded, color: AppColors.textHint),
          onPressed: _showChatRules,
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.border),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _bootstrap,
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
    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Text(
                    'ابدأ المحادثة — اكتب أول رسالة 👇',
                    style:
                        TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) {
                    final m = _messages[i];
                    final sent = m.senderId == _meId;
                    // Offer / accept / decline render as specialised
                    // bubbles so the user can take action inline.
                    if (m.isOffer) {
                      return _OfferBubble(
                        amount: m.offerAmount ?? 0,
                        sent: sent,
                        time: _formatTime(m.createdAt),
                        isLatestAcceptable:
                            _conv?.canAccept(_meId) == true &&
                                _messages.last.id == m.id,
                        onAccept: _acceptOffer,
                        onDecline: _declineOffer,
                        onCounter: _promptOffer,
                      );
                    }
                    if (m.isAccept) {
                      return ChatSystemMessage(message: m.body);
                    }
                    if (m.isDecline) {
                      return ChatSystemMessage(message: m.body);
                    }
                    return ChatBubble(
                      message: m.body,
                      type: sent ? BubbleType.sent : BubbleType.received,
                      time: _formatTime(m.createdAt),
                      showAvatar: !sent,
                      isRead: m.isRead,
                    );
                  },
                ),
        ),
        if (_conv?.isAccepted == true) _buildAcceptedBanner(),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child:
              _showWarning ? _buildWarningBanner() : const SizedBox.shrink(),
        ),
        _buildInputBar(),
      ],
    );
  }

  // ── Warning banner ─────────────────────────────────────────────
  Widget _buildWarningBanner() {
    return Container(
      key: const ValueKey('warning'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
            color: AppColors.error.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.block_rounded, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _warningText,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.error,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Input bar ──────────────────────────────────────────────────
  Widget _buildInputBar() {
    // When the thread is sealed (offer accepted / declined / expired),
    // replace the composer with a read-only notice.
    if (_conv != null && !_conv!.isOpen) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          // Offer button — opens the price-entry dialog.
          GestureDetector(
            onTap: _sending ? null : _promptOffer,
            child: Container(
              width: 46,
              height: 46,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    width: 1.5),
              ),
              child: const Icon(Icons.sell_outlined,
                  color: AppColors.primary, size: 20),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _msgController,
              maxLines: 3,
              minLines: 1,
              textInputAction: TextInputAction.send,
              enabled: !_sending,
              onSubmitted: (_) => _sendMessage(),
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'اكتب رسالتك...',
                hintStyle: const TextStyle(
                    color: AppColors.textLight, fontSize: 13),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.xxl),
                  borderSide: const BorderSide(
                      color: AppColors.border, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.xxl),
                  borderSide: const BorderSide(
                      color: AppColors.border, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.xxl),
                  borderSide: const BorderSide(
                      color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sending ? null : _sendMessage,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _sending ? AppColors.textLight : AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: _sending
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded,
                      color: AppColors.accent, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────
  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final m = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $suffix';
  }

  void _showChatRules() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppRadius.xl),
            topRight: Radius.circular(AppRadius.xl),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: const [
              Icon(Icons.shield_outlined, color: AppColors.primary),
              SizedBox(width: 10),
              Text('قواعد الدردشة',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary)),
            ]),
            const SizedBox(height: 20),
            _rule('✅', 'التفاوض على السعر مسموح به بالكامل'),
            _rule('✅', 'سؤال عن المواعيد والخدمات'),
            _rule('✅', 'طلب صور إضافية للمكان'),
            _rule('🚫', 'تبادل أرقام الهاتف أو الواتساب'),
            _rule('🚫', 'مشاركة روابط خارجية للتواصل'),
            _rule('🚫', 'الدفع خارج التطبيق'),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                '${S.appName} يحمي حقوقك! جميع الاتفاقيات والمدفوعات تتم داخل التطبيق لضمان أمانك.',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _rule(String emoji, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textSecondary))),
        ]),
      );

  // ══════════════════════════════════════════════════════════
  //  Trip-intent sheet (asked when starting a new thread)
  // ══════════════════════════════════════════════════════════
  Future<(DateTime, DateTime, int)?> _askTripWindow() async {
    DateTime? ci;
    DateTime? co;
    int gs = 2;

    return showModalBottomSheet<(DateTime, DateTime, int)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) => Container(
            padding: EdgeInsets.fromLTRB(
              20, 20, 20,
              20 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            decoration: const BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('تفاصيل الرحلة',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                const Text(
                  'حدد تاريخ الوصول والمغادرة وعدد الأفراد قبل فتح المحادثة',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final range = await showDateRangePicker(
                      context: ctx,
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365)),
                      initialDateRange: (ci != null && co != null)
                          ? DateTimeRange(start: ci!, end: co!)
                          : null,
                    );
                    if (range != null) {
                      setSheet(() {
                        ci = range.start;
                        co = range.end;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border:
                          Border.all(color: AppColors.border, width: 1.5),
                    ),
                    child: Row(children: [
                      const Icon(Icons.date_range_rounded,
                          color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          (ci == null || co == null)
                              ? 'اختر تاريخ الوصول والمغادرة'
                              : '${_fmtDate(ci!)}  →  ${_fmtDate(co!)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: (ci == null)
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border, width: 1.5),
                  ),
                  child: Row(children: [
                    const Icon(Icons.group_rounded, color: AppColors.primary),
                    const SizedBox(width: 10),
                    const Text('عدد الأفراد',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                      color: AppColors.primary,
                      onPressed: gs > 1
                          ? () => setSheet(() => gs = gs - 1)
                          : null,
                    ),
                    Text('$gs',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      color: AppColors.primary,
                      onPressed: gs < 50
                          ? () => setSheet(() => gs = gs + 1)
                          : null,
                    ),
                  ]),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: (ci == null || co == null)
                        ? null
                        : () => Navigator.pop(
                              sheetCtx,
                              (ci!, co!, gs),
                            ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.md)),
                    ),
                    child: const Text('متابعة',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  // ══════════════════════════════════════════════════════════
  //  Offer / accept / decline actions
  // ══════════════════════════════════════════════════════════
  Future<void> _promptOffer() async {
    if (_conv == null || !_conv!.isOpen) return;
    final controller = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إرسال عرض سعر'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'ادخل السعر المقترح بالجنيه المصري (لليلة للشاليه / للساعة للمراكب).',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'مثال: 1500',
                suffixText: 'ج.م',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(controller.text.trim());
              if (v != null && v > 0) Navigator.pop(ctx, v);
            },
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
    if (amount == null || _conv == null) return;

    try {
      await ChatService.postOffer(_conv!.id, amount);
      await _refreshMessages();
      final fresh = await ChatService.getConversation(_conv!.id);
      if (!mounted) return;
      setState(() => _conv = fresh);
    } on ApiException catch (e) {
      _showError(ErrorHandler.getMessage(e));
    } catch (_) {
      _showError('حدث خطأ أثناء إرسال العرض');
    }
  }

  Future<void> _declineOffer() async {
    if (_conv == null) return;
    try {
      await ChatService.declineOffer(_conv!.id);
      await _refreshMessages();
      final fresh = await ChatService.getConversation(_conv!.id);
      if (!mounted) return;
      setState(() => _conv = fresh);
    } on ApiException catch (e) {
      _showError(ErrorHandler.getMessage(e));
    } catch (_) {
      _showError('حدث خطأ أثناء رفض العرض');
    }
  }

  Future<void> _acceptOffer() async {
    if (_conv == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد قبول العرض'),
        content: Text(
          'هيتم إنشاء حجز بالسعر المتفق عليه '
          '(${_conv!.latestOfferAmount?.toStringAsFixed(0) ?? '-'} ج.م/ليلة) '
          'وهتنتقل لصفحة الدفع مباشرة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('قبول ومتابعة الدفع'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final result = await ChatService.acceptOffer(_conv!.id);
      if (!mounted) return;
      setState(() => _conv = result.conversation);
      await _refreshMessages();
      if (!mounted) return;
      // inDrive-style: price agreed → jump straight to payment.
      await _proceedToPaymentAfterAccept(result);
    } on ApiException catch (e) {
      _showError(ErrorHandler.getMessage(e));
    } catch (_) {
      _showError('حدث خطأ أثناء قبول العرض');
    }
  }

  /// After the backend seals the negotiation, load the property and
  /// push the user into PaymentPage with the agreed per-night rate ×
  /// nights + the property's fees already filled in.
  Future<void> _proceedToPaymentAfterAccept(
      ConversationAccepted result) async {
    final conv = _conv;
    if (conv == null ||
        conv.property == null ||
        conv.checkIn == null ||
        conv.checkOut == null) {
      // Missing trip context — fall back to the legacy snackbar so
      // the user can still reach the booking from "حجوزاتي".
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.success,
        content: Text(
            'تم إنشاء حجز ${result.bookingCode} ✅ — تابع الدفع من حجوزاتي'),
      ));
      return;
    }

    try {
      final prop = await PropertyService.getProperty(conv.property!.id);
      if (!mounted) return;

      final nights = conv.checkOut!.difference(conv.checkIn!).inDays;
      final offerAmount = conv.latestOfferAmount ?? 0;
      final baseAmount = (offerAmount * nights).toInt();
      final cleaningFee = prop.cleaningFee.toInt();
      final totalAmount = result.totalPrice.toInt();

      final checkInStr = '${conv.checkIn!.day}/'
          '${conv.checkIn!.month}/${conv.checkIn!.year}';
      final checkOutStr = '${conv.checkOut!.day}/'
          '${conv.checkOut!.month}/${conv.checkOut!.year}';

      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => PaymentPage(
          property: prop,
          checkIn: checkInStr,
          checkOut: checkOutStr,
          nights: nights,
          guests: conv.guests ?? 1,
          guestNote: '',
          baseAmount: baseAmount,
          cleaningFee: cleaningFee,
          totalAmount: totalAmount,
        ),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.success,
        content: Text(
            'تم إنشاء حجز ${result.bookingCode} ✅ — تابع الدفع من حجوزاتي'),
      ));
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.error,
    ));
  }

  // ══════════════════════════════════════════════════════════
  //  Accepted banner
  // ══════════════════════════════════════════════════════════
  Widget _buildAcceptedBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
            color: AppColors.success.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Row(children: [
        const Icon(Icons.celebration_rounded, color: AppColors.success),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _conv?.bookingId != null
                ? 'تم الاتفاق — حجز رقم #${_conv!.bookingId}.  تابع الحجز من قسم «حجوزاتي» لإتمام الدفع وعرض بيانات التواصل.'
                : 'تم الاتفاق — تابع الحجز من قسم «حجوزاتي».',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.success,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Offer bubble — price card with Accept / Decline / Counter
// ══════════════════════════════════════════════════════════════

class _OfferBubble extends StatelessWidget {
  final double amount;
  final bool sent;
  final String time;
  final bool isLatestAcceptable;
  final Future<void> Function() onAccept;
  final Future<void> Function() onDecline;
  final Future<void> Function() onCounter;

  const _OfferBubble({
    required this.amount,
    required this.sent,
    required this.time,
    required this.isLatestAcceptable,
    required this.onAccept,
    required this.onDecline,
    required this.onCounter,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment:
            sent ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: sent
                    ? AppColors.primary
                    : AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: sent
                    ? null
                    : Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.sell_rounded,
                        size: 18,
                        color: sent ? Colors.white : AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      sent ? 'عرضك' : 'عرض جديد',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: sent ? Colors.white70 : AppColors.primary,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    '${amount.toStringAsFixed(0)} ج.م',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color:
                          sent ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 10,
                      color: sent
                          ? Colors.white.withValues(alpha: 0.8)
                          : AppColors.textHint,
                    ),
                  ),
                  if (isLatestAcceptable) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        FilledButton.icon(
                          onPressed: onAccept,
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: const Text('قبول'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.success,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: onCounter,
                          icon: const Icon(Icons.swap_horiz_rounded,
                              size: 16),
                          label: const Text('عرض مضاد'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                sent ? Colors.white : AppColors.primary,
                            side: BorderSide(
                                color: sent
                                    ? Colors.white70
                                    : AppColors.primary),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: onDecline,
                          icon: const Icon(Icons.close_rounded, size: 16),
                          label: const Text('رفض'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.error,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
