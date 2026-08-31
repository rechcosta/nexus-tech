import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../providers/notificacoes_provider.dart';
import '../screens/notificacoes_screen.dart';

/// Sino com contador de não lidas. Vai no cabeçalho das telas raiz dos três
/// papéis, sempre no mesmo lugar, para que "onde vejo meus avisos" seja uma
/// pergunta respondida uma vez só.
class SinoNotificacoes extends StatelessWidget {
  /// Cor do ícone — o cabeçalho do admin usa fundo escuro em algumas telas.
  final Color cor;

  const SinoNotificacoes({super.key, this.cor = AppColors.primary});

  @override
  Widget build(BuildContext context) {
    final naoLidas = context.watch<NotificacoesProvider>().naoLidas;

    return IconButton(
      tooltip: 'Notificações',
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const NotificacoesScreen()),
      ),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            naoLidas > 0 ? Icons.notifications : Icons.notifications_outlined,
            color: cor,
          ),
          if (naoLidas > 0)
            Positioned(
              right: -6,
              top: -4,
              child: ContadorBadge(valor: naoLidas),
            ),
        ],
      ),
    );
  }
}

/// Pastilha vermelha com o contador. Extraída porque a barra inferior também
/// a usa (mensagens não lidas na aba de conversas).
class ContadorBadge extends StatelessWidget {
  final int valor;

  const ContadorBadge({super.key, required this.valor});

  @override
  Widget build(BuildContext context) {
    // Acima de 99 o número deixa de ser informação e vira ruído visual.
    final texto = valor > 99 ? '99+' : '$valor';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      constraints: const BoxConstraints(minWidth: 18),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.background, width: 1.5),
      ),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          height: 1.2,
        ),
      ),
    );
  }
}
