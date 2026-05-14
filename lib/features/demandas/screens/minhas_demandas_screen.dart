import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../providers/demanda_form_provider.dart';
import '../providers/demandas_provider.dart';
import '../widgets/demanda_card.dart';
import '../widgets/filtros_bottom_sheet.dart';
import 'demanda_detalhes_screen.dart';
import 'demanda_form_screen.dart';

class MinhasDemandasScreen extends StatefulWidget {
  const MinhasDemandasScreen({super.key});

  @override
  State<MinhasDemandasScreen> createState() => _MinhasDemandasScreenState();
}

class _MinhasDemandasScreenState extends State<MinhasDemandasScreen> {
  final _buscaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final uid = auth.usuario?.uid;
      if (uid != null) {
        context.read<DemandasProvider>().observar(uid);
      }
    });
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  void _abrirFiltros() {
    final demandas = context.read<DemandasProvider>();
    FiltrosBottomSheet.mostrar(
      context,
      statusInicial: demandas.filtroStatus,
      periodoInicial: demandas.filtroPeriodo,
      onAplicar: (status, periodo) {
        demandas.aplicarFiltros(status: status, periodo: periodo);
      },
      onLimpar: demandas.limparFiltros,
    );
  }

  void _abrirDetalhes(String id) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DemandaDetalhesScreen(demandaId: id)),
    );
  }

  void _abrirNovaDemanda() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const DemandaFormScreen(modo: DemandaFormModo.criar),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildBuscaEFiltro(),
            Expanded(child: _buildLista()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: _abrirNovaDemanda,
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
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

  Widget _buildBuscaEFiltro() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _buscaController,
              decoration: InputDecoration(
                hintText: 'Buscar demandas por nome...',
                prefixIcon:
                    const Icon(Icons.search, color: AppColors.textSecondary),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              onChanged: (txt) =>
                  context.read<DemandasProvider>().atualizarBusca(txt),
            ),
          ),
          const SizedBox(width: 12),
          Consumer<DemandasProvider>(
            builder: (_, p, __) => _BotaoFiltro(
              filtrosAtivos: p.filtrosAtivos,
              onTap: _abrirFiltros,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLista() {
    return Consumer<DemandasProvider>(
      builder: (context, provider, _) {
        if (provider.carregando && provider.demandas.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.erro != null) {
          return _Estado(
            icone: Icons.error_outline,
            titulo: 'Erro ao carregar',
            mensagem: provider.erro!,
            acao: ElevatedButton(
              onPressed: () {
                final uid = context.read<AuthProvider>().usuario?.uid;
                if (uid != null) provider.observar(uid);
              },
              child: const Text('Tentar novamente'),
            ),
          );
        }

        final demandas = provider.demandas;
        if (demandas.isEmpty) {
          final temFiltro =
              provider.temFiltrosAtivos || provider.busca.isNotEmpty;
          return _Estado(
            icone: temFiltro ? Icons.filter_list_off : Icons.inbox_outlined,
            titulo: temFiltro
                ? 'Nenhuma demanda encontrada'
                : 'Você ainda não criou demandas',
            mensagem: temFiltro
                ? 'Tente ajustar os filtros ou a busca'
                : 'Toque no botão + para criar sua primeira demanda',
            acao: temFiltro
                ? TextButton(
                    onPressed: provider.limparFiltros,
                    child: const Text('Limpar filtros'),
                  )
                : null,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
          itemCount: demandas.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => DemandaCard(
            demanda: demandas[i],
            onTap: () => _abrirDetalhes(demandas[i].id),
          ),
        );
      },
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            icon: const Icon(Icons.home_outlined,
                color: AppColors.primary, size: 28),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline,
                color: AppColors.primary, size: 28),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Chat — disponível em sprint futura')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline,
                color: AppColors.primary, size: 28),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Perfil — disponível em sprint futura')),
              );
            },
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

class _Estado extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String mensagem;
  final Widget? acao;

  const _Estado({
    required this.icone,
    required this.titulo,
    required this.mensagem,
    this.acao,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            if (acao != null) ...[
              const SizedBox(height: 16),
              acao!,
            ],
          ],
        ),
      ),
    );
  }
}
