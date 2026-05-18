import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_tech/core/models/demanda.dart';

void main() {
  group('StatusDemanda — transições do demandante', () {
    test('apenas "cadastrada" permite edição pelo demandante', () {
      expect(StatusDemanda.cadastrada.podeEditarDemandante, isTrue);
      expect(StatusDemanda.emAnalise.podeEditarDemandante, isFalse);
      expect(StatusDemanda.emProducao.podeEditarDemandante, isFalse);
      expect(StatusDemanda.concluida.podeEditarDemandante, isFalse);
      expect(StatusDemanda.cancelada.podeEditarDemandante, isFalse);
    });

    test('apenas "cadastrada" permite cancelamento pelo demandante', () {
      expect(StatusDemanda.cadastrada.podeCancelarDemandante, isTrue);
      expect(StatusDemanda.emAnalise.podeCancelarDemandante, isFalse);
      expect(StatusDemanda.emProducao.podeCancelarDemandante, isFalse);
      expect(StatusDemanda.concluida.podeCancelarDemandante, isFalse);
      expect(StatusDemanda.cancelada.podeCancelarDemandante, isFalse);
    });
  });

  group('StatusDemanda — labels exibidos', () {
    test('cada status tem label não-vazio e único', () {
      final labels = StatusDemanda.values.map((s) => s.label).toList();
      expect(labels.toSet().length, equals(labels.length),
          reason: 'labels duplicados quebrariam diferenciação visual');
      expect(labels.every((l) => l.isNotEmpty), isTrue);
    });
  });

  group('FiltroPeriodo.range', () {
    test('ultimos7Dias retorna início ~7 dias atrás, fim nulo', () {
      final range = FiltroPeriodo.ultimos7Dias.range;
      expect(range.fim, isNull);
      expect(range.inicio, isNotNull);
      final diff = DateTime.now().difference(range.inicio!);
      expect(diff.inDays, equals(7));
    });

    test('todasApos30Dias inverte: fim ~30 dias atrás, início nulo', () {
      final range = FiltroPeriodo.todasApos30Dias.range;
      expect(range.inicio, isNull);
      expect(range.fim, isNotNull);
      final diff = DateTime.now().difference(range.fim!);
      expect(diff.inDays, equals(30));
    });
  });
}
