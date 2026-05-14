import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/models/demanda.dart';

/// Bottom sheet de filtros. Decisão UX: bottom sheet em vez de dialog
/// porque (a) tem mais espaço vertical, (b) padrão mobile, (c) não cobre
/// totalmente a lista, mantendo contexto visual.
class FiltrosBottomSheet extends StatefulWidget {
  final StatusDemanda? statusInicial;
  final FiltroPeriodo? periodoInicial;
  final void Function(StatusDemanda? status, FiltroPeriodo? periodo) onAplicar;
  final VoidCallback onLimpar;

  const FiltrosBottomSheet({
    super.key,
    required this.statusInicial,
    required this.periodoInicial,
    required this.onAplicar,
    required this.onLimpar,
  });

  static Future<void> mostrar(
    BuildContext context, {
    required StatusDemanda? statusInicial,
    required FiltroPeriodo? periodoInicial,
    required void Function(StatusDemanda? status, FiltroPeriodo? periodo)
        onAplicar,
    required VoidCallback onLimpar,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FiltrosBottomSheet(
        statusInicial: statusInicial,
        periodoInicial: periodoInicial,
        onAplicar: onAplicar,
        onLimpar: onLimpar,
      ),
    );
  }

  @override
  State<FiltrosBottomSheet> createState() => _FiltrosBottomSheetState();
}

class _FiltrosBottomSheetState extends State<FiltrosBottomSheet> {
  late StatusDemanda? _status;
  late FiltroPeriodo? _periodo;

  @override
  void initState() {
    super.initState();
    _status = widget.statusInicial;
    _periodo = widget.periodoInicial;
  }

  int get _totalFiltros {
    var n = 0;
    if (_status != null) n++;
    if (_periodo != null) n++;
    return n;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                const Text(
                  'Filtros',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  color: AppColors.textSecondary,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 24),

            // ============== STATUS ==============
            _SecaoFiltro(
              titulo: 'Status',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: StatusDemanda.values.map((s) {
                  final selecionado = _status == s;
                  return _ChipFiltro(
                    label: s.label,
                    selecionado: selecionado,
                    onTap: () => setState(
                      () => _status = selecionado ? null : s,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // ============== PERÍODO ==============
            _SecaoFiltro(
              titulo: 'Período',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: FiltroPeriodo.values.map((p) {
                  final selecionado = _periodo == p;
                  return _ChipFiltro(
                    label: p.label,
                    selecionado: selecionado,
                    onTap: () => setState(
                      () => _periodo = selecionado ? null : p,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 32),

            // ============== AÇÕES ==============
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _status = null;
                        _periodo = null;
                      });
                      widget.onLimpar();
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(color: Colors.grey.shade300),
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Limpar filtros'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onAplicar(_status, _periodo);
                      Navigator.pop(context);
                    },
                    child: Text(
                      _totalFiltros == 0
                          ? 'Aplicar'
                          : 'Aplicar ($_totalFiltros)',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SecaoFiltro extends StatelessWidget {
  final String titulo;
  final Widget child;

  const _SecaoFiltro({required this.titulo, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _ChipFiltro extends StatelessWidget {
  final String label;
  final bool selecionado;
  final VoidCallback onTap;

  const _ChipFiltro({
    required this.label,
    required this.selecionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selecionado ? AppColors.primary : Colors.grey.shade100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              color: selecionado ? Colors.white : AppColors.textPrimary,
              fontWeight: selecionado ? FontWeight.w600 : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
