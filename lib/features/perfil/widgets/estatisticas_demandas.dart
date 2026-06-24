import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Um indicador (valor + rótulo + cor/ícone) do painel de estatísticas.
typedef ItemEstatistica = ({
  String label,
  int? valor, // null = carregando
  Color cor,
  IconData icone,
});

/// Linha de cartões com os contadores de demandas por status.
/// Responsivo: cada cartão ocupa fração igual da largura e o número usa
/// FittedBox para não estourar em telas estreitas.
class EstatisticasDemandas extends StatelessWidget {
  final List<ItemEstatistica> itens;

  const EstatisticasDemandas({super.key, required this.itens});

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight dá uma altura definida ao Row para que o
    // CrossAxisAlignment.stretch funcione dentro de um ListView (que tem
    // altura ilimitada no eixo principal). Sem isso, o RenderFlex não é
    // dimensionado e a lista inteira falha ("RenderBox was not laid out").
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < itens.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: _Card(item: itens[i])),
          ],
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final ItemEstatistica item;
  const _Card({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: item.cor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: item.cor.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(item.icone, color: item.cor, size: 22),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              item.valor?.toString() ?? '—',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: item.cor,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              fontSize: 12,
              height: 1.15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
