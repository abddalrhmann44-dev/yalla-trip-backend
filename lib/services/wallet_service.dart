// ═══════════════════════════════════════════════════════════════
//  TALAA — Wallet + Referrals Service
//  Thin DTO + API wrapper over /wallet/* endpoints.
// ═══════════════════════════════════════════════════════════════

import '../utils/api_client.dart';

enum WalletTxnType {
  referralBonus,
  signupBonus,
  bookingRefund,
  bookingRedeem,
  adminAdjust,
  topup,
  unknown,
}

WalletTxnType _typeFromCode(String s) {
  switch (s) {
    case 'referral_bonus':
      return WalletTxnType.referralBonus;
    case 'signup_bonus':
      return WalletTxnType.signupBonus;
    case 'booking_refund':
      return WalletTxnType.bookingRefund;
    case 'booking_redeem':
      return WalletTxnType.bookingRedeem;
    case 'admin_adjust':
      return WalletTxnType.adminAdjust;
    case 'topup':
      return WalletTxnType.topup;
  }
  return WalletTxnType.unknown;
}

String walletTxnLabelAr(WalletTxnType t) {
  switch (t) {
    case WalletTxnType.referralBonus:
      return 'مكافأة دعوة صديق';
    case WalletTxnType.signupBonus:
      return 'مكافأة التسجيل';
    case WalletTxnType.bookingRefund:
      return 'استرداد حجز';
    case WalletTxnType.bookingRedeem:
      return 'خصم من المحفظة';
    case WalletTxnType.adminAdjust:
      return 'تعديل إداري';
    case WalletTxnType.topup:
      return 'شحن بالبطاقة';
    case WalletTxnType.unknown:
      return 'عملية';
  }
}

enum ReferralStatus { pending, rewarded, expired, unknown }

ReferralStatus _refStatusFromCode(String s) {
  switch (s) {
    case 'pending':
      return ReferralStatus.pending;
    case 'rewarded':
      return ReferralStatus.rewarded;
    case 'expired':
      return ReferralStatus.expired;
  }
  return ReferralStatus.unknown;
}

String referralStatusLabelAr(ReferralStatus s) {
  switch (s) {
    case ReferralStatus.pending:
      return 'في الانتظار';
    case ReferralStatus.rewarded:
      return 'تم المكافأة';
    case ReferralStatus.expired:
      return 'منتهية';
    case ReferralStatus.unknown:
      return '-';
  }
}

// ── Models ────────────────────────────────────────────────
class WalletTxn {
  final int id;
  final double amount;
  final WalletTxnType type;
  final double balanceAfter;
  final String? description;
  final int? bookingId;
  final int? referralId;
  final DateTime createdAt;

  WalletTxn({
    required this.id,
    required this.amount,
    required this.type,
    required this.balanceAfter,
    required this.description,
    required this.bookingId,
    required this.referralId,
    required this.createdAt,
  });

