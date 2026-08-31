import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/enums.dart';
import '../core/providers/auth_provider.dart';
import '../features/admin/screens/admin_home_screen.dart';
import '../features/auth/screens/cadastro_demandante_screen.dart';
import '../features/auth/screens/cadastro_professor_screen.dart';
import '../features/auth/screens/conta_bloqueada_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/admin/providers/admin_provider.dart';
import '../features/chat/providers/chats_provider.dart';
import '../features/demandas/screens/minhas_demandas_screen.dart';
import '../features/demandas/screens/professor_home_screen.dart';
import '../features/notificacoes/providers/notificacoes_provider.dart';

/// Único ponto de decisão de navegação do app: um `switch` sobre o estado de
/// autenticação e, dentro dele, sobre o papel do usuário.
///
/// Como o perfil é observado em tempo real (`AuthProvider`), uma decisão
/// administrativa — suspender um demandante, desativar um professor — troca a
/// tela na sessão aberta, sem exigir novo login.
class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  /// Uid da sessão renderizada por último. Serve para detectar troca de
  /// usuário (inclusive logout, quando vira `null`) e derrubar o estado que
  /// pertence à sessão anterior.
  String? _uidSessao;

  /// Descarta o estado dos providers com escopo de sessão.
  ///
  /// Sem isso, dois problemas reais: o próximo usuário do aparelho veria por
  /// um instante os badges do usuário anterior, e os streams do painel
  /// administrativo continuariam abertos sob uma conta sem permissão,
  /// colhendo `permission-denied` a cada snapshot.
  ///
  /// Roda fora do `build` — mexer em provider durante a construção da árvore
  /// dispara `setState() during build`.
  void _sincronizarSessao(String? uid) {
    if (uid == _uidSessao) return;
    _uidSessao = uid;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NotificacoesProvider>().limpar();
      context.read<ChatsProvider>().limpar();
      context.read<AdminProvider>().limpar();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    _sincronizarSessao(auth.usuario?.uid);

    return switch (auth.status) {
      AuthStatus.initial || AuthStatus.autenticando => const _LoadingScreen(),
      AuthStatus.naoAutenticado || AuthStatus.erro => const LoginScreen(),
      AuthStatus.autenticadoSemCadastro => auth.isProfessorEmail
          ? const CadastroProfessorScreen()
          : const CadastroDemandanteScreen(),
      AuthStatus.autenticado => _telaPorRole(auth),
    };
  }

  Widget _telaPorRole(AuthProvider auth) {
    // Bloqueios de conta vêm antes do papel: uma conta suspensa não tem área
    // de trabalho, tem uma explicação.
    if (auth.contaBanida || auth.professorInativo) {
      return const ContaBloqueadaScreen();
    }

    final role = auth.usuario?.role;
    return switch (role) {
      UserRole.demandante => const MinhasDemandasScreen(),
      UserRole.professor => const ProfessorHomeScreen(),
      UserRole.administrador => const AdminHomeScreen(),
      null => const _LoadingScreen(),
    };
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
