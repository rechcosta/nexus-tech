import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_tech/core/models/area.dart';

void main() {
  group('Area.normalizarNome', () {
    test('capitaliza cada palavra', () {
      expect(Area.normalizarNome('desenvolvimento web'), 'Desenvolvimento Web');
    });

    test('força lowercase em palavras gritadas (evita "WEB" vs "Web")', () {
      expect(
        Area.normalizarNome('ENGENHARIA DE SOFTWARE'),
        'Engenharia De Software',
      );
    });

    test('colapsa múltiplos espaços', () {
      expect(
        Area.normalizarNome('Banco   de    Dados'),
        'Banco De Dados',
      );
    });

    test('remove espaços nas pontas', () {
      expect(Area.normalizarNome('  Inteligência Artificial  '),
          'Inteligência Artificial');
    });

    test('string vazia ou só espaços retorna vazio', () {
      expect(Area.normalizarNome(''), '');
      expect(Area.normalizarNome('   '), '');
    });

    test('palavra única é capitalizada', () {
      expect(Area.normalizarNome('flutter'), 'Flutter');
    });
  });

  group('Area.chave (dedup)', () {
    test('chave é lowercase do nome trimado', () {
      final area = Area(
        id: '1',
        nome: 'Desenvolvimento Web',
        criadoEm: DateTime(2025),
        criadoPor: 'uid',
      );
      expect(area.chave, 'desenvolvimento web');
    });
  });
}
