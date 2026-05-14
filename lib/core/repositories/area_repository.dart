import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/app_constants.dart';
import '../exceptions/firestore_error_handler.dart';
import '../models/area.dart';

enum TipoArea { tecnica, interesse }

class AreaRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _colecao(TipoArea tipo) =>
      _firestore.collection(switch (tipo) {
        TipoArea.tecnica => AppConstants.collectionAreasTecnicas,
        TipoArea.interesse => AppConstants.collectionAreasInteresse,
      });

  Future<List<Area>> listar(TipoArea tipo) async {
    try {
      final snapshot = await _colecao(tipo).orderBy('nome').get();
      return snapshot.docs
          .map((doc) => Area.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      throw mapFirestoreError(e, recurso: 'Áreas');
    }
  }

  /// Cria nova área se não existir (deduplicação por chave normalizada).
  /// * Otimização: usa query indexada em vez de carregar lista inteira.
  Future<Area> criarSeNaoExiste({
    required TipoArea tipo,
    required String nomeBruto,
    required String criadoPorUid,
  }) async {
    final nomeNormalizado = Area.normalizarNome(nomeBruto);
    if (nomeNormalizado.isEmpty) {
      throw ArgumentError('Nome da área não pode ser vazio');
    }

    final chave = nomeNormalizado.toLowerCase();

    try {
      // Query indexada: busca apenas o documento com a chave igual.
      // Não carrega lista inteira.
      final query =
          await _colecao(tipo).where('chave', isEqualTo: chave).limit(1).get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        return Area.fromMap(doc.id, doc.data());
      }

      // Não existe — cria novo documento
      final novaArea = Area(
        id: '',
        nome: nomeNormalizado,
        criadoEm: DateTime.now(),
        criadoPor: criadoPorUid,
      );

      final docRef = await _colecao(tipo).add({
        ...novaArea.toMap(),
        'chave': chave, // necessário pra query de duplicata
      });

      return Area(
        id: docRef.id,
        nome: novaArea.nome,
        criadoEm: novaArea.criadoEm,
        criadoPor: novaArea.criadoPor,
      );
    } catch (e) {
      if (e is ArgumentError) rethrow;
      throw mapFirestoreError(e, recurso: 'Área');
    }
  }
}
