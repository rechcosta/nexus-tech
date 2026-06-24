import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/app_constants.dart';
import '../exceptions/firestore_error_handler.dart';
import '../models/administrador.dart';
import '../models/demandante.dart';
import '../models/enums.dart';
import '../models/professor.dart';
import '../models/usuario.dart';

class UsuarioRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(AppConstants.collectionUsers);

  Future<Usuario?> buscarPorUid(String uid) async {
    try {
      final doc = await _users.doc(uid).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      final roleStr = data['role'] as String?;
      if (roleStr == null) {
        // Documento corrompido: existe mas sem role válido.
        // Trata como inexistente para forçar novo cadastro.
        return null;
      }

      final role = UserRole.values.where((e) => e.name == roleStr).firstOrNull;
      if (role == null) return null;

      return switch (role) {
        UserRole.professor => Professor.fromMap(data),
        UserRole.demandante => Demandante.fromMap(data),
        UserRole.administrador => Administrador.fromMap(data),
      };
    } catch (e) {
      throw mapFirestoreError(e, recurso: 'Usuário');
    }
  }

  Future<void> criarProfessor(Professor professor) async {
    try {
      await _users.doc(professor.uid).set(professor.toMap());
    } catch (e) {
      throw mapFirestoreError(e, recurso: 'Professor');
    }
  }

  Future<void> criarDemandante(Demandante demandante) async {
    try {
      await _users.doc(demandante.uid).set(demandante.toMap());
    } catch (e) {
      throw mapFirestoreError(e, recurso: 'Demandante');
    }
  }

  // ! ===========================
  // ! UC23 - EDITAR PERFIL
  // ! ===========================

  Future<void> atualizarDemandante({
    required String uid,
    required String nome,
    required String telefone,
    required TipoDemandante tipo,
    required String endereco,
  }) async {
    try {
      await _users.doc(uid).update({
        'nome': nome.trim(),
        'telefone': telefone.replaceAll(RegExp(r'\D'), ''),
        'tipo': tipo.name,
        'endereco': endereco.trim(),
      });
    } catch (e) {
      throw mapFirestoreError(e, recurso: 'Perfil');
    }
  }

  Future<void> atualizarProfessor({
    required String uid,
    required String nome,
    required List<String> areasTecnicas,
    required List<String> areasInteresse,
  }) async {
    try {
      await _users.doc(uid).update({
        'nome': nome.trim(),
        'areasTecnicas': areasTecnicas,
        'areasInteresse': areasInteresse,
      });
    } catch (e) {
      throw mapFirestoreError(e, recurso: 'Perfil');
    }
  }

  Future<void> atualizarFotoUrl({
    required String uid,
    required String fotoUrl,
  }) async {
    try {
      await _users.doc(uid).update({'fotoUrl': fotoUrl});
    } catch (e) {
      throw mapFirestoreError(e, recurso: 'Foto de perfil');
    }
  }

  /// Cria perfil de administrador automaticamente no primeiro acesso.
  /// Retorna o objeto criado (evita refetch posterior).
  Future<Administrador> criarAdministradorAutomatico({
    required String uid,
    required String email,
    required String nome,
  }) async {
    try {
      final admin = Administrador(
        uid: uid,
        email: email,
        nome: nome,
        criadoEm: DateTime.now(),
      );
      await _users.doc(uid).set(admin.toMap());
      return admin;
    } catch (e) {
      throw mapFirestoreError(e, recurso: 'Administrador');
    }
  }
}

extension _IterableFirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
