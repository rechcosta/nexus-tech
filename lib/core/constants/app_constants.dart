class AppConstants {
  // * Domínios institucionais
  static const String professorEmailDomain = 'osorio.ifrs.edu.br';

  /// * Lista de e-mails autorizados como administradores.
  /// Para adicionar/remover admins, edita essa lista e
  /// republica o app, ou — alternativa futura — migra essa configuração
  /// pra Remote Config.
  /// ! IMPORTANTE: emails aqui também precisam estar replicados nas Firestore
  /// * Rules (no helper isAdminEmail). Ver firestore.rules.
  ///
  /// ! Não repita aqui nenhum e-mail de [professorTestEmails] — admin tem
  /// precedência e a conta deixaria de servir para testar o professor.
  static const Set<String> adminEmails = {
    // * Adicione os e-mails dos administradores aqui:
    //'karen.borges@osorio.ifrs.edu.br',
    'rechcostagustavo@gmail.com',
  };

  // ╔══════════════════════════════════════════════════════════════════╗
  // ║ INÍCIO — E-MAIL DE TESTE (PROFESSOR) — REMOVER ANTES DE PRODUÇÃO   ║
  // ╚══════════════════════════════════════════════════════════════════╝
  /// * E-mails extras tratados como PROFESSOR para TESTE, mesmo sem o domínio
  /// institucional. Permite validar o fluxo completo do professor com uma
  /// conta pessoal (Google).
  /// ! IMPORTANTE: manter sincronizado com firestore.rules > isProfessorEmail().
  ///
  /// ! Um e-mail NUNCA deve estar aqui e em [adminEmails] ao mesmo tempo:
  /// `AuthProvider` checa `isAdminEmail` primeiro, então a conta viraria
  /// administradora e o papel de professor nunca seria exercido. As duas
  /// listas são mantidas disjuntas de propósito, uma conta por papel.
  static const Set<String> professorTestEmails = {
    'gustavinho.rechcosta@gmail.com', // <-- conta de teste do PROFESSOR
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

  /// Notificações in-app. Renderizadas em tempo real pelo próprio app (funciona
  /// no plano Spark); o push via FCM depende de uma Cloud Function que observe
  /// esta coleção. Ver docs/CLOUD_FUNCTIONS.md.
  static const String collectionNotificacoes = 'notificacoes';

  /// Conversas demandante x professor. O ID de cada documento é o `demandaId`
  /// correspondente — ver docstring de `Chat`.
  static const String collectionChats = 'chats';

  /// Subcoleção de mensagens dentro de cada chat.
  static const String subcollectionMensagens = 'mensagens';

  /// Denúncias de demandas feitas por professores e julgadas por admins.
  static const String collectionDenuncias = 'denuncias';

  // * Regras de negócio do ciclo de vida da demanda

  /// Strikes que levam ao banimento automático do demandante.
  /// Aplicado na mesma transação que julga a denúncia procedente
  /// (`DenunciaRepository.julgar`), e reforçado pelas Firestore Rules, que
  /// bloqueiam a criação de demandas por conta banida.
  static const int strikesParaBanimento = 3;

  /// Limite de caracteres de uma mensagem de chat. Espelhado nas Rules —
  /// mudar aqui exige mudar lá (firestore.rules > match /chats/{id}/mensagens).
  static const int maxCaracteresMensagem = 2000;

  /// Quantas mensagens a tela de chat mantém em memória. Conversas longas
  /// carregam as mais recentes; o histórico completo fica no Firestore.
  static const int limiteMensagensChat = 200;

  /// Quantas notificações a central carrega por vez.
  static const int limiteNotificacoes = 50;

  /// UC09 R03: janela máxima de análise antes do rollback automático.
  /// O rollback definitivo (para todos os professores, em tempo hábil) será
  /// uma Cloud Function agendada/triggada. Enquanto não há acesso a Functions,
  /// o cliente reconcilia de forma best-effort ao abrir "Minhas Demandas".
  static const Duration janelaAnalise = Duration(hours: 24);
}
