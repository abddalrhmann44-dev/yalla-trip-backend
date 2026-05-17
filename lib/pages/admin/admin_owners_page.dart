// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin Owners Management
//  List all property owners with search / filter; tap to detail page.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/constants.dart';
import '../../models/user_model_api.dart';
import '../../models/property_model_api.dart';
import '../../services/admin_service.dart';
import 'admin_owner_detail_page.dart';

const _kOcean  = Color(0xFFFF6B35);
const _kGreen  = Color(0xFF4CAF50);
const _kRed    = Color(0xFFEF5350);
const _kPurple = Color(0xFF7E57C2);

class AdminOwnersPage extends StatefulWidget {
  const AdminOwnersPage({super.key});
  @override
  State<AdminOwnersPage> createState() => _AdminOwnersPageState();
}

class _AdminOwnersPageState extends State<AdminOwnersPage> {
  List<UserApi> _owners = [];
  List<UserApi> _filtered = [];
  Map<int, int> _propCount = {}; // ownerId → count
  List<PropertyApi> _allProps = [];
  bool _loading = true;
  String? _error;
  String _filter = 'الكل';
  final _searchCtrl = TextEditingController();

  static const _filters = ['الكل', 'مُفعّل', 'موقوف'];

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
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        AdminService.getUsers(role: 'owner', limit: 100),
        AdminService.getProperties(limit: 100),
      ]);
      _owners = results[0] as List<UserApi>;
      _allProps = results[1] as List<PropertyApi>;
      _propCount = {};
      for (final p in _allProps) {
        _propCount[p.ownerId] = (_propCount[p.ownerId] ?? 0) + 1;
      }
      _applyFilter();
    } catch (e) {
      debugPrint('Admin owners error: $e');
      if (mounted) setState(() => _error = 'تعذّر تحميل الملاك، حاول مرة أخرى');
    }
    if (mounted) setState(() => _loading = false);
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    _filtered = _owners.where((u) {
      if (_filter == 'مُفعّل' && !u.isActive) return false;
      if (_filter == 'موقوف' && u.isActive) return false;
      if (q.isEmpty) return true;
      final code = 'own-${u.id.toString().padLeft(4, '0')}';
      return u.name.toLowerCase().contains(q) ||
          (u.phone?.contains(q) ?? false) ||
          code.contains(q);
    }).toList();
  }

  List<PropertyApi> _propsOf(UserApi u) =>
      _allProps.where((p) => p.ownerId == u.id).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        backgroundColor: context.kCard,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: context.kText, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('إدارة الملاك (${_filtered.length})',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: context.kText)),
        centerTitle: true,
      ),
      body: Column(children: [
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() => _applyFilter()),
            style: TextStyle(fontSize: 14, color: context.kText),
            decoration: InputDecoration(
              hintText: 'بحث بالاسم أو OWN-XXXX...',
              hintStyle: TextStyle(fontSize: 13, color: context.kSub),
              prefixIcon: Icon(Icons.search_rounded, color: context.kSub, size: 20),
              filled: true,
              fillColor: context.kCard,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: context.kBorder)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: context.kBorder)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _kOcean, width: 1.5)),
            ),
          ),
        ),

        // Filter chips
        SizedBox(
          height: 50,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            physics: const BouncingScrollPhysics(),
            itemCount: _filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final f = _filters[i];
              final sel = f == _filter;
              return GestureDetector(
                onTap: () => setState(() {
                  _filter = f;
                  _applyFilter();
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                  decoration: BoxDecoration(
                    color: sel ? _kOcean : context.kCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? _kOcean : context.kBorder),
                  ),
                  child: Text(f,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: sel ? Colors.white : context.kText)),
                ),
              );
            },
          ),
        ),

        // List
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _kOcean))
              : _error != null
                  ? _errorView()
                  : _filtered.isEmpty
                      ? Center(
                          child: Text('لا يوجد ملاك',
                              style: TextStyle(fontSize: 14, color: context.kSub)))
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: _kOcean,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                            physics: const BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics()),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) => _ownerCard(_filtered[i]),
                          ),
                        ),
        ),
      ]),
    );
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: _kRed.withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: context.kText)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(backgroundColor: _kOcean),
            ),
          ]),
        ),
      );

  Widget _ownerCard(UserApi u) {
    final ownerCode = 'OWN-${u.id.toString().padLeft(4, '0')}';
    final count = _propCount[u.id] ?? 0;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminOwnerDetailPage(
              owner: u,
              ownerProperties: _propsOf(u),
            ),
          ),
        ).then((_) => _load());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.kCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.kBorder),
        ),
        child: Row(children: [
          // Avatar
          _avatar(u),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(u.name,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: context.kText),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: (u.isActive ? _kGreen : _kRed).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(u.isActive ? 'مُفعّل' : 'موقوف',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: u.isActive ? _kGreen : _kRed)),
                  ),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: _kOcean.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(ownerCode,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _kOcean,
                            letterSpacing: 0.5)),
                  ),
                  if (u.isVerified) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.verified_rounded,
                        size: 14, color: _kPurple),
                  ],
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.phone_rounded, size: 12, color: context.kSub),
                  const SizedBox(width: 3),
                  Text(u.phone ?? '—',
                      style: TextStyle(fontSize: 11, color: context.kSub)),
                  const Spacer(),
                  Icon(Icons.apartment_rounded, size: 12, color: context.kSub),
                  const SizedBox(width: 3),
                  Text('$count عقار',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: context.kSub)),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.kSub),
        ]),
      ),
    );
  }

  Widget _avatar(UserApi u) {
    final initials = u.name.isNotEmpty
        ? u.name.trim().split(' ').map((w) => w[0]).take(2).join()
        : '?';
    return ClipOval(
      child: SizedBox(
        width: 48,
        height: 48,
        child: u.avatarUrl != null
            ? CachedNetworkImage(
                imageUrl: u.avatarUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => _initialsBox(initials),
                errorWidget: (_, __, ___) => _initialsBox(initials),
              )
            : _initialsBox(initials),
      ),
    );
  }

  Widget _initialsBox(String initials) => Container(
        color: _kOcean.withValues(alpha: 0.15),
        child: Center(
          child: Text(initials,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: _kOcean)),
        ),
      );
}
