enum UserRole { administrador, professor, demandante }

enum TipoDemandante {
  empresa,
  orgaoPublico,
  ong,
  instituicaoEducacional,
  pessoaFisica,
  academico;

  String get label => switch (this) {
        TipoDemandante.empresa => 'Empresa',
        TipoDemandante.orgaoPublico => 'Órgão Público',
        TipoDemandante.ong => 'ONG',
        TipoDemandante.instituicaoEducacional => 'Instituição Educacional',
        TipoDemandante.pessoaFisica => 'Pessoa Física',
        TipoDemandante.academico => 'Acadêmico',
      };
}
