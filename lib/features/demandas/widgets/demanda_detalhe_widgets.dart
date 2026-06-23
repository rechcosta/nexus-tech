import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Peças de apresentação reutilizáveis da tela de detalhes de uma demanda.
///
/// Extraídas para evitar duplicação entre a visão do demandante e a do
/// professor (Sprint 3). A visão do demandante mantém suas versões privadas
/// por ora; uma unificação completa pode vir num cleanup futuro.

/// Bloco "título + parágrafo" com divisória superior, usado nas seções
/// (Descrição, Público-alvo, Impacto, Solução entregue...).
class SecaoTexto extends StatelessWidget {
  final String titulo;
  final String conteudo;

  const SecaoTexto({super.key, required this.titulo, required this.conteudo});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            conteudo,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade800,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// Caixa destacada para avisos contextuais (motivo de cancelamento,
/// "em análise por você até...", solução entregue em destaque, etc).
class BlocoInfo extends StatelessWidget {
  final Color cor;
  final String titulo;
  final String conteudo;
  final IconData? icone;

  const BlocoInfo({
    super.key,
    required this.cor,
    required this.titulo,
    required this.conteudo,
    this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icone != null) ...[
                Icon(icone, size: 18, color: cor),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: cor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            conteudo,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip arredondado com o tipo do demandante.
class ChipTipoDemandante extends StatelessWidget {
  final String tipo;
  const ChipTipoDemandante({super.key, required this.tipo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.success,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        tipo,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Cabeçalho padrão das telas internas: logo + "Nexus Tech" + link "Voltar".
class DetalheHeader extends StatelessWidget {
  final VoidCallback? onVoltar;
  const DetalheHeader({super.key, this.onVoltar});

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
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: onVoltar ?? () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Voltar',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
