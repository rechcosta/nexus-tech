import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/enums.dart';
import '../core/providers/auth_provider.dart';
import '../features/auth/screens/cadastro_demandante_screen.dart';
import '../features/auth/screens/cadastro_professor_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/demandas/screens/minhas_demandas_screen.dart';
import '../features/demandas/screens/professor_home_screen.dart';

class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

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
    final role = auth.usuario?.role;
    return switch (role) {
      UserRole.demandante => const MinhasDemandasScreen(),
      UserRole.professor => const ProfessorHomeScreen(),
      UserRole.administrador => const _PlaceholderAdmin(),
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

/// TODO(sprint-?): painel administrativo
class _PlaceholderAdmin extends StatelessWidget {
  const _PlaceholderAdmin();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nexus Tech — Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().sair(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.admin_panel_settings,
                  size: 64, color: Colors.green),
              const SizedBox(height: 16),
              Text(
                'Bem-vindo, ${auth.usuario?.nome ?? ""}',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Painel administrativo — Sprint futura',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
