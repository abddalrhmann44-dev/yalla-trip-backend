import 'package:flutter/material.dart';
import '../main.dart' show appSettings;
import '../utils/app_strings.dart';
import '../widgets/constants.dart';
import '../widgets/chat_bubble.dart';

// ── Message Model ─────────────────────────────────────────

class ChatMessage {
  final String id;
  final String text;
  final bool isSent;
  final String time;
  bool isRead;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isSent,
    required this.time,
    this.isRead = false,
  });
}

// ── Chat Page ─────────────────────────────────────────────

class ChatPage extends StatefulWidget {
  final String ownerName;
  final String propertyName;
  final String propertyEmoji;
  final String currentPrice;

  const ChatPage({
    super.key,
    required this.ownerName,
    required this.propertyName,
    required this.propertyEmoji,
    required this.currentPrice,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showWarning = false;
  String _warningText = '';

  // ── Booking state ─────────────────────────────────────────
  // بعد الحجز يتم رفع الحظر عن تبادل الأرقام
  bool _bookingConfirmed = false;

  // ── Phone / contact number detection ─────────────────────
  // Detects: Egyptian mobile (01x), landlines (0x), international (+xx),
  // WhatsApp mentions, Telegram, and digit strings 8+ chars
  static final RegExp _contactPattern = RegExp(
    r'(\+?[\d\s\-]{8,}|01[0125]\d{8}|'
    r'(واتس|واتساب|whatsapp|telegram|تيليجرام|تلفون|رقم|number|call|اتصل|تليفون))',
    caseSensitive: false,
  );

  final List<ChatMessage> _messages = [
    ChatMessage(
      id: '1',
      text: 'مرحباً! 👋 أنا مهتم بحجز ${''} هل السعر قابل للتفاوض؟',
      isSent: false,
      time: '10:30 AM',
      isRead: true,
    ),
    ChatMessage(
      id: '2',
      text: 'أهلاً بك! نعم السعر يشمل جميع الخدمات. ما هي الفترة التي تريد الحجز فيها؟',
      isSent: true,
      time: '10:32 AM',
      isRead: true,
    ),
    ChatMessage(
      id: '3',
      text: 'أريد من 15 إلى 20 يوليو، هل يمكن تخفيض السعر للإقامة الطويلة؟',
      isSent: false,
      time: '10:33 AM',
      isRead: true,
    ),
    ChatMessage(
      id: '4',
      text: 'بالتأكيد! لمدة 5 ليالي يمكنني تقديم خصم 15%. السعر سيكون EGP ${''} بدلاً من ${''} 💰',
      isSent: true,
      time: '10:35 AM',
      isRead: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    appSettings.addListener(_onLangChange);
    // Fix initial messages with property name
    _messages[0] = ChatMessage(
      id: '1',
      text: 'مرحباً! 👋 أنا مهتم بحجز ${widget.propertyEmoji} ${widget.propertyName}، هل السعر قابل للتفاوض؟',
      isSent: false,
      time: '10:30 AM',
      isRead: true,
    );
    _messages[3] = ChatMessage(
      id: '4',
      text: 'بالتأكيد! لمدة 5 ليالي يمكنني تقديم خصم 15%. يمكننا الاتفاق على السعر المناسب 💰',
      isSent: true,
      time: '10:35 AM',
      isRead: false,
    );
  }

  void _onLangChange() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    appSettings.removeListener(_onLangChange);
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _containsContactInfo(String text) {
    return _contactPattern.hasMatch(text);
  }

  void _sendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    // ── Block contact info (إلا بعد تأكيد الحجز) ─────────
    if (_containsContactInfo(text) && !_bookingConfirmed) {
      setState(() {
        _showWarning = true;
        _warningText =
            '⚠️ تبادل أرقام التواصل غير مسموح قبل الحجز.\n'
            'أكمل الحجز أولاً ثم يمكنك التواصل المباشر مع المالك.';
      });
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) setState(() => _showWarning = false);
      });
      return;
    }

