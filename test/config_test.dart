import 'package:flutter_test/flutter_test.dart';
import 'package:oyun_hava_hokeyi/oyun_hava_hokeyi.dart';

void main() {
  test('33 dilde ad, slogan, anlatım ve eğitim var', () {
    expect(havaHokeyiConfig.gameId, 'oyun-hava-hokeyi');
    expect(havaHokeyiConfig.title.length, 33);
    expect(havaHokeyiConfig.tagline.length, 33);
    for (final s in havaHokeyiConfig.tutorial) {
      expect(s.text.length, 33);
      expect(s.text.every((t) => t.trim().isNotEmpty), isTrue);
    }
  });
}
