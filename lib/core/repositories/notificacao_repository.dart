import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/app_constants.dart';
import '../exceptions/firestore_error_handler.dart';
import '../models/notificacao.dart';

/// Central de notificações in-app.
///
/// **Escrita é sempre best-effort.** Notificar é consequência de uma operação
/// principal que já foi commitada (assumir demanda, julgar denúncia, enviar
/// mensagem). Se o documento de notificação falhar, o usuário perde um aviso —
/// não pode perder a operação. Por isso [enfileirar] engole exceções em vez de
/// propagá-las, coerente com o princípio §2.5 da arquitetura.
///
/// **Leitura é em tempo real.** A central e o badge do sino consomem o mesmo
/// stream, então abrir a tela não gera leitura extra.
class NotificacaoRepository {
  final FirebaseFirestore _firestore;

  NotificacaoRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _notificacoes =>
      _firestore.collection(AppConstants.collectionNotificacoes);

  // ! ===========================
  // ! LEITURA
  // ! ===========================

  /// Notificações do usuário, mais recentes primeiro.
  /// Exige índice composto (destinatarioUid ASC, criadoEm DESC).
  Stream<List<Notificacao>> observar(String uid) {
    return _notificacoes
        .where('destinatarioUid', isEqualTo: uid)
        .orderBy('criadoEm', descending: true)
        .limit(AppConstants.limiteNotificacoes)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Notificacao.fromMap(d.id, d.data()))
            .toList());
  }

  // ! ===========================
  // ! ESCRITA DO DESTINATÁRIO
  // ! ===========================

  /// Marca uma notificação como lida. As Rules restringem a escrita ao
  /// destinatário e apenas aos campos `lida`/`lidaEm`.
  Future<void> marcarComoLida(String id) async {
    try {
      await _notificacoes.doc(id).update({
        'lida': true,
        'lidaEm': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw mapFirestoreError(e, recurso: 'Notificação');
    }
  }

  /// Marca todas as não lidas do usuário de uma vez.
  ///
  /// Percorre em lotes de 400 (o `WriteBatch` do Firestore aceita 500
  /// operações; a margem evita estourar por arredondamento). Para o volume
  /// esperado — dezenas de notificações — um único lote resolve.
  Future<void> marcarTodasComoLidas(String uid) async {
    try {
      final naoLidas = await _notificacoes
          .where('destinatarioUid', isEqualTo: uid)
          .where('lida', isEqualTo: false)
          .get();
      if (naoLidas.docs.isEmpty) return;

      final agora = DateTime.now().toIso8601String();
      for (var i = 0; i < naoLidas.docs.length; i += 400) {
        final fatia = naoLidas.docs.skip(i).take(400);
        final batch = _firestore.batch();
        for (final doc in fatia) {
          batch.update(doc.reference, {'lida': true, 'lidaEm': agora});
        }
        await batch.commit();
      }
    } catch (e) {
      throw mapFirestoreError(e, recurso: 'Notificações');
    }
  }

  // ! ===========================
  // ! ENFILEIRAMENTO (best-effort)
  // ! ===========================

  /// Cria a notificação. Nunca lança — ver docstring da classe.
  ///
  /// [autorUid] precisa ser o uid autenticado: as Rules recusam qualquer
  /// documento cujo autor não seja quem está escrevendo, o que impede forjar
  /// notificações em nome de terceiros.
  Future<void> enfileirar({
    required String destinatarioUid,
    required String autorUid,
    required String autorNome,
    required TipoNotificacao tipo,
    required String titulo,
    required String corpo,
    String? demandaId,
    String? chatId,
    String? denunciaId,
  }) async {
    // Notificar a si mesmo é sempre ruído (ex.: admin que julga a própria
    // denúncia num ambiente de teste).
    if (destinatarioUid == autorUid) return;

    try {
      await _notificacoes.add(
        Notificacao(
          id: '',
          destinatarioUid: destinatarioUid,
          autorUid: autorUid,
          autorNome: autorNome,
          tipo: tipo,
          titulo: titulo,
          corpo: corpo,
          demandaId: demandaId,
          chatId: chatId,
          denunciaId: denunciaId,
          criadoEm: DateTime.now(),
        ).toMap(),
      );
    } catch (_) {
      // best-effort — ver docstring da classe.
    }
  }

  /// Variante para uso dentro de uma transação/batch já aberta pelo chamador,
  /// quando a notificação precisa ser atômica com a operação principal
  /// (ex.: a mensagem de chat e o aviso da mensagem).
  void enfileirarNoBatch(
    WriteBatch batch, {
    required String destinatarioUid,
    required String autorUid,
    required String autorNome,
    required TipoNotificacao tipo,
    required String titulo,
    required String corpo,
    String? demandaId,
    String? chatId,
    String? denunciaId,
  }) {
    if (destinatarioUid == autorUid) return;
    batch.set(
      _notificacoes.doc(),
      Notificacao(
        id: '',
        destinatarioUid: destinatarioUid,
        autorUid: autorUid,
        autorNome: autorNome,
        tipo: tipo,
        titulo: titulo,
        corpo: corpo,
        demandaId: demandaId,
        chatId: chatId,
        denunciaId: denunciaId,
        criadoEm: DateTime.now(),
      ).toMap(),
    );
  }
}
