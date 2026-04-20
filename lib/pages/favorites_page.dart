// ═══════════════════════════════════════════════════════════════
//  TALAA — Favorites Page
//  Shows the user's saved/favorited properties in a list.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../main.dart' show favoritesProvider;
import '../models/property_model_api.dart';
import '../services/favorites_service.dart';
import '../widgets/constants.dart';
import '../widgets/favorite_button.dart';
import 'property_details_page.dart';

const _kOcean  = Color(0xFF1565C0);
const _kOrange = Color(0xFFFF6D00);

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  bool _loading = true;
  String? _error;
  List<PropertyApi> _items = [];

  @override
  void initState() {
    super.initState();
    favoritesProvider.addListener(_onFavChange);
    _load();
  }

  @override
  void dispose() {
    favoritesProvider.removeListener(_onFavChange);
    super.dispose();
  }

  void _onFavChange() {
    if (!mounted) return;
    // Drop items no longer in the provider set (instant UI feedback after
    // un-favoriting from this page without another network call).
    final keepIds = favoritesProvider.ids;
    final filtered = _items.where((p) => keepIds.contains(p.id)).toList();
    if (filtered.length != _items.length) {
      setState(() => _items = filtered);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await FavoritesService.getFavorites();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل المفضلة';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        backgroundColor: _kOcean,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'المفضلة',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        color: _kOcean,
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _kOcean));
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(child: Icon(Icons.wifi_off_rounded,
              size: 64, color: context.kSub)),
          const SizedBox(height: 12),
          Center(
            child: Text(_error!,
                style: TextStyle(fontSize: 15, color: context.kSub)),
          ),
          const SizedBox(height: 12),
          Center(
            child: ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kOcean,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(child: Icon(Icons.favorite_border_rounded,
              size: 72, color: context.kSub)),
          const SizedBox(height: 16),
          Center(
            child: Text('لم تُضف أي عقار للمفضلة بعد',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.kText)),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text('اضغط على القلب لإضافة العقارات التي تعجبك',
                style: TextStyle(fontSize: 13, color: context.kSub)),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _items.length,
      itemBuilder: (_, i) => _card(_items[i]),
    );
  }

  // ── Card ────────────────────────────────────────────────────
  Widget _card(PropertyApi p) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PropertyDetailsPage(propertyApi: p)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: context.kCard,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 14,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            child: SizedBox(
              height: 150,
              child: Stack(fit: StackFit.expand, children: [
                p.firstImage.isNotEmpty
                    ? Image.network(p.firstImage,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(p))
                    : _placeholder(p),
                PositionedDirectional(
                  top: 10,
                  end: 10,
                  child: FavoriteButton(
                    propertyId: p.id,
                    size: 17,
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: context.kText)),
                  ),
                  if (p.rating > 0) ...[
                    const Icon(Icons.star_rounded,
                        color: Colors.amber, size: 18),
                    const SizedBox(width: 2),
                    Text(p.rating.toStringAsFixed(1),
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.kText)),
                  ],
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.location_on_rounded,
                      size: 14, color: context.kSub),
                  const SizedBox(width: 3),
                  Text(p.area,
                      style:
                          TextStyle(fontSize: 12, color: context.kSub)),
                  const Spacer(),
                  Text('${p.pricePerNight.toStringAsFixed(0)} ج.م',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _kOrange)),
                  Text(' /ليلة',
                      style:
                          TextStyle(fontSize: 11, color: context.kSub)),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _placeholder(PropertyApi p) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [p.areaColor, p.areaColor.withValues(alpha: 0.55)],
          ),
        ),
        child: Center(
          child: Text(p.categoryEmoji,
              style: const TextStyle(fontSize: 60)),
        ),
      );
}
