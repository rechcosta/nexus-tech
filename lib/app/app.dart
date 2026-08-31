import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/perfil/providers/perfil_provider.dart';
import '../core/providers/auth_provider.dart';
import '../features/auth/providers/cadastro_provider.dart';
import '../features/demandas/providers/acao_demanda_provider.dart';
import '../features/demandas/providers/demanda_form_provider.dart';
import '../features/demandas/providers/demandas_provider.dart';
import '../features/demandas/providers/professor_demandas_provider.dart';
import '../features/admin/providers/admin_provider.dart';
import '../features/chat/providers/chats_provider.dart';
import '../features/notificacoes/providers/notificacoes_provider.dart';
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
        ChangeNotifierProvider(create: (_) => PerfilProvider()),
        // Sprint 4 — comunicação, avisos e moderação (UC11 R03, UC-admin).
        // Globais porque alimentam badges que precisam existir em qualquer
        // aba, não só na tela que os consome.
        ChangeNotifierProvider(create: (_) => NotificacoesProvider()),
        ChangeNotifierProvider(create: (_) => ChatsProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
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
