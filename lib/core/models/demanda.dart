import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'enums.dart';

/// Status possíveis de uma demanda no fluxo completo do sistema.
///
/// IMPORTANTE: nem todas as transições são implementadas pelo demandante.
/// Esta enum existe inteira para que o vocabulário do domínio seja consistente,
/// mas as transições do professor (em análise / em produção / concluída)
/// serão implementadas em sprints futuras.
enum StatusDemanda {
  /// Estado inicial. Visível na prateleira pública.
  cadastrada,

  /// Professor marcou pra análise. Tem 24h pra decidir.
  /// TODO(sprint-3): transição via UC09
  emAnalise,

  /// Professor assumiu. Trabalho em andamento.
  /// TODO(sprint-3): transição via UC11
  emProducao,

  /// Trabalho entregue.
  /// TODO(sprint-3): transição via UC12
  concluida,

  /// Demandante cancelou (UC16). Soft-delete: preserva histórico.
  cancelada;

  String get label => switch (this) {
        StatusDemanda.cadastrada => 'Aguardando',
        StatusDemanda.emAnalise => 'Em análise',
        StatusDemanda.emProducao => 'Em produção',
        StatusDemanda.concluida => 'Concluída',
        StatusDemanda.cancelada => 'Cancelada',
      };

  IconData get icone => switch (this) {
        StatusDemanda.cadastrada => Icons.hourglass_empty,
        StatusDemanda.emAnalise => Icons.search,
        StatusDemanda.emProducao => Icons.settings,
        StatusDemanda.concluida => Icons.check_circle_outline,
        StatusDemanda.cancelada => Icons.cancel_outlined,
      };

  Color get cor => switch (this) {
        StatusDemanda.cadastrada => Colors.amber.shade700,
        StatusDemanda.emAnalise => Colors.orange.shade700,
        StatusDemanda.emProducao => Colors.blue.shade700,
        StatusDemanda.concluida => AppColors.success,
        StatusDemanda.cancelada => AppColors.error,
      };

  /// Demandante só pode editar/cancelar enquanto demanda não foi assumida.
  /// Regra alinhada com UC16 R02 e UC17 R02.
  bool get podeEditarDemandante => this == StatusDemanda.cadastrada;
  bool get podeCancelarDemandante => this == StatusDemanda.cadastrada;
}

/// Filtro aplicado à lista de demandas.
/// Conforme requisito do produto: filtros são acumulativos (status E período).
enum FiltroPeriodo {
  ultimos7Dias,
  ultimos30Dias,
  todasApos30Dias;

  String get label => switch (this) {
        FiltroPeriodo.ultimos7Dias => 'Últimos 7 dias',
        FiltroPeriodo.ultimos30Dias => 'Últimos 30 dias',
        FiltroPeriodo.todasApos30Dias => 'Todas após 30 dias',
      };

  /// Retorna a data mínima/máxima de criação para esse filtro.
  /// Para `todasApos30Dias`, retorna a data limite SUPERIOR
  /// (demandas criadas há mais de 30 dias).
  ({DateTime? inicio, DateTime? fim}) get range {
    final agora = DateTime.now();
    return switch (this) {
      FiltroPeriodo.ultimos7Dias => (
          inicio: agora.subtract(const Duration(days: 7)),
          fim: null,
        ),
      FiltroPeriodo.ultimos30Dias => (
          inicio: agora.subtract(const Duration(days: 30)),
          fim: null,
        ),
      FiltroPeriodo.todasApos30Dias => (
          inicio: null,
          fim: agora.subtract(const Duration(days: 30)),
        ),
    };
  }
}

class Demanda {
  final String id;

  // --- demandante ---
  final String demandanteUid;
  final String demandanteNome;
  final TipoDemandante demandanteTipo;

  // --- conteúdo ---
  final String titulo;
  final String descricao;
  final String publicoAlvo;
  final String impacto;

  // --- estado ---
  final StatusDemanda status;
  final String? motivoCancelamento;

  // --- atribuição (preenchido pelo professor em sprina futura) ---
  final String? professorUid;
  final String? professorNome;

