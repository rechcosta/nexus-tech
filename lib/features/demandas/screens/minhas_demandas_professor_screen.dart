import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../providers/professor_demandas_provider.dart';
import '../widgets/demanda_card.dart';
import '../widgets/estado_lista.dart';
import '../widgets/filtros_bottom_sheet.dart';
import 'demanda_detalhes_professor_screen.dart';

/// "Minhas Demandas" do professor: tudo que está atribuído a ele
/// (em análise, em produção, concluída). Reaproveita o card e o bottom sheet
/// de filtros já existentes.
class MinhasDemandasProfessorScreen extends StatelessWidget {
  const MinhasDemandasProfessorScreen({super.key});

  void _abrirFiltros(BuildContext context) {
    final p = context.read<ProfessorDemandasProvider>();
    FiltrosBottomSheet.mostrar(
      context,
      statusInicial: p.filtroStatus,
      periodoInicial: p.filtroPeriodo,
      onAplicar: (status, periodo) =>
          p.aplicarFiltrosMinhas(status: status, periodo: periodo),
      onLimpar: p.limparFiltrosMinhas,
    );
  }

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
        const _Header(),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Row(
            children: [
              Expanded(
                child: BarraBusca(
                  hint: 'Buscar nas minhas demandas...',
                  onChanged: (txt) => context
                      .read<ProfessorDemandasProvider>()
                      .atualizarBuscaMinhas(txt),
                ),
              ),
              const SizedBox(width: 12),
              Consumer<ProfessorDemandasProvider>(
                builder: (_, p, __) => _BotaoFiltro(
                  filtrosAtivos: p.filtrosAtivos,
                  onTap: () => _abrirFiltros(context),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Consumer<ProfessorDemandasProvider>(
            builder: (context, p, _) {
              if (p.carregandoMinhas && p.minhas.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (p.erroMinhas != null) {
                return EstadoLista(
                  icone: Icons.error_outline,
                  titulo: 'Erro ao carregar',
                  mensagem: p.erroMinhas!,
                );
              }
              final demandas = p.minhas;
              if (demandas.isEmpty) {
                final filtrando =
                    p.temFiltrosAtivos || p.buscaMinhas.isNotEmpty;
                return EstadoLista(
                  icone:
                      filtrando ? Icons.filter_list_off : Icons.folder_outlined,
                  titulo: filtrando
                      ? 'Nenhuma demanda encontrada'
                      : 'Você ainda não pegou demandas',
                  mensagem: filtrando
                      ? 'Tente ajustar os filtros ou a busca'
                      : 'Marque uma demanda da prateleira para análise',
                  acao: filtrando
                      ? TextButton(
                          onPressed: p.limparFiltrosMinhas,
                          child: const Text('Limpar filtros'),
                        )
                      : null,
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
  const _Header();

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
              IconButton(
                icon: const Icon(Icons.logout, color: AppColors.primary),
                tooltip: 'Sair',
                onPressed: () => context.read<AuthProvider>().sair(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Minhas\nDemandas',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _BotaoFiltro extends StatelessWidget {
  final int filtrosAtivos;
  final VoidCallback onTap;

  const _BotaoFiltro({required this.filtrosAtivos, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Material(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.filter_alt_outlined,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        if (filtrosAtivos > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                '$filtrosAtivos',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
