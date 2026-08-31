import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../notificacoes/widgets/sino_notificacoes.dart';
import '../providers/professor_demandas_provider.dart';
import '../widgets/demanda_card.dart';
import '../widgets/estado_lista.dart';
import 'demanda_detalhes_professor_screen.dart';

/// UC08 — Prateleira pública de demandas disponíveis para o professor.
/// Exibe apenas `cadastrada` + `emProducao` (filtro server-side no
/// repositório). Busca por título/descrição é client-side.
class PrateleiraScreen extends StatelessWidget {
  const PrateleiraScreen({super.key});

  void _abrirDetalhes(BuildContext context, String id) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DemandaDetalhesProfessorScreen(demandaId: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Header(nome: context.watch<AuthProvider>().usuario?.nome ?? ''),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: BarraBusca(
            hint: 'Buscar por título ou descrição...',
            onChanged: (txt) => context
                .read<ProfessorDemandasProvider>()
                .atualizarBuscaPrateleira(txt),
          ),
        ),
        Expanded(
          child: Consumer<ProfessorDemandasProvider>(
            builder: (context, p, _) {
              if (p.carregandoPrateleira && p.prateleira.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (p.erroPrateleira != null) {
                return EstadoLista(
                  icone: Icons.error_outline,
                  titulo: 'Erro ao carregar',
                  mensagem: p.erroPrateleira!,
                );
              }
              final demandas = p.prateleira;
              if (demandas.isEmpty) {
                final buscando = p.buscaPrateleira.isNotEmpty;
                return EstadoLista(
                  icone: buscando ? Icons.search_off : Icons.inbox_outlined,
                  titulo: buscando
                      ? 'Nenhuma demanda encontrada'
                      : 'Nenhuma demanda disponível',
                  mensagem: buscando
                      ? 'Tente outros termos de busca'
                      : 'Quando demandantes publicarem, elas aparecem aqui',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                itemCount: demandas.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => DemandaCard(
                  demanda: demandas[i],
                  onTap: () => _abrirDetalhes(context, demandas[i].id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final String nome;
  const _Header({required this.nome});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset('assets/images/logo.png', width: 56, height: 56),
              const SizedBox(width: 12),
              const Text(
                'Nexus Tech',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              const SinoNotificacoes(),
              IconButton(
                icon: const Icon(Icons.logout, color: AppColors.primary),
                tooltip: 'Sair',
                onPressed: () => context.read<AuthProvider>().sair(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Prateleira',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Demandas disponíveis para análise',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}
