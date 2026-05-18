// ═══════════════════════════════════════════════════════════════
//  TALAA — Chat Sanitizer (client mirror)
//
//  Detect *attempts* to exchange contact info — phone numbers,
//  emails, social-media handles — before they leave the device.
//  Mirrors the backend ``chat_sanitizer.py`` so the warning banner
//  surfaces the same intent the server moderation will flag.
//
//  Detection layers (first match wins):
//
//    1. Arabic-Indic / Eastern-Arabic digits → ASCII.
//    2. Spelled-out digits in Arabic / English collapsed to digits
//       when ≥ 3 consecutive number-words appear.
//    3. Homoglyphs (O→0, l/I→1, S→5, B→8, Z→2) replaced ONLY inside
//       alphanumeric chunks that already contain ≥ 2 ASCII digits
//       (so we don't mangle normal words).
//    4. Connector characters between digits collapsed so
//       ``010 - 1234 - 5678`` becomes one contiguous run.
//    5. Any digit run of ≥ 6 chars is treated as a phone-like leak.
//    6. ``@handle`` mentions near a social-network keyword count
//       (whatsapp, telegram, instagram, snapchat, tiktok…).
//    7. Curated indirect phrases like "ابعتلى رقمك" / "send me your
//       number" trigger the same warning even when no digits exist.
//
//  The server still owns the final ``is_flagged`` decision and the
//  redaction; the client check is purely a UX guard so users don't
//  waste a round-trip on a message that won't make it through.
// ═══════════════════════════════════════════════════════════════

class ChatSanitizer {
  ChatSanitizer._();

  // ── Digit normalisation ────────────────────────────────
  // Arabic-Indic (U+0660..0669) + Extended Arabic-Indic
  // (U+06F0..06F9) → ASCII digits.
  static String _normaliseDigits(String text) {
    final buf = StringBuffer();
    for (final r in text.runes) {
      if (r >= 0x0660 && r <= 0x0669) {
        buf.writeCharCode(0x30 + (r - 0x0660));
      } else if (r >= 0x06F0 && r <= 0x06F9) {
        buf.writeCharCode(0x30 + (r - 0x06F0));
      } else {
        buf.writeCharCode(r);
      }
    }
    return buf.toString();
  }

  // ── Spelled-out digit lexicon ──────────────────────────
  static const Map<String, String> _numberWords = {
    // Arabic — formal
    'صفر': '0',
    'واحد': '1', 'واحدة': '1',
    'اثنان': '2', 'إثنان': '2', 'اثنين': '2', 'إثنين': '2',
    'ثلاثة': '3', 'ثلاث': '3',
    'أربعة': '4', 'اربعة': '4', 'أربع': '4', 'اربع': '4',
    'خمسة': '5', 'خمس': '5',
    'ستة': '6', 'ست': '6',
    'سبعة': '7', 'سبع': '7',
    'ثمانية': '8', 'ثماني': '8',
    'تسعة': '9', 'تسع': '9',
    // Arabic — colloquial Egyptian
    'اتنين': '2', 'إتنين': '2',
    'تلاتة': '3', 'تلات': '3',
    'تمنية': '8', 'تمانية': '8',
    // English
    'zero': '0', 'naught': '0', 'nought': '0', 'oh': '0',
    'one': '1',
    'two': '2',
    'three': '3',
    'four': '4',
    'five': '5',
    'six': '6',
    'seven': '7',
    'eight': '8',
    'nine': '9',
  };

  static const int _minSpelledRun = 3;

  // ASCII letters + Arabic letters (U+0600..U+06FF) + ASCII digits.
  static final RegExp _token = RegExp(
    r'[A-Za-z\u0600-\u06FF\d]+|[^A-Za-z\u0600-\u06FF\d]+',
  );

  // ── Homoglyph rescue ──────────────────────────────────
  static const Map<String, String> _homoglyph = {
    'O': '0', 'o': '0',
    'I': '1', 'l': '1',
    'S': '5', 's': '5',
    'B': '8',
    'Z': '2', 'z': '2',
  };
  static final RegExp _alnumRun = RegExp(r'[A-Za-z\d]{3,}');
  static final RegExp _hasTwoDigits = RegExp(r'\d.*\d');

  // ── Connector / digit run regexes ─────────────────────
  static final RegExp _connectorSplit = RegExp(
    r'(?<=\d)[\s\-.·•/_\\|\u200c\u200d\u200e\u200f]+(?=\d)',
  );
  static final RegExp _digitRun = RegExp(r'\d{6,}');
  static final RegExp _email = RegExp(r'\S+@\S+\.\S+');
  static final RegExp _atHandle = RegExp(r'@[A-Za-z0-9_.]{3,}');

  // ── Social platform keywords (lowercase) ──────────────
  static const List<String> _socialKeywords = [
    // English
    'whatsapp', 'whats', 'telegram', 'tg',
    'instagram', 'insta', 'ig',
    'snapchat', 'snap',
    'tiktok', 'tik tok',
    'signal', 'viber', 'imo', 'wechat', 'line',
    'facebook', 'fb', 'messenger',
    'discord', 'twitter',
    // Arabic
    'واتس', 'واتساب', 'واتس آب',
    'تلجرام', 'تليجرام', 'تيليجرام',
    'انستا', 'إنستا', 'انستجرام', 'إنستجرام', 'انستغرام',
    'سناب',
    'تيك توك', 'تيكتوك',
    'فيس', 'فيسبوك', 'ماسنجر',
    'ديسكورد', 'تويتر',
    'ايمو', 'إيمو',
  ];

