class AppConstants {
  // * Domínios institucionais
  static const String professorEmailDomain = 'osorio.ifrs.edu.br';

  /// * Lista de e-mails autorizados como administradores.
  /// Para adicionar/remover admins, edita essa lista e
  /// republica o app, ou — alternativa futura — migra essa configuração
  /// pra Remote Config.
  /// ! IMPORTANTE: emails aqui também precisam estar replicados nas Firestore
  /// * Rules (no helper isAdminEmail). Ver firestore.rules.
  static const Set<String> adminEmails = {
    // * Adicione os e-mails dos administradores aqui:
    //'karen.borges@osorio.ifrs.edu.br',
    // 'rechcostagustavo@gmail.com',
  };

  // ╔══════════════════════════════════════════════════════════════════╗
  // ║ INÍCIO — E-MAIL DE TESTE (PROFESSOR) — REMOVER ANTES DE PRODUÇÃO   ║
  // ╚══════════════════════════════════════════════════════════════════╝
  /// * E-mails extras tratados como PROFESSOR para TESTE, mesmo sem o domínio
  /// institucional. Permite validar o fluxo completo do professor com uma
  /// conta pessoal (Google).
  /// ! IMPORTANTE: manter sincronizado com firestore.rules > isProfessorEmail().
  static const Set<String> professorTestEmails = {
    'rechcostagustavo@gmail.com', // <-- seu e-mail de teste aqui
  };
  // ╔══════════════════════════════════════════════════════════════════╗
  // ║ FIM — E-MAIL DE TESTE (PROFESSOR)                                  ║
  // ╚══════════════════════════════════════════════════════════════════╝

  // Coleções Firestore
  static const String collectionUsers = 'users';
  static const String collectionAreasTecnicas = 'areas_tecnicas';
  static const String collectionAreasInteresse = 'areas_interesse';
  static const String collectionDemandas = 'demandas';
  static const String collectionAuditLogs = 'audit_logs';

  /// Fila de notificações pendentes. O app apenas enfileira (best-effort);
  /// uma Cloud Function despacha via FCM quando o Firebase pago for liberado.
  /// Ver docs/CLOUD_FUNCTIONS.md.
  static const String collectionNotificacoes = 'notificacoes';

  // * Regras de negócio do ciclo de vida da demanda

  /// UC09 R03: janela máxima de análise antes do rollback automático.
  /// O rollback definitivo (para todos os professores, em tempo hábil) será
  /// uma Cloud Function agendada/triggada. Enquanto não há acesso a Functions,
  /// o cliente reconcilia de forma best-effort ao abrir "Minhas Demandas".
  static const Duration janelaAnalise = Duration(hours: 24);
}