    setState(() {
      _showWarning = false;
      _messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        isSent: true,
        time: _formatTime(DateTime.now()),
        isRead: false,
      ));
      _msgController.clear();
    });

    // Scroll to bottom
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

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final suffix = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $suffix';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // ── Price Banner ──
          _buildPriceBanner(),

          // ── Booking Confirmed Banner ──
          if (_bookingConfirmed)
            _buildBookingConfirmedBanner(),

          // ── Messages ──
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              itemCount: _messages.length + 1, // +1 for date divider
              itemBuilder: (context, i) {
                if (i == 0) {
                  return const ChatSystemMessage(message: 'اليوم');
                }
                final msg = _messages[i - 1];
                return ChatBubble(
                  message: msg.text,
                  type: msg.isSent
                      ? BubbleType.sent
                      : BubbleType.received,
                  time: msg.time,
                  showAvatar: !msg.isSent,
                  isRead: msg.isRead,
                );
              },
            ),
          ),

          // ── Warning Banner ──
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _showWarning
                ? _buildWarningBanner()
                : const SizedBox.shrink(),
          ),

          // ── Input Bar ──
          _buildInputBar(),
        ],
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: AppColors.primary,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Text(widget.propertyEmoji,
                  style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.ownerName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.circle,
                        size: 8, color: AppColors.success),
                    SizedBox(width: 4),
                    Text(
                      S.online,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.success,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline_rounded,
              color: AppColors.textHint),
          onPressed: () => _showChatRules(context),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
            height: 1, color: AppColors.border),
      ),
    );
  }

  // ── Price Banner ─────────────────────────────────────────

  Widget _buildPriceBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.primary.withValues(alpha: 0.05),
      child: Row(
        children: [
          const Icon(Icons.local_offer_rounded,
              size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
                children: [
                  const TextSpan(text: 'السعر: '),
                  TextSpan(
                    text: 'EGP ${widget.currentPrice}/ليلة',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // زر تأكيد الحجز — يرفع الحظر عن الأرقام
          if (!_bookingConfirmed)
            GestureDetector(
              onTap: () {
                setState(() {
                  _bookingConfirmed = true;
                  _showWarning = false;
                  // إضافة رسالة نظام بالحجز
                  _messages.add(ChatMessage(
                    id: 'booking_${DateTime.now().millisecondsSinceEpoch}',
                    text: '✅ تم تأكيد الحجز! يمكنكم الآن تبادل معلومات التواصل.',
                    isSent: false,
                    time: _formatTime(DateTime.now()),
                    isRead: true,
                  ));
                });
                Future.delayed(const Duration(milliseconds: 150), () {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('تأكيد الحجز ✓',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    );
  }

  // ── Booking Confirmed Banner ──────────────────────────────

  Widget _buildBookingConfirmedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
        ),
      ),
      child: Row(children: [
        const Text('✅', style: TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('تم تأكيد الحجز!',
                  style: TextStyle(color: Colors.white,
                      fontSize: 13, fontWeight: FontWeight.w900)),
              Text('يمكنكم الآن تبادل أرقام التواصل مباشرةً',
                  style: TextStyle(color: Colors.white70,
                      fontSize: 10)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text('🔓 محادثة مفتوحة',
              style: TextStyle(color: Colors.white,
                  fontSize: 9, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  // ── Warning Banner ────────────────────────────────────────

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
          const Icon(Icons.block_rounded,
              color: AppColors.error, size: 20),
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

  // ── Input Bar ─────────────────────────────────────────────

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(
            top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgController,
              maxLines: 3,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'اكتب رسالتك للتفاوض على السعر...',
                hintStyle: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: 13,
                ),
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
            onTap: _sendMessage,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: const Icon(
                Icons.send_rounded,
                color: AppColors.accent,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Chat Rules Dialog ─────────────────────────────────────

  void _showChatRules(BuildContext context) {
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
            Row(
              children: const [
                Icon(Icons.shield_outlined, color: AppColors.primary),
                SizedBox(width: 10),
                Text(
                  'قواعد الدردشة',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _ruleItem('✅', 'التفاوض على السعر مسموح به بالكامل'),
            _ruleItem('✅', 'سؤال عن المواعيد والخدمات'),
            _ruleItem('✅', 'طلب صور إضافية للمكان'),
            _ruleItem('🚫', 'تبادل أرقام الهاتف أو الواتساب'),
            _ruleItem('🚫', 'مشاركة روابط خارجية للتواصل'),
            _ruleItem('🚫', 'الدفع خارج التطبيق'),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Text(
                'نحن نحمي حقوقك! جميع الاتفاقيات والمدفوعات تتم داخل Yalla Trip لضمان أمانك.',
                style: TextStyle(
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

  Widget _ruleItem(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
