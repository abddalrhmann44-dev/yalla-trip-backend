// ═══════════════════════════════════════════════════════════════
//  TALAA — Chat Inbox Page
//  Lists all user conversations
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../widgets/constants.dart';
import '../main.dart' show appSettings;

class ChatInboxPage extends StatelessWidget {
  final bool embedded;
  const ChatInboxPage({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final isAr = appSettings.arabic;

    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        backgroundColor: context.kCard,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: !embedded,
        leading: embedded
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Icon ──
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),

              // ── Title ──
              Text(
                isAr ? 'مفيش محادثات لسه' : 'No conversations yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.kText,
                ),
              ),
              const SizedBox(height: 8),

              // ── Subtitle ──
              Text(
                isAr
                    ? 'لما تحجز شاليه أو عقار هتقدر تتكلم مع المالك هنا'
                    : 'Book a property to start chatting with the owner',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: context.kSub,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),

              // ── CTA ──
              FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.search_rounded, size: 18),
                label: Text(
                  isAr ? 'استكشف العقارات' : 'Explore Properties',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
