import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import '../exceptions/app_exception.dart';
import '../models/demandante.dart';
import '../models/professor.dart';
import '../models/usuario.dart';
import '../repositories/usuario_repository.dart';
import '../services/auth_service.dart';

enum AuthStatus {
  initial,
  autenticando,
  naoAutenticado,
  autenticadoSemCadastro,
  autenticado,
  erro,
}

/// Estado de autenticação e do perfil do usuário logado.
///
/// **Por que o perfil é observado, e não lido uma vez:** decisões
/// administrativas (banir um demandante, desativar um professor) precisam
/// valer na sessão que já está aberta. Com uma leitura pontual, o usuário
/// seguiria operando com o perfil antigo até reabrir o app — exatamente o
/// intervalo em que a suspensão deveria estar valendo.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final UsuarioRepository _usuarioRepository;

  AuthProvider({
    AuthService? authService,
    UsuarioRepository? usuarioRepository,
  })  : _authService = authService ?? AuthService(),
        _usuarioRepository = usuarioRepository ?? UsuarioRepository() {
    _init();
  }

  AuthStatus _status = AuthStatus.initial;
  Usuario? _usuario;
  User? _firebaseUser;
  String? _erro;

  StreamSubscription<User?>? _subAuth;
  StreamSubscription<Usuario?>? _subUsuario;

  /// Trava de reentrância da criação automática do admin. Sem ela, o próprio
  /// `set()` reemite o snapshot e a criação dispara de novo antes de o
  /// documento aparecer no stream.
  bool _criandoAdmin = false;

  AuthStatus get status => _status;
  Usuario? get usuario => _usuario;
  User? get firebaseUser => _firebaseUser;
  String? get erro => _erro;

  /// Demandante com a conta suspensa por acúmulo de strikes.
  /// O roteador troca o app inteiro por uma tela de bloqueio quando isso é
  /// verdade — não basta esconder botões.
  bool get contaBanida {
    final u = _usuario;
    return u is Demandante && u.banido;
  }

  /// Professor com o perfil desligado pela administração (UC04 R01).
  bool get professorInativo {
    final u = _usuario;
    return u is Professor && !u.ativo;
  }

  bool get isProfessorEmail {
    final email = _firebaseUser?.email?.toLowerCase();
    if (email == null) return false;
    if (email.endsWith('@${AppConstants.professorEmailDomain}')) return true;
    // ===== INÍCIO — E-MAIL DE TESTE (PROFESSOR) — REMOVER ANTES DE PRODUÇÃO =====
    // Allowlist de teste: trata e-mails pessoais como professor.
    // Lista definida em AppConstants.professorTestEmails.
    return AppConstants.professorTestEmails
        .map((e) => e.toLowerCase())
        .contains(email);
    // ===== FIM — E-MAIL DE TESTE (PROFESSOR) =====
  }

  bool get isAdminEmail {
    final email = _firebaseUser?.email?.toLowerCase();
    if (email == null) return false;
    return AppConstants.adminEmails.map((e) => e.toLowerCase()).contains(email);
  }

  void _init() {
    _subAuth = _authService.authStateChanges.listen(_onAuthChanged);
  }

  Future<void> _onAuthChanged(User? user) async {
    _firebaseUser = user;
    await _subUsuario?.cancel();
    _subUsuario = null;
    _criandoAdmin = false;

    if (user == null) {
      _status = AuthStatus.naoAutenticado;
      _usuario = null;
      _erro = null;
      notifyListeners();
      return;
    }

    _subUsuario = _usuarioRepository.observarPorUid(user.uid).listen(
          _onPerfilChanged,
          onError: _onPerfilErro,
        );
  }

  void _onPerfilChanged(Usuario? cadastro) {
    if (cadastro != null) {
      _usuario = cadastro;
      _status = AuthStatus.autenticado;
      _erro = null;
      _criandoAdmin = false;
      notifyListeners();
      return;
    }

    // Não há cadastro ainda.
    final user = _firebaseUser;
    if (user != null && isAdminEmail) {
      // Primeiro acesso de admin: perfil criado automaticamente. O stream
      // reemite com o documento pronto e cai no ramo de cima.
      if (!_criandoAdmin) {
        _criandoAdmin = true;
        unawaited(_criarAdmin(user));
      }
      return;
    }

    // Professor ou demandante: precisa preencher o cadastro.
    _usuario = null;
    _status = AuthStatus.autenticadoSemCadastro;
    _erro = null;
    notifyListeners();
  }

  Future<void> _criarAdmin(User user) async {
    try {
      await _usuarioRepository.criarAdministradorAutomatico(
        uid: user.uid,
        email: user.email!,
        nome: user.displayName ?? user.email!.split('@').first,
      );
      // O objeto criado não é atribuído aqui de propósito: o stream do perfil
      // entrega a versão canônica do documento logo em seguida, e usar as duas
      // fontes abriria espaço para divergência.
    } catch (e) {
      _criandoAdmin = false;
      _onPerfilErro(e);
    }
  }

  void _onPerfilErro(Object e) {
    _erro = e is AppException ? e.message : 'Erro inesperado ao carregar perfil.';
    _status = AuthStatus.erro;
    notifyListeners();
  }

  Future<void> entrarComGoogle() async {
    try {
      _status = AuthStatus.autenticando;
      _erro = null;
      notifyListeners();

      final user = await _authService.signInWithGoogle();
      if (user == null) {
        _status = AuthStatus.naoAutenticado;
        notifyListeners();
      }
      // Sucesso: _onAuthChanged é chamado pelo stream
    } catch (e) {
      _erro = 'Falha ao autenticar. Tente novamente.';
      _status = AuthStatus.erro;
      notifyListeners();
    }
  }

  Future<void> sair() async {
    await _subUsuario?.cancel();
    _subUsuario = null;
    await _authService.signOut();
  }

  /// Reassina o perfil.
  ///
  /// Com o stream em pé, o app já reflete qualquer mudança sozinho — as telas
  /// de cadastro e edição continuam chamando isto por clareza de intenção
  /// ("acabei de gravar, quero o perfil atualizado") e para cobrir o caso em
  /// que a inscrição caiu por erro de rede.
  Future<void> recarregarUsuario() async {
    final user = _firebaseUser;
    if (user == null) return;
    await _onAuthChanged(user);
  }

  @override
  void dispose() {
    _subAuth?.cancel();
    _subUsuario?.cancel();
    super.dispose();
  }
}
