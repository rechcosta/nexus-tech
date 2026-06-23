import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import '../exceptions/app_exception.dart';
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

  AuthStatus get status => _status;
  Usuario? get usuario => _usuario;
  User? get firebaseUser => _firebaseUser;
  String? get erro => _erro;

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
    _authService.authStateChanges.listen(_onAuthChanged);
  }

  Future<void> _onAuthChanged(User? user) async {
    _firebaseUser = user;

    if (user == null) {
      _status = AuthStatus.naoAutenticado;
      _usuario = null;
      _erro = null;
      notifyListeners();
      return;
    }

    try {
      final cadastroExistente = await _usuarioRepository.buscarPorUid(user.uid);

      if (cadastroExistente != null) {
        _usuario = cadastroExistente;
        _status = AuthStatus.autenticado;
        _erro = null;
        notifyListeners();
        return;
      }

      // Primeiro acesso: admin é criado automaticamente
      if (isAdminEmail) {
        // * Otimização: usa o objeto retornado pela criação,
        // * evita segunda leitura no Firestore.
        final admin = await _usuarioRepository.criarAdministradorAutomatico(
          uid: user.uid,
          email: user.email!,
          nome: user.displayName ?? user.email!.split('@').first,
        );
        _usuario = admin;
        _status = AuthStatus.autenticado;
      } else {
        // Professor ou demandante: precisa preencher cadastro
        _status = AuthStatus.autenticadoSemCadastro;
        _usuario = null;
      }
      _erro = null;
    } on AppException catch (e) {
      _erro = e.message;
      _status = AuthStatus.erro;
    } catch (e) {
      _erro = 'Erro inesperado ao carregar perfil.';
      _status = AuthStatus.erro;
    }
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
    await _authService.signOut();
  }

  Future<void> recarregarUsuario() async {
    if (_firebaseUser != null) {
      await _onAuthChanged(_firebaseUser);
    }
  }
}