  /// Se essa demanda foi cancelada e o demandante usou o botão
  /// "Republicar como nova demanda", este campo guarda o ID da nova.
  /// Serve para duas coisas:
  /// 1. Impedir republicação dupla (UI esconde o botão se != null).
  /// 2. Trilha de auditoria visível: a partir da cancelada dá pra
  ///    chegar à nova (futuro: link clicável).
  /// A Firestore Rule garante que esse campo só pode ser preenchido
  /// UMA vez, evitando reescrita maliciosa.
  final String? republicadaComoId;

  // --- timestamps ---
  final DateTime criadoEm;
  final DateTime? atualizadoEm;
  final DateTime? canceladoEm;

  const Demanda({
    required this.id,
    required this.demandanteUid,
    required this.demandanteNome,
    required this.demandanteTipo,
    required this.titulo,
    required this.descricao,
    required this.publicoAlvo,
    required this.impacto,
    required this.status,
    required this.criadoEm,
    this.motivoCancelamento,
    this.professorUid,
    this.professorNome,
    this.republicadaComoId,
    this.atualizadoEm,
    this.canceladoEm,
  });

  Map<String, dynamic> toMap() => {
        'demandanteUid': demandanteUid,
        'demandanteNome': demandanteNome,
        'demandanteTipo': demandanteTipo.name,
        'titulo': titulo,
        'tituloLower': titulo.toLowerCase(), // para busca client-side
        'descricao': descricao,
        'publicoAlvo': publicoAlvo,
        'impacto': impacto,
        'status': status.name,
        'motivoCancelamento': motivoCancelamento,
        'professorUid': professorUid,
        'professorNome': professorNome,
        'republicadaComoId': republicadaComoId,
        'criadoEm': criadoEm.toIso8601String(),
        'atualizadoEm': atualizadoEm?.toIso8601String(),
        'canceladoEm': canceladoEm?.toIso8601String(),
      };

  factory Demanda.fromMap(String id, Map<String, dynamic> map) => Demanda(
        id: id,
        demandanteUid: map['demandanteUid'] as String,
        demandanteNome: map['demandanteNome'] as String,
        demandanteTipo: TipoDemandante.values.firstWhere(
          (t) => t.name == map['demandanteTipo'],
          orElse: () => TipoDemandante.pessoaFisica,
        ),
        titulo: map['titulo'] as String,
        descricao: map['descricao'] as String,
        publicoAlvo: map['publicoAlvo'] as String,
        impacto: map['impacto'] as String,
        status: StatusDemanda.values.firstWhere(
          (s) => s.name == map['status'],
          orElse: () => StatusDemanda.cadastrada,
        ),
        motivoCancelamento: map['motivoCancelamento'] as String?,
        professorUid: map['professorUid'] as String?,
        professorNome: map['professorNome'] as String?,
        // Demandas legadas (criadas antes deste campo existir) retornam null.
        republicadaComoId: map['republicadaComoId'] as String?,
        criadoEm: DateTime.parse(map['criadoEm'] as String),
        atualizadoEm: map['atualizadoEm'] != null
            ? DateTime.parse(map['atualizadoEm'] as String)
            : null,
        canceladoEm: map['canceladoEm'] != null
            ? DateTime.parse(map['canceladoEm'] as String)
            : null,
      );

  Demanda copyWith({
    String? titulo,
    String? descricao,
    String? publicoAlvo,
    String? impacto,
    StatusDemanda? status,
    String? motivoCancelamento,
    String? republicadaComoId,
    DateTime? atualizadoEm,
    DateTime? canceladoEm,
  }) {
    return Demanda(
      id: id,
      demandanteUid: demandanteUid,
      demandanteNome: demandanteNome,
      demandanteTipo: demandanteTipo,
      titulo: titulo ?? this.titulo,
      descricao: descricao ?? this.descricao,
      publicoAlvo: publicoAlvo ?? this.publicoAlvo,
      impacto: impacto ?? this.impacto,
      status: status ?? this.status,
      motivoCancelamento: motivoCancelamento ?? this.motivoCancelamento,
      professorUid: professorUid,
      professorNome: professorNome,
      republicadaComoId: republicadaComoId ?? this.republicadaComoId,
      criadoEm: criadoEm,
      atualizadoEm: atualizadoEm ?? this.atualizadoEm,
      canceladoEm: canceladoEm ?? this.canceladoEm,
    );
  }
}
