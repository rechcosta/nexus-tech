import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/providers/auth_provider.dart';
import '../features/auth/providers/cadastro_provider.dart';
import '../features/demandas/providers/acao_demanda_provider.dart';
import '../features/demandas/providers/demanda_form_provider.dart';
import '../features/demandas/providers/demandas_provider.dart';
import '../features/demandas/providers/professor_demandas_provider.dart';
import 'router.dart';
import 'theme.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CadastroProvider()),
        ChangeNotifierProvider(create: (_) => DemandasProvider()),
        ChangeNotifierProvider(create: (_) => DemandaFormProvider()),
        // Sprint 3 — área do professor (UC08–UC12)
        ChangeNotifierProvider(create: (_) => ProfessorDemandasProvider()),
        ChangeNotifierProvider(create: (_) => AcaoDemandaProvider()),
      ],
      child: MaterialApp(
        title: 'Nexus Tech',
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: const AppRouter(),
      ),
    );
  }
}
