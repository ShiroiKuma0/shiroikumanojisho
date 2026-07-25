import 'dart:typed_data';

/// Small, self-contained bloom filter over dictionary term strings.
///
/// Purpose
/// -------
/// Dictionary search is dominated by per-dictionary term-index queries.
/// For users with many dictionaries (50+) across many languages, most
/// of those per-dict queries miss: the term simply isn't in that
/// dictionary. A bloom filter lets the search pipeline answer
/// "dictionary X definitely does not contain term T" in a few hundred
/// nanoseconds, skipping the Isar call entirely.
///
/// Encoding
/// --------
/// - Two independent FNV-1a 64-bit hashes of the lowercased term, one
///   from the normal direction and one from the reverse direction.
/// - k = 7 hash functions derived by double-hashing `h1 + i * h2 mod m`.
/// - m = nextPowerOfTwo(max(64, bitsPerEntry * n)) bits.
/// - Payload format (stored as `List<byte>` on `Dictionary`):
///     byte 0       : magic 'b' (0x62)
///     byte 1       : version (0x01)
///     bytes 2..9   : u64 little-endian m (number of bits)
///     bytes 10..   : bitset of length (m/8) bytes
///
/// Why this specific design
/// ------------------------
/// - FNV-1a gives a stable, platform-independent, allocation-free hash
///   with decent distribution for short ASCII/UTF-8 strings. We avoid
///   Dart's `String.hashCode` because it is not guaranteed stable
///   across Dart versions or isolates, which would break bloom filters
///   persisted across app updates.
/// - Double-hashing two independent 64-bit hashes gives us k=7
///   effectively-independent hash functions very cheaply (one multiply
///   + one add + one mask per hash).
/// - 10 bits per entry and k=7 yields ~1% false-positive rate, which
///   is more than enough — a false positive just costs us the Isar
///   query we were already willing to do. False NEGATIVES (which
///   bloom filters forbid by construction) would be catastrophic; we
///   avoid them by correct double-hashing.
///
/// Usage
/// -----
/// - At import time, call [TermBloom.build] with all terms in the
///   dictionary, then store the returned `List<int>` on the
///   `Dictionary.bloomBits` field.
/// - At search time, construct a [TermBloom] from those bytes once and
///   reuse it across queries. Call [TermBloom.mayContain] before
///   hitting Isar; skip the query if it returns false.
class TermBloom {

  TermBloom._(this.m, this._bits);
  /// Construct a filter from previously-serialised bytes. Returns null
  /// if the bytes are empty, malformed, or came from an unsupported
  /// version (in which case callers should fall back to "always
  /// query").
  static TermBloom? fromBytes(List<int> bytes) {
    if (bytes.length < 10) return null;
    if (bytes[0] != _magic || bytes[1] != _version) return null;
    final header = ByteData.sublistView(Uint8List.fromList(bytes), 2, 10);
    final m = header.getUint64(0, Endian.little);
    if (m == 0 || m > _maxBits) return null;
    final expectedBitBytes = (m + 7) >> 3;
    if (bytes.length - 10 < expectedBitBytes) return null;
    final bits = Uint8List.fromList(
        bytes.sublist(10, 10 + expectedBitBytes));
    return TermBloom._(m, bits);
  }

  /// Build a fresh filter over the provided terms.
  ///
  /// `bitsPerEntry` defaults to 10 (about 1% false-positive at k=7).
  /// Increase for fewer false positives; decrease to save memory.
  /// The minimum filter size is 64 bits; empty term lists still
  /// produce a valid (all-zero) bloom filter.
  static TermBloom build(Iterable<String> terms, {int bitsPerEntry = 10}) {
    int n = 0;
    for (final _ in terms) {
      n++;
    }
    final desired = (n * bitsPerEntry).clamp(64, _maxBits);
    final m = _nextPowerOfTwo(desired);
    final bits = Uint8List((m + 7) >> 3);
    final bloom = TermBloom._(m, bits);
    for (final term in terms) {
      bloom._add(term);
    }
    return bloom;
  }

  /// Number of bits in the filter (power of two).
  final int m;

