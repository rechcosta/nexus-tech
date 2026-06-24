import 'enums.dart';
import 'usuario.dart';

class Administrador extends Usuario {
  Administrador({
    required super.uid,
    required super.email,
    required super.nome,
    required super.criadoEm,
    super.fotoUrl,
  }) : super(role: UserRole.administrador);

  @override
  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'nome': nome,
        'role': role.name,
        'criadoEm': criadoEm.toIso8601String(),
        'fotoUrl': fotoUrl,
      };

  factory Administrador.fromMap(Map<String, dynamic> map) => Administrador(
        uid: map['uid'] as String,
        email: map['email'] as String,
        nome: map['nome'] as String,
        criadoEm: DateTime.parse(map['criadoEm'] as String),
        fotoUrl: map['fotoUrl'] as String?,
      );
}