  factory WalletTxn.fromJson(Map<String, dynamic> j) => WalletTxn(
        id: j['id'] as int,
        amount: (j['amount'] as num).toDouble(),
        type: _typeFromCode(j['type'] as String),
        balanceAfter: (j['balance_after'] as num).toDouble(),
        description: j['description'] as String?,
        bookingId: j['booking_id'] as int?,
        referralId: j['referral_id'] as int?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class WalletSummary {
  final double balance;
  final double lifetimeEarned;
  final double lifetimeSpent;
  final String? referralCode;
  final List<WalletTxn> recentTransactions;

  WalletSummary({
    required this.balance,
    required this.lifetimeEarned,
    required this.lifetimeSpent,
    required this.referralCode,
    required this.recentTransactions,
  });

  factory WalletSummary.fromJson(Map<String, dynamic> j) => WalletSummary(
        balance: (j['balance'] as num).toDouble(),
        lifetimeEarned: (j['lifetime_earned'] as num).toDouble(),
        lifetimeSpent: (j['lifetime_spent'] as num).toDouble(),
        referralCode: j['referral_code'] as String?,
        recentTransactions: [
          for (final t in (j['recent_transactions'] as List? ?? []))
            WalletTxn.fromJson(t as Map<String, dynamic>)
        ],
      );
}

class ReferralEntry {
  final int id;
  final int inviteeId;
  final String? inviteeName;
  final ReferralStatus status;
  final double? rewardAmount;
  final DateTime? rewardedAt;
  final DateTime createdAt;

  ReferralEntry({
    required this.id,
    required this.inviteeId,
    required this.inviteeName,
    required this.status,
    required this.rewardAmount,
    required this.rewardedAt,
    required this.createdAt,
  });

  factory ReferralEntry.fromJson(Map<String, dynamic> j) => ReferralEntry(
        id: j['id'] as int,
        inviteeId: j['invitee_id'] as int,
        inviteeName: j['invitee_name'] as String?,
        status: _refStatusFromCode(j['status'] as String),
        rewardAmount: (j['reward_amount'] as num?)?.toDouble(),
        rewardedAt: j['rewarded_at'] == null
            ? null
            : DateTime.parse(j['rewarded_at'] as String),
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class ReferralSummary {
  final String referralCode;
  final String referralLink;
  final int totalReferrals;
  final int rewardedCount;
  final int pendingCount;
  final double totalEarned;
  final List<ReferralEntry> referrals;

  ReferralSummary({
    required this.referralCode,
    required this.referralLink,
    required this.totalReferrals,
    required this.rewardedCount,
    required this.pendingCount,
    required this.totalEarned,
    required this.referrals,
  });

  factory ReferralSummary.fromJson(Map<String, dynamic> j) => ReferralSummary(
        referralCode: j['referral_code'] as String,
        referralLink: j['referral_link'] as String,
        totalReferrals: j['total_referrals'] as int,
        rewardedCount: j['rewarded_count'] as int,
        pendingCount: j['pending_count'] as int,
        totalEarned: (j['total_earned'] as num).toDouble(),
        referrals: [
          for (final r in (j['referrals'] as List? ?? []))
            ReferralEntry.fromJson(r as Map<String, dynamic>)
        ],
      );
}

class RedeemPreview {
  final double availableBalance;
  final double maxRedeemable;
  final String? capReason;
  RedeemPreview({
    required this.availableBalance,
    required this.maxRedeemable,
    required this.capReason,
  });
  factory RedeemPreview.fromJson(Map<String, dynamic> j) => RedeemPreview(
        availableBalance: (j['available_balance'] as num).toDouble(),
        maxRedeemable: (j['max_redeemable'] as num).toDouble(),
        capReason: j['cap_reason'] as String?,
      );
}

// ── Service ───────────────────────────────────────────────
class WalletService {
  static final _api = ApiClient();

  static Future<WalletSummary> summary() async {
    final res = await _api.get('/wallet/me');
    return WalletSummary.fromJson(res as Map<String, dynamic>);
  }

  static Future<RedeemPreview> redeemPreview(double subtotal) async {
    final res = await _api.post(
      '/wallet/me/redeem/preview?subtotal=$subtotal',
      {},
    );
    return RedeemPreview.fromJson(res as Map<String, dynamic>);
  }

  static Future<ReferralSummary> referrals() async {
    final res = await _api.get('/wallet/referrals/me');
    return ReferralSummary.fromJson(res as Map<String, dynamic>);
  }

  /// Credit the user's wallet after a successful card payment.
  ///
  /// The MVP backend trusts the client; integrate the gateway SDK on
  /// the Flutter side and pass the returned transaction reference as
  /// [gatewayReference] so it's persisted in the ledger description.
  static Future<WalletSummary> topup({
    required double amount,
    String? gatewayReference,
  }) async {
    final res = await _api.post(
      '/wallet/me/topup',
      {
        'amount': amount,
        if (gatewayReference != null) 'gateway_reference': gatewayReference,
      },
    );
    return WalletSummary.fromJson(res as Map<String, dynamic>);
  }

  // Admin.
  static Future<WalletSummary> adminAdjust({
    required int userId,
    required double amount,
    required String description,
  }) async {
    final res = await _api.post(
      '/wallet/admin/$userId/adjust',
      {'amount': amount, 'description': description},
    );
    return WalletSummary.fromJson(res as Map<String, dynamic>);
  }

  static Future<Map<String, dynamic>> adminStats() async {
    final res = await _api.get('/wallet/admin/stats');
    return (res as Map).cast<String, dynamic>();
  }
}
