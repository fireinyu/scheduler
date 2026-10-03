import 'dart:math';

class MatchResult<T> {
  final T item;
  final String label;
  final double score;

  const MatchResult({
    required this.item,
    required this.label,
    required this.score,
  });
}

class FuzzySearch {
  /// Computes a match closeness score between candidate string and query.
  /// Higher score indicates a closer match. Returns 0.0 if not matched.
  static double score(String candidate, String query) {
    final cand = candidate.trim().toLowerCase();
    final q = query.trim().toLowerCase();

    if (q.isEmpty) return 1.0;
    if (cand.isEmpty) return 0.0;

    // 1. Exact match (highest priority)
    if (cand == q) return 1000.0;

    // 2. Starts with query (prefix match)
    if (cand.startsWith(q)) {
      return 500.0 + (100.0 - (cand.length - q.length).clamp(0, 100));
    }

    // 3. Any individual word in candidate starts with query
    final words = cand.split(RegExp(r'[\s\-_\.,/]+'));
    for (final word in words) {
      if (word.startsWith(q)) {
        return 350.0 + (50.0 - (word.length - q.length).clamp(0, 50));
      }
    }

    // 4. Substring match anywhere in candidate
    final subIndex = cand.indexOf(q);
    if (subIndex != -1) {
      return 200.0 - subIndex.clamp(0, 100);
    }

    // 5. Subsequence match (all query characters appear in candidate in order)
    int qIdx = 0;
    int firstMatch = -1;
    int lastMatch = -1;
    for (int i = 0; i < cand.length && qIdx < q.length; i++) {
      if (cand[i] == q[qIdx]) {
        if (firstMatch == -1) firstMatch = i;
        lastMatch = i;
        qIdx++;
      }
    }

    if (qIdx == q.length) {
      final span = lastMatch - firstMatch + 1;
      return 120.0 - (span - q.length).clamp(0, 80);
    }

    // 6. Typo tolerance: Levenshtein edit distance similarity
    final distance = _levenshteinDistance(cand, q);
    final maxLen = max(cand.length, q.length);
    final similarity = 1.0 - (distance / maxLen);

    // If similarity is at least 0.45 or distance <= 2 for queries of length >= 3
    if (similarity >= 0.45 || (q.length >= 3 && distance <= 2)) {
      return similarity * 100.0;
    }

    return 0.0;
  }

  /// Filters candidates and ranks them so closest matches appear first.
  static List<T> filterAndRank<T>({
    required List<T> items,
    required String Function(T) getName,
    required String query,
  }) {
    if (query.trim().isEmpty) return List<T>.from(items);

    final scored = <MatchResult<T>>[];
    for (final item in items) {
      final name = getName(item);
      final s = score(name, query);
      if (s > 0) {
        scored.add(MatchResult(item: item, label: name, score: s));
      }
    }

    // Sort descending: closest matches first
    scored.sort((a, b) => b.score.compareTo(a.score));

    return scored.map((m) => m.item).toList();
  }

  static int _levenshteinDistance(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        final cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
      }
      for (int j = 0; j < t.length + 1; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[t.length];
  }
}
