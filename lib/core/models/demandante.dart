import 'enums.dart';
import 'usuario.dart';

class Demandante extends Usuario {
  final String telefone;
  final TipoDemandante tipo;
  final String cpfCnpj;
  final String endereco;
  final int strikes;

  Demandante({
    required super.uid,
    required super.email,
    required super.nome,
    required super.criadoEm,
    required this.telefone,
    required this.tipo,
    required this.cpfCnpj,
    required this.endereco,
    this.strikes = 0,
  }) : super(role: UserRole.demandante);

  @override
  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'nome': nome,
        'role': role.name,
        'criadoEm': criadoEm.toIso8601String(),
        'telefone': telefone,
        'tipo': tipo.name,
        'cpfCnpj': cpfCnpj,
        'endereco': endereco,
        'strikes': strikes,
      };

  factory Demandante.fromMap(Map<String, dynamic> map) => Demandante(
        uid: map['uid'] as String,
        email: map['email'] as String,
        nome: map['nome'] as String,
        criadoEm: DateTime.parse(map['criadoEm'] as String),
        telefone: map['telefone'] as String,
        tipo: TipoDemandante.values.firstWhere(
          (e) => e.name == map['tipo'],
          orElse: () => TipoDemandante.pessoaFisica,
        ),
        cpfCnpj: map['cpfCnpj'] as String,
        endereco: map['endereco'] as String,
        strikes: map['strikes'] as int? ?? 0,
      );
}
