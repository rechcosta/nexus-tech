import 'enums.dart';
import 'usuario.dart';

class Professor extends Usuario {
  final String siape;
  final List<String> areasTecnicas;
  final List<String> areasInteresse;
  final bool ativo;

  Professor({
    required super.uid,
    required super.email,
    required super.nome,
    required super.criadoEm,
    required this.siape,
    required this.areasTecnicas,
    required this.areasInteresse,
    this.ativo = true,
    super.fotoUrl,
  }) : super(role: UserRole.professor);

  @override
  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'nome': nome,
        'role': role.name,
        'criadoEm': criadoEm.toIso8601String(),
        'siape': siape,
        'areasTecnicas': areasTecnicas,
        'areasInteresse': areasInteresse,
        'ativo': ativo,
        'fotoUrl': fotoUrl,
      };

  factory Professor.fromMap(Map<String, dynamic> map) => Professor(
        uid: map['uid'] as String,
        email: map['email'] as String,
        nome: map['nome'] as String,
        criadoEm: DateTime.parse(map['criadoEm'] as String),
        siape: map['siape'] as String,
        areasTecnicas: List<String>.from(map['areasTecnicas'] ?? const []),
        areasInteresse: List<String>.from(map['areasInteresse'] ?? const []),
        ativo: map['ativo'] as bool? ?? true,
        fotoUrl: map['fotoUrl'] as String?,
      );
}
