import 'enums.dart';

abstract class Usuario {
  final String uid;
  final String email;
  final String nome;
  final UserRole role;
  final DateTime criadoEm;

  const Usuario({
    required this.uid,
    required this.email,
    required this.nome,
    required this.role,
    required this.criadoEm,
  });

  Map<String, dynamic> toMap();
}
