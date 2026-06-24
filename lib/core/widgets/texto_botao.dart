import 'package:flutter/material.dart';

/// Conteúdo de botão que nunca quebra linha nem trunca: encolhe via
/// [FittedBox] para caber em qualquer largura de tela. Use como `child:` de
/// `ElevatedButton`/`OutlinedButton`/`TextButton`.
///
/// Aceita um [icone] opcional, substituindo a necessidade do construtor
/// `.icon` (que não é responsivo por padrão).
class TextoBotao extends StatelessWidget {
  final String texto;
  final IconData? icone;

  const TextoBotao(this.texto, {super.key, this.icone});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[
            Icon(icone, size: 18),
            const SizedBox(width: 8),
          ],
          Text(texto, maxLines: 1, softWrap: false),
        ],
      ),
    );
  }
}
