import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../perfil/screens/perfil_screen.dart';
import '../../../app/theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../providers/professor_demandas_provider.dart';
import 'minhas_demandas_professor_screen.dart';
import 'prateleira_screen.dart';

/// Casca da área do professor. Mantém as duas abas (Prateleira e Minhas
/// Demandas) vivas via [IndexedStack] para preservar scroll e estado ao
/// alternar, e dispara a observação dos streams uma única vez.
class ProfessorHomeScreen extends StatefulWidget {
  const ProfessorHomeScreen({super.key});

  @override
  State<ProfessorHomeScreen> createState() => _ProfessorHomeScreenState();
}

class _ProfessorHomeScreenState extends State<ProfessorHomeScreen> {
  int _aba = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthProvider>().usuario?.uid;
      if (uid != null) {
        context.read<ProfessorDemandasProvider>().observar(uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _aba,
          children: const [
            PrateleiraScreen(),
            MinhasDemandasProfessorScreen(),
            PerfilScreen(comoAba: true), // UC23 — perfil do professor
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _aba,
        onDestinationSelected: (i) => setState(() => _aba = i),
        backgroundColor: AppColors.background,
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront, color: AppColors.primary),
            label: 'Prateleira',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder, color: AppColors.primary),
            label: 'Minhas Demandas',
          ),
          // no NavigationBar > destinations, adicione a 3ª:
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppColors.primary),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
