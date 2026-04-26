// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin Users Management
//  Full user administration: list, filter, search, change role,
//  activate/deactivate, verify (KYC).  Backed by /admin/users/*.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../main.dart' show userProvider;
import '../../models/user_model_api.dart';
import '../../services/admin_service.dart';
import '../../utils/api_client.dart';
import '../../utils/error_handler.dart';
import '../../widgets/constants.dart';

const _kOcean  = Color(0xFFFF6B35);
const _kGreen  = Color(0xFF4CAF50);
const _kOrange = Color(0xFFFF6D00);
const _kRed    = Color(0xFFEF5350);
const _kPurple = Color(0xFF7E57C2);

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});
  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  static const _roles = <_RoleFilter>[
    _RoleFilter(label: 'الكل', value: null),
    _RoleFilter(label: 'ضيوف', value: 'guest'),
    _RoleFilter(label: 'ملاك', value: 'owner'),
    _RoleFilter(label: 'مشرفين', value: 'admin'),
  ];

  List<UserApi> _users = [];
  bool _loading = true;
  String? _error;
  String? _roleFilter;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await AdminService.getUsers(
        search: _searchCtrl.text.trim(),
        role: _roleFilter,
        limit: 200,
      );
      if (mounted) setState(() => _users = users);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = ErrorHandler.getMessage(e));
    } catch (e) {
      if (mounted) setState(() => _error = 'حصل خطأ، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ══════════════════════════════════════════════════════════
  //  ACTIONS
  // ══════════════════════════════════════════════════════════

  Future<void> _changeRole(UserApi u) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (_) => _RolePickerDialog(current: u.role, userName: u.name),
    );
    if (selected == null || selected == u.role) return;
    try {
      final updated = await AdminService.changeUserRole(u.id, selected);
      _replaceUser(updated);
      _snack('تم تغيير صلاحية ${u.name}', _kGreen);
    } on ApiException catch (e) {
      _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (_) {
      _snack('حصل خطأ', _kRed);
    }
  }

  Future<void> _toggleActive(UserApi u) async {
    final action = u.isActive ? 'تعطيل' : 'تفعيل';
    final ok = await _confirmDialog(
      '$action الحساب؟',
      u.isActive
          ? 'لن يتمكن ${u.name} من الدخول حتى يتم التفعيل مرة أخرى.'
          : 'سيتمكن ${u.name} من الدخول مرة أخرى.',
      u.isActive ? _kRed : _kGreen,
    );
    if (ok != true) return;
    try {
      if (u.isActive) {
        await AdminService.deactivateUser(u.id);
        _replaceUser(UserApi(
          id: u.id,
          firebaseUid: u.firebaseUid,
          name: u.name,
          email: u.email,
          phone: u.phone,
          role: u.role,
          avatarUrl: u.avatarUrl,
          isVerified: u.isVerified,
          isActive: false,
          createdAt: u.createdAt,
          updatedAt: DateTime.now(),
        ));
      } else {
        final updated = await AdminService.activateUser(u.id);
        _replaceUser(updated);
      }
      _snack('تم ${u.isActive ? "تعطيل" : "تفعيل"} ${u.name}',
          u.isActive ? _kRed : _kGreen);
    } on ApiException catch (e) {
      _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (_) {
      _snack('حصل خطأ', _kRed);
    }
  }

  Future<void> _toggleVerified(UserApi u) async {
    try {
      final updated = await AdminService.setUserVerified(u.id, !u.isVerified);
      _replaceUser(updated);
      _snack(
          updated.isVerified
              ? 'تم توثيق ${u.name}'
              : 'تم إلغاء توثيق ${u.name}',
          updated.isVerified ? _kGreen : _kOrange);
    } on ApiException catch (e) {
      _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (_) {
      _snack('حصل خطأ', _kRed);
    }
  }

  void _replaceUser(UserApi updated) {
    setState(() {
      final idx = _users.indexWhere((u) => u.id == updated.id);
      if (idx >= 0) _users[idx] = updated;
    });
  }

  // ── Helpers ─────────────────────────────────────────────────
  Future<bool?> _confirmDialog(String title, String body, Color color) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: TextStyle(fontWeight: FontWeight.w900, color: color)),
        content: Text(body, style: TextStyle(color: context.kSub)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء',
                style: TextStyle(color: _kOcean, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('تأكيد',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, Color color) {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }

  // ══════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        backgroundColor: context.kCard,
        elevation: 0,
        title: Text('إدارة المستخدمين',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: context.kText)),
        centerTitle: true,
      ),
      body: Column(children: [
        // ── Search bar ─────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            onSubmitted: (_) => _load(),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'ابحث بالاسم…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchCtrl.clear();
                        _load();
                      },
                    ),
            ),
          ),
        ),

        // ── Role filter chips ──────────────────────────
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _roles.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final r = _roles[i];
              final selected = _roleFilter == r.value;
              return ChoiceChip(
                label: Text(r.label),
                selected: selected,
                onSelected: (_) {
                  setState(() => _roleFilter = r.value);
                  _load();
                },
                selectedColor: _kOcean,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : context.kText,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),

        // ── Content ─────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _kOcean))
              : _error != null
                  ? _errorState()
                  : _users.isEmpty
                      ? _emptyState()
                      : RefreshIndicator(
                          color: _kOcean,
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _users.length,
                            itemBuilder: (_, i) => _userCard(_users[i]),
                          ),
                        ),
        ),
      ]),
    );
  }

  // ── User Card ───────────────────────────────────────────────
  Widget _userCard(UserApi u) {
    final isSelf = userProvider.user?.id == u.id;
    final roleColor = switch (u.role) {
      'admin' => _kRed,
      'owner' => _kPurple,
      _ => _kOcean,
    };
    final roleLabel = switch (u.role) {
      'admin' => 'مشرف',
      'owner' => 'مالك',
      _ => 'ضيف',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.kBorder),
      ),
      child: Column(children: [
        Row(children: [
          // Avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: roleColor.withValues(alpha: 0.3)),
            ),
            clipBehavior: Clip.antiAlias,
            child: (u.avatarUrl != null && u.avatarUrl!.isNotEmpty)
                ? CachedNetworkImage(
                    imageUrl: u.avatarUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        Icon(Icons.person_rounded, color: roleColor, size: 24),
                  )
                : Icon(Icons.person_rounded, color: roleColor, size: 24),
          ),
          const SizedBox(width: 12),

          // Name + email
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(
                      u.name.isEmpty ? '(بدون اسم)' : u.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: context.kText),
                    ),
                  ),
                  if (u.isVerified) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.verified_rounded,
                        color: _kOcean, size: 16),
                  ],
                  if (isSelf) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _kOrange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('أنت',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: _kOrange)),
                    ),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(
                  u.email?.isNotEmpty == true
                      ? u.email!
                      : (u.phone ?? 'بدون بيانات'),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: context.kSub),
                ),
              ],
            ),
          ),

          // Role badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(roleLabel,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: roleColor)),
          ),
        ]),

        const SizedBox(height: 10),
        Divider(height: 1, color: context.kBorder),
        const SizedBox(height: 10),

        // Status chips
        Row(children: [
          _statusChip(
            u.isActive ? 'مُفعّل' : 'مُعطّل',
            u.isActive ? _kGreen : _kRed,
            u.isActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
          ),
          const SizedBox(width: 8),
          if (u.isVerified)
            _statusChip('موثّق', _kOcean, Icons.verified_rounded)
          else
            _statusChip('غير موثّق', context.kSub, Icons.shield_outlined),
          const Spacer(),
          Text(
            '#${u.id}',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: context.kSub),
          ),
        ]),

        const SizedBox(height: 12),

        // Action buttons
        Row(children: [
          Expanded(
            child: _actionBtn(
              icon: Icons.admin_panel_settings_rounded,
              label: 'تغيير الصلاحية',
              color: _kPurple,
              disabled: isSelf && u.role == 'admin',
              onTap: () => _changeRole(u),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _actionBtn(
              icon: u.isVerified
                  ? Icons.shield_outlined
                  : Icons.verified_rounded,
              label: u.isVerified ? 'إلغاء توثيق' : 'توثيق',
              color: _kOcean,
              onTap: () => _toggleVerified(u),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _actionBtn(
              icon: u.isActive
                  ? Icons.block_rounded
                  : Icons.play_circle_fill_rounded,
              label: u.isActive ? 'تعطيل' : 'تفعيل',
              color: u.isActive ? _kRed : _kGreen,
              disabled: isSelf,
              onTap: () => _toggleActive(u),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _statusChip(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w800, color: color)),
      ]),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool disabled = false,
  }) {
    return Opacity(
      opacity: disabled ? 0.35 : 1,
      child: GestureDetector(
        onTap: disabled
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap();
              },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 3),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: color)),
          ]),
        ),
      ),
    );
  }

  Widget _emptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline_rounded,
                size: 72, color: context.kSub.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('لا يوجد مستخدمين مطابقين للبحث',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.kSub)),
          ],
        ),
      );

  Widget _errorState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 56, color: _kRed.withValues(alpha: 0.6)),
              const SizedBox(height: 12),
              Text(_error ?? 'حصل خطأ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.kText)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════
//  Role filter helper
// ══════════════════════════════════════════════════════════════════
class _RoleFilter {
  final String label;
  final String? value;
  const _RoleFilter({required this.label, required this.value});
}

// ══════════════════════════════════════════════════════════════════
//  Role picker dialog
// ══════════════════════════════════════════════════════════════════
class _RolePickerDialog extends StatelessWidget {
  final String current;
  final String userName;
  const _RolePickerDialog({required this.current, required this.userName});

  @override
  Widget build(BuildContext context) {
    const options = [
      ('guest', 'ضيف', _kOcean, Icons.person_outline_rounded),
      ('owner', 'مالك', _kPurple, Icons.apartment_rounded),
      ('admin', 'مشرف', _kRed, Icons.admin_panel_settings_rounded),
    ];

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('صلاحية المستخدم',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: context.kText)),
          const SizedBox(height: 4),
          Text(userName,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: context.kSub)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: options
            .map((o) => InkWell(
                  onTap: () => Navigator.pop(context, o.$1),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: current == o.$1
                          ? o.$3.withValues(alpha: 0.12)
                          : context.kSand,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: current == o.$1
                            ? o.$3
                            : context.kBorder,
                      ),
                    ),
                    child: Row(children: [
                      Icon(o.$4, color: o.$3, size: 20),
                      const SizedBox(width: 10),
                      Text(o.$2,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: context.kText)),
                      const Spacer(),
                      if (current == o.$1)
                        Icon(Icons.check_circle_rounded,
                            color: o.$3, size: 18),
                    ]),
                  ),
                ))
            .toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
      ],
    );
  }
}
