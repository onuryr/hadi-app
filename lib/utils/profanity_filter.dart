/// Lightweight client-side profanity / spam filter for chat messages.
///
/// Defense-in-depth only — server-side trigger is the source of truth.
/// This catches casual abuse before the network round-trip and gives
/// the user a clearer error than the trigger's generic rejection.

class ProfanityFilter {
  // Lowercased word stems. Match is whole-word (\b<word>\b) on
  // alpha-collapsed text so "s.i.k.t.i.r" / "s1kt1r" / "siktiiir"
  // don't trivially bypass.
  static const Set<String> _badStems = {
    // Turkish — most common offensive stems
    'sik', 'sikt', 'sike', 'sikim', 'sikis', 'sikiş',
    'amk', 'aq', 'amq', 'mk', 'mq',
    'orospu', 'ouspu',
    'piç', 'pic',
    'göt', 'got',
    'yarrak', 'yarak',
    'ananı', 'ananin', 'ananın',
    'amına', 'amina', 'amın', 'amin',
    'salak', 'aptal', 'gerizekalı', 'gerizekali',
    'ibne', 'puşt', 'pust',
    'kahpe', 'kaltak',
    // English — common
    'fuck', 'fck', 'shit', 'sht', 'bitch', 'asshole',
    'cunt', 'dick', 'pussy', 'whore', 'slut', 'faggot',
    // Spam patterns
    'http://', 'https://', 'www.', 't.me/', 'wa.me/',
  };

  /// Returns true if [text] looks like profanity / spam.
  static bool isProfane(String text) {
    final normalized = _normalize(text);
    if (normalized.isEmpty) return false;
    for (final stem in _badStems) {
      // Direct substring for URLs / handles, word-boundary for words
      if (stem.contains('/') || stem.contains('.')) {
        if (normalized.toLowerCase().contains(stem)) return true;
      } else {
        final pattern = RegExp('\\b${RegExp.escape(stem)}\\b', caseSensitive: false);
        if (pattern.hasMatch(normalized)) return true;
      }
    }
    return false;
  }

  /// Collapses repeated letters and number-letter substitutions
  /// ("siiik" → "sik", "s1k" → "sik") to make trivial leet bypass harder.
  static String _normalize(String text) {
    final lower = text.toLowerCase();
    final swapped = lower
        .replaceAll('1', 'i')
        .replaceAll('0', 'o')
        .replaceAll('3', 'e')
        .replaceAll('4', 'a')
        .replaceAll('5', 's')
        .replaceAll('@', 'a')
        .replaceAll('\$', 's');
    // Collapse 3+ repeated chars to 2 ("siiiik" → "siik" → "sik" via stem match later)
    final collapsed = swapped.replaceAllMapped(
      RegExp(r'(.)\1{2,}'),
      (m) => m.group(1)!,
    );
    return collapsed;
  }
}