  /// Backing bitset. `(m + 7) >> 3` bytes.
  final Uint8List _bits;

  /// True if `term` *may* be in the set. A true return is
  /// probabilistic; a false return is a hard negative.
  bool mayContain(String term) {
    final mask = m - 1; // m is a power of two.
    final h1 = _fnv1a64(term);
    final h2 = _fnv1a64Reverse(term);
    int h = h1 & mask;
    for (int i = 0; i < _k; i++) {
      if (_bits[h >> 3] & (1 << (h & 7)) == 0) return false;
      h = (h + h2) & mask;
    }
    return true;
  }

  /// Serialise to the canonical byte layout documented on the class.
  /// Callers persist the returned list on `Dictionary.bloomBits`.
  List<int> toBytes() {
    final out = Uint8List(10 + _bits.length);
    out[0] = _magic;
    out[1] = _version;
    final header = ByteData.sublistView(out, 2, 10);
    header.setUint64(0, m, Endian.little);
    out.setRange(10, 10 + _bits.length, _bits);
    return out;
  }

  void _add(String term) {
    final mask = m - 1;
    final h1 = _fnv1a64(term);
    final h2 = _fnv1a64Reverse(term);
    int h = h1 & mask;
    for (int i = 0; i < _k; i++) {
      _bits[h >> 3] |= 1 << (h & 7);
      h = (h + h2) & mask;
    }
  }

  // --- Constants ---

  /// Number of hash functions. k=7 ≈ optimal for 10 bits/entry.
  static const int _k = 7;

  /// Magic byte — 'b' for bloom — to distinguish from legacy empty
  /// fields and catch corruption.
  static const int _magic = 0x62;

  /// On-disk format version. Bump if the algorithm changes such that
  /// older serialisations can no longer be read correctly.
  static const int _version = 0x01;

  /// Hard cap on filter size: 512 Mbit = 64 MB per dictionary. Well
  /// above any conceivable need; prevents pathological allocation.
  static const int _maxBits = 1 << 29;

  // --- Hash helpers ---

  /// 64-bit FNV-1a hash over the UTF-16 code units of [s] (lower-cased
  /// for ASCII A–Z). Stable across platforms because the offset basis
  /// and prime are hardcoded and we rely only on Dart's fixed-width
  /// integer arithmetic semantics.
  static int _fnv1a64(String s) {
    int h = _fnvOffsetBasis;
    for (int i = 0; i < s.length; i++) {
      int c = s.codeUnitAt(i);
      if (c >= 0x41 && c <= 0x5A) c += 0x20; // A-Z -> a-z
      h = (h ^ c) * _fnvPrime;
      h &= 0xFFFFFFFFFFFFFFFF; // Dart's ints are 64-bit on VMs; belt-and-braces.
    }
    return h;
  }

  /// Second, independent hash: FNV-1a over the reversed code-unit
  /// sequence. Because FNV-1a is order-sensitive the reverse pass
  /// produces a statistically uncorrelated 64-bit value for normal
  /// inputs, letting us use simple double-hashing for k derived
  /// hashes.
  static int _fnv1a64Reverse(String s) {
    int h = _fnvOffsetBasis;
    for (int i = s.length - 1; i >= 0; i--) {
      int c = s.codeUnitAt(i);
      if (c >= 0x41 && c <= 0x5A) c += 0x20;
      h = (h ^ c) * _fnvPrime;
      h &= 0xFFFFFFFFFFFFFFFF;
    }
    // Ensure h2 is odd so `h1 + i * h2 mod 2^k` enumerates all residues.
    return h | 1;
  }

  /// FNV-1a 64-bit offset basis (constants from the FNV spec).
  static const int _fnvOffsetBasis = 0xcbf29ce484222325;

  /// FNV-1a 64-bit prime.
  static const int _fnvPrime = 0x100000001b3;

  static int _nextPowerOfTwo(int n) {
    if (n <= 0) return 1;
    int v = n - 1;
    v |= v >> 1;
    v |= v >> 2;
    v |= v >> 4;
    v |= v >> 8;
    v |= v >> 16;
    v |= v >> 32;
    return v + 1;
  }
}
