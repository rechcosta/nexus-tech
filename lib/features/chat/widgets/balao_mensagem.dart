import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/models/chat.dart';

/// Uma mensagem na conversa.
///
/// Três formas distintas conforme a autoria, porque o olho precisa separá-las
/// sem ler: minha (verde, à direita), do outro (branca, à esquerda) e do
/// sistema (pílula cinza centralizada, sem autor).
class BalaoMensagem extends StatelessWidget {
  final Mensagem mensagem;
  final bool meu;

  /// `true` quando a mensagem anterior é do mesmo autor — o nome só aparece na
  /// primeira de uma sequência, para a conversa não virar uma lista de nomes.
  final bool agrupada;

  const BalaoMensagem({
    super.key,
    required this.mensagem,
    required this.meu,
    this.agrupada = false,
  });

  @override
  Widget build(BuildContext context) {
    if (mensagem.sistema) return _sistema();

    final cor = Mensagem.corBalao(meu: meu, sistema: false);

    return Align(
      alignment: meu ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(top: agrupada ? 2 : 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: cor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(meu ? 16 : 4),
            bottomRight: Radius.circular(meu ? 4 : 16),
          ),
          border: meu ? null : Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment:
              meu ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!meu && !agrupada) ...[
              Text(
                mensagem.autorNome,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              mensagem.texto,
              style: TextStyle(
                fontSize: 15,
                height: 1.35,
                color: meu ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _hora(mensagem.enviadaEm),
              style: TextStyle(
                fontSize: 10,
                color: meu ? Colors.white70 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sistema() => Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              mensagem.texto,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Colors.grey.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      );

  String _hora(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// Separador de dia ("Hoje", "Ontem", "12/03/2026") entre blocos de mensagens.
class SeparadorDia extends StatelessWidget {
  final DateTime dia;

  const SeparadorDia({super.key, required this.dia});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.shade300)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _rotulo(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey.shade300)),
        ],
      ),
    );
  }

  String _rotulo() {
    final hoje = DateTime.now();
    final d = dia;
    if (d.year == hoje.year && d.month == hoje.month && d.day == hoje.day) {
      return 'Hoje';
    }
    final ontem = hoje.subtract(const Duration(days: 1));
    if (d.year == ontem.year && d.month == ontem.month && d.day == ontem.day) {
      return 'Ontem';
    }
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
