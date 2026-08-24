import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:notably/core/sync/supabase_store.dart';

void main() {
  group('bytea encoding', () {
    // A Uint8List in a JSON body encodes as an array of integers, and Postgres
    // accepts the text "[1,2,3]" as escape-format bytea without complaining —
    // storing the digits instead of the ink. Every page then decoded to zero
    // strokes on every other device. Only the \x form survives the round trip.
    test('renders a Postgres hex literal, not a JSON array', () {
      expect(
        SupabaseStore.encodeBytea(Uint8List.fromList([0, 1, 15, 16, 255])),
        r'\x00010f10ff',
      );
    });

    test('an empty blob is the empty literal', () {
      expect(SupabaseStore.encodeBytea(Uint8List(0)), r'\x');
      expect(SupabaseStore.kEmptyBytea, r'\x');
    });

    test('every byte value round-trips through the hex form', () {
      final bytes = Uint8List.fromList(List.generate(256, (i) => i));
      final encoded = SupabaseStore.encodeBytea(bytes);
      expect(encoded.startsWith(r'\x'), isTrue);
      expect(encoded.length, 2 + bytes.length * 2);

      final hex = encoded.substring(2);
      final decoded = Uint8List(hex.length ~/ 2);
      for (var i = 0; i < decoded.length; i++) {
        decoded[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
      }
      expect(decoded, bytes);
    });
  });
}
