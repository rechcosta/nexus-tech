import 'package:cloud_firestore/cloud_firestore.dart';

import '../exceptions/firestore_error_handler.dart';
import '../models/anexo.dart';
import '../models/demanda.dart';

class DemandaRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _collectionDemandas = 'demandas';
  static const String _subcollectionAnexos = 'anexos';
  static const String _collectionAuditLog = 'audit_logs';

  CollectionReference<Map<String, dynamic>> get _demandas =>
      _firestore.collection(_collectionDemandas);

  CollectionReference<Map<String, dynamic>> _anexos(String demandaId) =>
      _demandas.doc(demandaId).collection(_subcollectionAnexos);

  // ! ===========================
  // ! UC15 - CADASTRAR DEMANDA
  // ! ===========================

  /// Cria nova demanda. Retorna ID gerado pelo Firestore.
  /// Status inicial: cadastrada (UC15 R03).
  Future<String> criar(Demanda demanda) async {
    try {
      final docRef = await _demandas.add(demanda.toMap());

      // UC15 R05: registro em log de auditoria
      await _registrarAuditoria(
        demandaId: docRef.id,
        acao: 'criar',
        autorUid: demanda.demandanteUid,
      );

      return docRef.id;
    } catch (e) {
      throw mapFirestoreError(e, recurso: 'Demanda');
    }
  }

  // ! ===========================
  // ! UC17 - EDITAR DEMANDA
  // ! ===========================

  /// Atualiza dados da demanda. Validação de status acontece no provider/UI;
  /// aqui apenas executa a operação.
  Future<void> atualizar({
    required String id,
    required String autorUid,
    required String titulo,
    required String descricao,
    required String publicoAlvo,
    required String impacto,
  }) async {
    try {
      final agora = DateTime.now().toIso8601String();
      await _demandas.doc(id).update({
        'titulo': titulo,
        'tituloLower': titulo.toLowerCase(),
        'descricao': descricao,
        'publicoAlvo': publicoAlvo,
        'impacto': impacto,
        'atualizadoEm': agora,
      });

      // UC17 R04: log de auditoria
      await _registrarAuditoria(
        demandaId: id,
        acao: 'editar',
        autorUid: autorUid,
      );
    } catch (e) {
      throw mapFirestoreError(e, recurso: 'Demanda');
    }
  }

  // ! ===========================
  // ! UC16 - CANCELAR DEMANDA
  // ! ===========================

  /// Soft-delete: marca como cancelada e preserva o registro.
  /// Decisão arquitetural: NÃO removemos o documento porque
  /// (a) auditoria precisa do histórico;
  /// (b) o demandante ainda quer ver na lista "Minhas Demandas" (UC21 R02).
  Future<void> cancelar({
    required String id,
    required String autorUid,
    required String motivo,
  }) async {
    try {
      final agora = DateTime.now().toIso8601String();
      await _demandas.doc(id).update({
        'status': StatusDemanda.cancelada.name,
        'motivoCancelamento': motivo,
        'canceladoEm': agora,
      });

      await _registrarAuditoria(
        demandaId: id,
        acao: 'cancelar',
        autorUid: autorUid,
        metadados: {'motivo': motivo},
      );
    } catch (e) {
      throw mapFirestoreError(e, recurso: 'Demanda');
    }
  }

  // ! ===========================
  // ! UC21 - LISTAR DEMANDAS DO DEMANDANTE
  // ! ===========================

  /// Lista demandas do demandante em tempo real.
  /// Snapshots() porque UC21 exige atualização em tempo real quando o
  /// status mudar (ex: professor aceita → demandante vê o status mudar).
  ///
  /// Filtros aplicados server-side via where clauses. Filtros são acumulativos.
  ///
  /// Os filtros compostos exigem índice no Firestore — ver firestore.indexes.json.
  Stream<List<Demanda>> listarDoDemandante({
    required String demandanteUid,
    StatusDemanda? filtroStatus,
    FiltroPeriodo? filtroPeriodo,
  }) {
    Query<Map<String, dynamic>> query =
        _demandas.where('demandanteUid', isEqualTo: demandanteUid);

    if (filtroStatus != null) {
      query = query.where('status', isEqualTo: filtroStatus.name);
    }

    if (filtroPeriodo != null) {
      final range = filtroPeriodo.range;
      if (range.inicio != null) {
        query = query.where(
          'criadoEm',
          isGreaterThanOrEqualTo: range.inicio!.toIso8601String(),
        );
      }
      if (range.fim != null) {
        query = query.where(
          'criadoEm',
          isLessThan: range.fim!.toIso8601String(),
        );
      }
    }

    query = query.orderBy('criadoEm', descending: true);

    return query.snapshots().map(
          (snap) =>
              snap.docs.map((d) => Demanda.fromMap(d.id, d.data())).toList(),
        );
  }

  /// Busca uma demanda específica por ID. Stream para tempo real.
  Stream<Demanda?> observar(String id) {
    return _demandas.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Demanda.fromMap(doc.id, doc.data()!);
    });
  }

  // ! ===========================
  // ! UC20 - ANEXOS (subcoleção)
  // ! ===========================

  Stream<List<Anexo>> listarAnexos(String demandaId) {
    return _anexos(demandaId)
        .orderBy('enviadoEm', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => Anexo.fromMap(d.id, d.data())).toList(),
        );
  }

  Future<List<Anexo>> buscarAnexos(String demandaId) async {
    try {
      final snap =
          await _anexos(demandaId).orderBy('enviadoEm', descending: true).get();
      return snap.docs.map((d) => Anexo.fromMap(d.id, d.data())).toList();
    } catch (e) {
      throw mapFirestoreError(e, recurso: 'Anexos');
    }
  }

  /// Conta anexos via aggregation query (mais barato que listar).
  /// Usado pelo card pra mostrar o contador sem baixar metadados.
  Future<int> contarAnexos(String demandaId) async {
    try {
      final snap = await _anexos(demandaId).count().get();
      return snap.count ?? 0;
    } catch (_) {
      // Best-effort: se contagem falhar, mostra 0 em vez de quebrar o card.
      return 0;
    }
  }

  Future<String> registrarAnexo({
    required String demandaId,
    required Map<String, dynamic> dadosAnexo,
  }) async {
    try {
      final ref = await _anexos(demandaId).add(dadosAnexo);
      return ref.id;
    } catch (e) {
      throw mapFirestoreError(e, recurso: 'Anexo');
    }
  }

  Future<void> removerAnexoMetadata({
    required String demandaId,
    required String anexoId,
  }) async {
    try {
      await _anexos(demandaId).doc(anexoId).delete();
    } catch (e) {
      throw mapFirestoreError(e, recurso: 'Anexo');
    }
  }

  // ! ===========================
  // ! AUDITORIA (privado)
  // ! ===========================

  /// Cria log de auditoria. Best-effort: falha aqui não deve abortar a operação
  /// principal, então capturamos exceções silenciosamente (mas TODO logar).
  Future<void> _registrarAuditoria({
    required String demandaId,
    required String acao,
    required String autorUid,
    Map<String, dynamic>? metadados,
  }) async {
    try {
      await _firestore.collection(_collectionAuditLog).add({
        'demandaId': demandaId,
        'acao': acao,
        'autorUid': autorUid,
        'em': DateTime.now().toIso8601String(),
        if (metadados != null) 'metadados': metadados,
      });
    } catch (_) {
      // TODO(observabilidade): integrar com Crashlytics/Sentry
    }
  }
}
