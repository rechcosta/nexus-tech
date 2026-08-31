import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Conversa 1:1 entre o demandante e o professor de uma demanda (UC11 R03).
///
/// **O ID do documento é o próprio `demandaId`.** Essa escolha torna a criação
/// idempotente: assumir a mesma demanda duas vezes (retry de rede, duplo
/// clique) escreve no mesmo documento em vez de criar conversas paralelas.
/// Não há chat sem demanda, e não há duas conversas para a mesma demanda.
///
/// [participantes] duplica os dois uids num array só para viabilizar a query
/// `array-contains` da lista de conversas — Firestore não faz OR entre dois
/// campos diferentes numa única query.
class Chat {
  /// Igual ao `demandaId` (ver docstring da classe).
  final String id;

  final String demandaId;
  final String tituloDemanda;

  final String demandanteUid;
  final String demandanteNome;
  final String professorUid;
  final String professorNome;

  /// `[demandanteUid, professorUid]` — usado no `array-contains` da listagem.
  final List<String> participantes;

  // --- denormalização da última mensagem (evita N leituras na listagem) ---
  final String? ultimaMensagem;
  final String? ultimaMensagemAutorUid;
  final DateTime? ultimaMensagemEm;

  /// Contador de não lidas por uid: `{ '<uid>': 3 }`. Incrementado
  /// atomicamente (`FieldValue.increment`) por quem envia e zerado por quem lê.
  final Map<String, int> naoLidas;

  /// `false` quando a demanda saiu de um estado que justifica conversa
  /// (concluída/cancelada). O histórico continua legível; só o envio para.
  final bool ativo;

  final DateTime criadoEm;

  const Chat({
    required this.id,
    required this.demandaId,
    required this.tituloDemanda,
    required this.demandanteUid,
    required this.demandanteNome,
    required this.professorUid,
    required this.professorNome,
    required this.participantes,
    required this.naoLidas,
    required this.criadoEm,
    this.ultimaMensagem,
    this.ultimaMensagemAutorUid,
    this.ultimaMensagemEm,
    this.ativo = true,
  });

  /// Não lidas para [uid]. Zero quando o uid não é participante.
  int naoLidasDe(String uid) => naoLidas[uid] ?? 0;

  /// Nome do outro lado da conversa, do ponto de vista de [uid].
  String outroNome(String uid) =>
      uid == demandanteUid ? professorNome : demandanteNome;

  /// Uid do outro lado da conversa, do ponto de vista de [uid].
  String outroUid(String uid) =>
      uid == demandanteUid ? professorUid : demandanteUid;

  Map<String, dynamic> toMap() => {
        'demandaId': demandaId,
        'tituloDemanda': tituloDemanda,
        'demandanteUid': demandanteUid,
        'demandanteNome': demandanteNome,
        'professorUid': professorUid,
        'professorNome': professorNome,
        'participantes': participantes,
        'ultimaMensagem': ultimaMensagem,
        'ultimaMensagemAutorUid': ultimaMensagemAutorUid,
        'ultimaMensagemEm': ultimaMensagemEm?.toIso8601String(),
        'naoLidas': naoLidas,
        'ativo': ativo,
        'criadoEm': criadoEm.toIso8601String(),
      };

  factory Chat.fromMap(String id, Map<String, dynamic> map) => Chat(
        id: id,
        demandaId: map['demandaId'] as String? ?? id,
        tituloDemanda: map['tituloDemanda'] as String? ?? 'Demanda',
        demandanteUid: map['demandanteUid'] as String,
        demandanteNome: map['demandanteNome'] as String? ?? 'Demandante',
        professorUid: map['professorUid'] as String,
        professorNome: map['professorNome'] as String? ?? 'Professor',
        participantes: List<String>.from(map['participantes'] ?? const []),
        ultimaMensagem: map['ultimaMensagem'] as String?,
        ultimaMensagemAutorUid: map['ultimaMensagemAutorUid'] as String?,
        ultimaMensagemEm: _parseData(map['ultimaMensagemEm']),
        // Firestore devolve Map<String, dynamic>; os contadores podem vir como
        // int ou num dependendo de como foram escritos (increment vs. set).
        naoLidas: (map['naoLidas'] as Map?)?.map(
              (k, v) => MapEntry(k as String, (v as num?)?.toInt() ?? 0),
            ) ??
            const {},
        ativo: map['ativo'] as bool? ?? true,
        criadoEm: _parseData(map['criadoEm']) ?? DateTime.now(),
      );

  static DateTime? _parseData(Object? valor) {
    if (valor is! String) return null;
    return DateTime.tryParse(valor);
  }
}

/// Uma mensagem dentro de [Chat]. Subcoleção `chats/{demandaId}/mensagens`.
///
/// [sistema] marca mensagens geradas pelo app (ex.: "Demanda assumida"), que
/// aparecem centralizadas e sem balão — servem de marco temporal na conversa.
class Mensagem {
  final String id;
  final String autorUid;
  final String autorNome;
  final String texto;
  final DateTime enviadaEm;
  final bool sistema;

  const Mensagem({
    required this.id,
    required this.autorUid,
    required this.autorNome,
    required this.texto,
    required this.enviadaEm,
    this.sistema = false,
  });

  Map<String, dynamic> toMap() => {
        'autorUid': autorUid,
        'autorNome': autorNome,
        'texto': texto,
        'enviadaEm': enviadaEm.toIso8601String(),
        'sistema': sistema,
      };

  factory Mensagem.fromMap(String id, Map<String, dynamic> map) => Mensagem(
        id: id,
        autorUid: map['autorUid'] as String? ?? '',
        autorNome: map['autorNome'] as String? ?? '',
        texto: map['texto'] as String? ?? '',
        enviadaEm:
            DateTime.tryParse(map['enviadaEm'] as String? ?? '') ??
                DateTime.now(),
        sistema: map['sistema'] as bool? ?? false,
      );

  /// Cor do balão conforme autoria. Centralizado aqui pelo mesmo motivo de
  /// `StatusDemanda.cor`: ponto único de verdade visual.
  static Color corBalao({required bool meu, required bool sistema}) {
    if (sistema) return Colors.grey.shade200;
    return meu ? AppColors.primary : Colors.white;
  }
}
