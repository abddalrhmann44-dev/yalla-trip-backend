// ═══════════════════════════════════════════════════════════════
//  TALAA — Listing Service (Firestore legacy)
//  For new backend API, use PropertyService in property_service.dart
//  Region-based filtering + Time-limited offer management
// ═══════════════════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/property_model.dart';

class ListingService {
  ListingService._();
  static final instance = ListingService._();

  final _db = FirebaseFirestore.instance;

  // ── Supported regions (Arabic — matches `area` field) ─────────
  static const List<String> regions = [
    'عين السخنة',
    'الجونة',
    'الساحل الشمالي',
    'شرم الشيخ',
    'الغردقة',
    'رأس سدر',
  ];

  static const Map<String, String> regionToEnglish = {
    'عين السخنة':     'Ain Sokhna',
    'الجونة':         'El Gouna',
    'الساحل الشمالي': 'North Coast',
    'شرم الشيخ':      'Sharm El Sheikh',
    'الغردقة':        'Hurghada',
    'رأس سدر':        'Ras Sedr',
  };

  // ── Stream: region listings (excludes currently active offers) ─
  //
  // A listing appears in its region page ONLY when it does NOT have
  // a currently active time-limited offer.  If an offer is set but
  // has already expired we still show it in the region page.
  Stream<List<PropertyModel>> streamRegionListings(String region) {
    return _db
        .collection('properties')
        .where('area',      isEqualTo: region)
        .where('available', isEqualTo: true)
        .snapshots()
        .map((snap) {
          final now = DateTime.now();
          return snap.docs
              .map((d) => PropertyModel.fromFirestore(d.id, d.data()))
              .where((p) {
                if (!p.isOfferActive) return true;
                if (p.offerEnd == null)  return true;
                return p.offerEnd!.isBefore(now); // expired → back in region
              })
              .toList();
        });
  }

  // ── Stream: home-page active offers only ──────────────────────
  //
  // Fetches properties with isOfferActive=true then validates that
  // the current time actually falls within [offerStart, offerEnd].
  Stream<List<PropertyModel>> streamActiveOffers() {
    return _db
        .collection('properties')
        .where('isOfferActive', isEqualTo: true)
        .snapshots()
        .map((snap) {
          final now = DateTime.now();
          return snap.docs
              .map((d) => PropertyModel.fromFirestore(d.id, d.data()))
              .where((p) {
                if (p.offerStart == null || p.offerEnd == null) return false;
                return p.offerStart!.isBefore(now) &&
                    p.offerEnd!.isAfter(now);
              })
              .toList();
        });
  }

  // ── Get owner's properties (for offer creation UI) ────────────
  Future<List<PropertyModel>> getOwnerProperties() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];
    final snap = await _db
        .collection('properties')
        .where('ownerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs
        .map((d) => PropertyModel.fromFirestore(d.id, d.data()))
        .toList();
  }

  // ── Create / update a time-limited offer ─────────────────────
  Future<void> setOffer({
    required String propertyId,
    required double offerPrice,
    required DateTime offerStart,
    required DateTime offerEnd,
  }) async {
    await _db.collection('properties').doc(propertyId).update({
      'isOfferActive': true,
      'offerPrice':    offerPrice,
      'offerStart':    Timestamp.fromDate(offerStart),
      'offerEnd':      Timestamp.fromDate(offerEnd),
      'updatedAt':     FieldValue.serverTimestamp(),
    });
  }

  // ── Cancel / remove an offer ──────────────────────────────────
  Future<void> cancelOffer(String propertyId) async {
    await _db.collection('properties').doc(propertyId).update({
      'isOfferActive': false,
      'offerPrice':    FieldValue.delete(),
      'offerStart':    FieldValue.delete(),
      'offerEnd':      FieldValue.delete(),
      'updatedAt':     FieldValue.serverTimestamp(),
    });
  }

  // ── Auto-expire stale offers for the logged-in owner ─────────
  //
  // Call this when the owner opens the offer-management page so
  // expired offers are cleaned up in Firestore immediately.
  Future<void> expireStaleOffers() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final now = DateTime.now();
      final snap = await _db
          .collection('properties')
          .where('ownerId',      isEqualTo: uid)
          .where('isOfferActive', isEqualTo: true)
          .get();
      final batch = _db.batch();
      bool dirty = false;
      for (final doc in snap.docs) {
        final endTs = doc.data()['offerEnd'] as Timestamp?;
        if (endTs != null && endTs.toDate().isBefore(now)) {
          batch.update(doc.reference, {
            'isOfferActive': false,
            'offerPrice':    FieldValue.delete(),
            'offerStart':    FieldValue.delete(),
            'offerEnd':      FieldValue.delete(),
          });
          dirty = true;
        }
      }
      if (dirty) await batch.commit();
    } catch (_) {}
  }
}
