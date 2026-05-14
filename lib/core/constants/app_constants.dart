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
    'karen.borges@osorio.ifrs.edu.br',
    // 'rechcostagustavo@gmail.com',
  };

  // Coleções Firestore
  static const String collectionUsers = 'users';
  static const String collectionAreasTecnicas = 'areas_tecnicas';
  static const String collectionAreasInteresse = 'areas_interesse';
}
