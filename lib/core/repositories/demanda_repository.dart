import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/app_constants.dart';
import '../exceptions/app_exception.dart';
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
  ///
  /// Se [originalCanceladaId] for fornecido, a operação é uma REPUBLICAÇÃO:
  /// cria a nova demanda E marca a original com `republicadaComoId` na
  /// mesma transação atômica (WriteBatch). Se uma operação falhar, nenhuma
  /// é persistida — impede estados inconsistentes onde a nova demanda
  /// existe mas a original ainda mostra o botão de republicar.
  Future<String> criar(
    Demanda demanda, {
    String? originalCanceladaId,
  }) async {
    try {
      if (originalCanceladaId == null) {
        // ----- fluxo simples: criação normal -----
        final docRef = await _demandas.add(demanda.toMap());

        // UC15 R05: registro em log de auditoria
        await _registrarAuditoria(
          demandaId: docRef.id,
          acao: 'criar',
          autorUid: demanda.demandanteUid,
        );

        return docRef.id;
      }

      // ----- fluxo de republicação: batch atômica -----
      // Gera referência (e ID) antes de escrever para podermos usá-lo
      // no update da demanda original na mesma batch.
      final novaRef = _demandas.doc();
      final originalRef = _demandas.doc(originalCanceladaId);

      final batch = _firestore.batch();
      batch.set(novaRef, demanda.toMap());
      batch.update(originalRef, {'republicadaComoId': novaRef.id});

      await batch.commit();

      await _registrarAuditoria(
        demandaId: novaRef.id,
        acao: 'republicar',
        autorUid: demanda.demandanteUid,
        metadados: {'originalCanceladaId': originalCanceladaId},
      );

      return novaRef.id;
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
  // ! UC08 - PRATELEIRA DO PROFESSOR
  // ! ===========================

  /// Lista a prateleira pública (UC08) em tempo real.
  /// UC08 R01: apenas demandas `cadastrada` e `emProducao` são exibidas.
  /// Demandas `emAnalise` somem da prateleira (UC09) por não estarem nesse
  /// conjunto; canceladas/concluídas idem.
  ///
  /// Exige índice composto (status ASC, criadoEm DESC) — ver
  /// firestore.indexes.json. A busca textual (título/descrição) é aplicada
  /// client-side no provider, coerente com a decisão de §7.3 da arquitetura.
  Stream<List<Demanda>> listarPrateleira() {
    return _demandas
        .where('status', whereIn: [
          StatusDemanda.cadastrada.name,
          StatusDemanda.emProducao.name,
        ])
        .orderBy('criadoEm', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => Demanda.fromMap(d.id, d.data())).toList(),
        );
  }

  /// Lista as demandas atribuídas a um professor ("Minhas Demandas" do
  /// professor — UC09/UC10/UC11/UC12). Em tempo real, pois o status muda
  /// durante a sessão. Filtros server-side acumulativos, espelhando
  /// [listarDoDemandante]. Exige índices compostos por `professorUid`.
  Stream<List<Demanda>> listarDoProfessor({
    required String professorUid,
    StatusDemanda? filtroStatus,
    FiltroPeriodo? filtroPeriodo,
  }) {
    Query<Map<String, dynamic>> query =
        _demandas.where('professorUid', isEqualTo: professorUid);

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

  // ! ===========================
  // ! UC09/UC10/UC11/UC12 - TRANSIÇÕES DE STATUS (PROFESSOR)
  // ! ===========================
  //
  // Todas as transições usam runTransaction: lê o estado atual, valida a
  // máquina de estados (StatusDemanda.podeTransicionarPara) e a propriedade
  // sobre a demanda DENTRO da transação, e só então escreve. Isso garante
  // serializabilidade — se dois professores agem ao mesmo tempo, apenas um
  // commit vence; o outro vê o estado já alterado e recebe ConflictException.
  // As Firestore Rules são a camada de segurança equivalente no servidor.

  /// UC09 — Marca a demanda para análise (`cadastrada` -> `emAnalise`),
  /// associa o professor e agenda a janela de 24h ([AppConstants.janelaAnalise]).
  Future<void> marcarParaAnalise({
    required String demandaId,
    required String professorUid,
    required String professorNome,
  }) async {
    try {
      await _firestore.runTransaction((tx) async {
        final ref = _demandas.doc(demandaId);
        final snap = await tx.get(ref);
        if (!snap.exists) throw const NotFoundException('Demanda');

        final atual = Demanda.fromMap(snap.id, snap.data()!);
        if (!atual.status.podeMarcarAnalise) {
          throw const ConflictException(
            'Esta demanda não está mais disponível para análise.',
          );
        }

        final agora = DateTime.now();
        tx.update(ref, {
          'status': StatusDemanda.emAnalise.name,
          'professorUid': professorUid,
          'professorNome': professorNome,
          'analiseIniciadaEm': agora.toIso8601String(),
          'analiseExpiraEm':
              agora.add(AppConstants.janelaAnalise).toIso8601String(),
          'atualizadoEm': agora.toIso8601String(),
        });
      });

      await _registrarAuditoria(
        demandaId: demandaId,
        acao: 'marcar_analise',
        autorUid: professorUid,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw mapFirestoreError(e, recurso: 'Demanda');
    }
  }

  /// UC10 — Devolve a demanda em análise para a prateleira
  /// (`emAnalise` -> `cadastrada`) e desassocia o professor.
  ///
  /// [automatico] indica rollback por expiração da janela de 24h (UC09 R04),
  /// diferenciado na auditoria. Tanto a rejeição manual quanto o rollback só
  /// podem ser feitos pelo professor associado (ou, no futuro, pela Cloud
  /// Function de expiração via privilégio de admin).
  Future<void> rejeitarAnalise({
    required String demandaId,
    required String professorUid,
    bool automatico = false,
  }) async {
    try {
      await _firestore.runTransaction((tx) async {
        final ref = _demandas.doc(demandaId);
        final snap = await tx.get(ref);
        if (!snap.exists) throw const NotFoundException('Demanda');

        final atual = Demanda.fromMap(snap.id, snap.data()!);
        if (!atual.status.podeRejeitar || atual.professorUid != professorUid) {
          throw const ConflictException(
            'Esta demanda não está mais em análise por você.',
          );
        }

        tx.update(ref, {
          'status': StatusDemanda.cadastrada.name,
          'professorUid': null,
          'professorNome': null,
          'analiseIniciadaEm': null,
          'analiseExpiraEm': null,
          'atualizadoEm': DateTime.now().toIso8601String(),
        });
      });

      await _registrarAuditoria(
        demandaId: demandaId,
        acao: automatico ? 'rollback_analise' : 'rejeitar',
        autorUid: professorUid,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw mapFirestoreError(e, recurso: 'Demanda');
    }
  }

  /// UC11 — Assume a demanda (`emAnalise` -> `emProducao`).
  /// Registra o início da produção (para indicadores) e enfileira a
  /// notificação do demandante. A criação do chat (UC11 R03) é Sprint 4.
  Future<void> assumir({
    required String demandaId,
    required String professorUid,
  }) async {
    try {
      late Demanda assumida;
      await _firestore.runTransaction((tx) async {
        final ref = _demandas.doc(demandaId);
        final snap = await tx.get(ref);
        if (!snap.exists) throw const NotFoundException('Demanda');

        final atual = Demanda.fromMap(snap.id, snap.data()!);
        if (!atual.status.podeAssumir || atual.professorUid != professorUid) {
          throw const ConflictException(
            'Esta demanda não está mais em análise por você.',
          );
        }
        assumida = atual;

        tx.update(ref, {
          'status': StatusDemanda.emProducao.name,
          'producaoIniciadaEm': DateTime.now().toIso8601String(),
          // A janela de análise deixa de fazer sentido após a assunção.
          'analiseExpiraEm': null,
          'atualizadoEm': DateTime.now().toIso8601String(),
        });
      });

      await _registrarAuditoria(
        demandaId: demandaId,
        acao: 'assumir',
        autorUid: professorUid,
      );

      // UC11 R04: notificar o demandante (best-effort; despacho via FCM
      // ficará a cargo de Cloud Function — ver docs/CLOUD_FUNCTIONS.md).
      await _enfileirarNotificacao(
        destinatarioUid: assumida.demandanteUid,
        autorUid: professorUid,
        tipo: 'demanda_em_producao',
        demandaId: demandaId,
        tituloDemanda: assumida.titulo,
        professorNome: assumida.professorNome,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw mapFirestoreError(e, recurso: 'Demanda');
    }
  }

  /// UC12 — Conclui a demanda (`emProducao` -> `concluida`), registrando a
  /// descrição da solução e a data de entrega. Os anexos da entrega são
  /// enviados ANTES desta chamada (são o entregável). Libera a avaliação do
  /// demandante (derivada do status `concluida`) e enfileira a notificação.
  Future<void> concluir({
    required String demandaId,
    required String professorUid,
    required String descricaoSolucao,
  }) async {
    try {
      late Demanda concluida;
      await _firestore.runTransaction((tx) async {
        final ref = _demandas.doc(demandaId);
        final snap = await tx.get(ref);
        if (!snap.exists) throw const NotFoundException('Demanda');

        final atual = Demanda.fromMap(snap.id, snap.data()!);
        if (!atual.status.podeConcluir || atual.professorUid != professorUid) {
          throw const ConflictException(
            'Apenas o professor responsável pode concluir esta demanda, '
            'e somente enquanto ela estiver em produção.',
          );
        }
        concluida = atual;

        final agora = DateTime.now();
        tx.update(ref, {
          'status': StatusDemanda.concluida.name,
          'descricaoSolucao': descricaoSolucao,
          'concluidaEm': agora.toIso8601String(),
          'atualizadoEm': agora.toIso8601String(),
        });
      });

      await _registrarAuditoria(
        demandaId: demandaId,
        acao: 'concluir',
        autorUid: professorUid,
      );

      await _enfileirarNotificacao(
        destinatarioUid: concluida.demandanteUid,
        autorUid: professorUid,
        tipo: 'demanda_concluida',
        demandaId: demandaId,
        tituloDemanda: concluida.titulo,
        professorNome: concluida.professorNome,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw mapFirestoreError(e, recurso: 'Demanda');
    }
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

  // ! ===========================
  // ! NOTIFICAÇÕES (privado, best-effort)
  // ! ===========================

  /// Enfileira uma notificação para o destinatário (UC11/UC12 R04).
  ///
  /// O app apenas ESCREVE o documento. O envio do push em si (FCM) será feito
  /// por uma Cloud Function que observa a coleção `notificacoes` e marca
  /// `enviada: true` após despachar — ver docs/CLOUD_FUNCTIONS.md. Por isso é
  /// best-effort: falhar aqui não pode abortar a transição de status, que é a
  /// operação principal e já foi commitada.
  Future<void> _enfileirarNotificacao({
    required String destinatarioUid,
    required String autorUid,
    required String tipo,
    required String demandaId,
    required String tituloDemanda,
    String? professorNome,
  }) async {
    try {
      await _firestore.collection(AppConstants.collectionNotificacoes).add({
        'destinatarioUid': destinatarioUid,
        'autorUid': autorUid,
        'tipo': tipo,
        'demandaId': demandaId,
        'tituloDemanda': tituloDemanda,
        'professorNome': professorNome,
        'lida': false,
        // Flag consumida pela Cloud Function de despacho (FCM).
        'enviada': false,
        'criadoEm': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // best-effort — ver docstring.
    }
  }
}
