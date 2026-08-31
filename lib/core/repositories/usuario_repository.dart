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
      return _desserializar(doc.data());
    } catch (e) {
      throw mapFirestoreError(e, recurso: 'Usuário');
    }
  }

  /// Observa o próprio perfil em tempo real.
  ///
  /// Existe para que decisões administrativas cheguem **na sessão aberta**:
  /// quando o admin bane um demandante ou desativa um professor, o app precisa
  /// reagir sem esperar um novo login. Com uma leitura pontual, o usuário
  /// continuaria operando com o perfil antigo até fechar o app.
  ///
  /// Emite `null` quando o documento não existe (primeiro acesso, antes do
  /// cadastro) ou quando o `role` está ausente/corrompido — ambos os casos são
  /// tratados como "precisa cadastrar".
  Stream<Usuario?> observarPorUid(String uid) {
    return _users.doc(uid).snapshots().map((doc) => _desserializar(doc.data()));
  }

  /// Instancia a subclasse certa a partir do `role` gravado.
  /// `null` para documento inexistente ou com role inválido.
  Usuario? _desserializar(Map<String, dynamic>? data) {
    if (data == null) return null;

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
  }

  /// Uids dos administradores cadastrados — destinatários das denúncias.
  ///
  /// Lê da coleção em vez de derivar de `AppConstants.adminEmails` porque a
  /// notificação precisa de **uid**, e o e-mail só vira uid depois do primeiro
  /// login do admin. Um admin que nunca entrou no app não recebe notificação
  /// in-app — ele verá a fila de denúncias assim que entrar.
  ///
  /// Best-effort: falhar aqui não pode impedir o registro da denúncia.
  Future<Set<String>> buscarAdminUids() async {
    try {
      final snap = await _users
          .where('role', isEqualTo: UserRole.administrador.name)
          .get();
      return snap.docs.map((d) => d.id).toSet();
    } catch (_) {
      return const {};
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