  // ── Indirect contact-request phrases ──────────────────
  static const List<String> _contactRequestPhrases = [
    // Arabic
    'ابعتلي رقم', 'ابعتلى رقم', 'ابعتلي نمرت', 'ابعتلى نمرت',
    'ابعتلي تليفون', 'ابعتلى تليفون',
    'اديني رقم', 'ادينى رقم', 'اديني نمرت', 'ادينى نمرت',
    'ادينى تليفون', 'اديني تليفون',
    'هتبعت رقم', 'هبعتلك رقم', 'هبعت رقم',
    'خد رقمي', 'خد رقمى', 'خدي رقمي', 'خدى رقمى',
    'كلمني على', 'كلمنى على', 'اتصل بيا', 'اتصل بى',
    'كلمني واتس', 'كلمنى واتس',
    'رقمي يبدأ', 'رقمى يبدأ', 'نمرتي تبدأ', 'نمرتى تبدا',
    'ابعت رقمك', 'ابعتلي تليجرام', 'ابعتلي انستا',
    // English
    'send me your number', 'give me your number',
    'your phone number', 'your whatsapp', 'your telegram',
    'text me on', 'call me on', 'dm me on',
    'my number is', 'my number starts',
    'reach me on', 'contact me on',
  ];

  // ── Pipeline ──────────────────────────────────────────

  static String _foldSpelledDigits(String text) {
    final matches = _token.allMatches(text).toList();
    if (matches.isEmpty) return text;

    final out = StringBuffer();
    // Pairs of (digit, originalToken) plus the separators between them.
    final buf = <List<String>>[]; // [digit, original]
    final sepBuf = <String>[];
    String pendingSep = '';

    void flushBuf(String trailingSep) {
      if (buf.length >= _minSpelledRun) {
        // Collapse to one contiguous digit run, drop in-run seps.
        for (final entry in buf) {
          out.write(entry[0]);
        }
      } else {
        // Restore the original tokens verbatim.
        for (var i = 0; i < buf.length; i++) {
          out.write(buf[i][1]);
          if (i < sepBuf.length) out.write(sepBuf[i]);
        }
      }
      buf.clear();
      sepBuf.clear();
      if (trailingSep.isNotEmpty) out.write(trailingSep);
    }

    bool isFirstWordChar(int cu) {
      // ASCII letter
      if ((cu >= 0x41 && cu <= 0x5A) || (cu >= 0x61 && cu <= 0x7A)) return true;
      // Arabic block
      if (cu >= 0x0600 && cu <= 0x06FF) return true;
      return false;
    }

    bool isFirstDigit(int cu) => cu >= 0x30 && cu <= 0x39;

    for (final m in matches) {
      final tok = m.group(0)!;
      if (tok.isEmpty) continue;
      final firstCu = tok.codeUnitAt(0);
      if (isFirstWordChar(firstCu)) {
        final digit = _numberWords[tok.toLowerCase()];
        if (digit != null) {
          if (pendingSep.isNotEmpty && buf.isNotEmpty) {
            sepBuf.add(pendingSep);
          }
          buf.add([digit, tok]);
          pendingSep = '';
        } else {
          // Non-number word breaks the run.
          flushBuf(pendingSep);
          out.write(tok);
          pendingSep = '';
        }
      } else if (isFirstDigit(firstCu)) {
        if (pendingSep.isNotEmpty && buf.isNotEmpty) {
          sepBuf.add(pendingSep);
        }
        buf.add([tok, tok]);
        pendingSep = '';
      } else {
        pendingSep += tok;
      }
    }
    flushBuf(pendingSep);
    return out.toString();
  }

  static String _applyHomoglyphs(String text) {
    return text.replaceAllMapped(_alnumRun, (m) {
      final chunk = m.group(0)!;
      if (!_hasTwoDigits.hasMatch(chunk)) return chunk;
      final b = StringBuffer();
      for (var i = 0; i < chunk.length; i++) {
        final c = chunk[i];
        b.write(_homoglyph[c] ?? c);
      }
      return b.toString();
    });
  }

  static String _normalise(String text) {
    var cleaned = _normaliseDigits(text);
    cleaned = _foldSpelledDigits(cleaned);
    cleaned = _applyHomoglyphs(cleaned);
    cleaned = cleaned.replaceAll(_connectorSplit, '');
    return cleaned;
  }

  /// Returns ``true`` if the message looks like it tries to share a
  /// phone, email, or social-media handle — directly or via any of
  /// the obfuscation tricks the sanitizer knows about.
  static bool looksLikeContactExchange(String text) {
    if (text.isEmpty) return false;
    final norm = _normalise(text);
    if (_digitRun.hasMatch(norm)) return true;
    if (_email.hasMatch(text)) return true;
    final lower = text.toLowerCase();
    if (text.contains('@') &&
        _socialKeywords.any(lower.contains) &&
        _atHandle.hasMatch(text)) {
      return true;
    }
    if (_contactRequestPhrases.any(lower.contains)) return true;
    return false;
  }
}
