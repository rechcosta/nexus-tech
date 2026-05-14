import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme.dart';
import '../../../core/models/anexo.dart';

/// Lista os anexos de uma demanda em modo somente-leitura, com ação de abrir
/// o arquivo via URL pública do Firebase Storage.
///
/// Diferente de [AnexosSection] (form de edição), este widget NÃO permite
/// adicionar nem remover anexos — é a visualização pura para a tela de
/// detalhes (UC02 R02).
class AnexosVisualizacao extends StatelessWidget {
  final List<Anexo> anexos;

  const AnexosVisualizacao({super.key, required this.anexos});

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
          Row(
            children: [
              const Text(
                'Anexos',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${anexos.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (anexos.isEmpty)
            _vazio()
          else
            ...anexos.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AnexoTile(anexo: a),
              ),
            ),
        ],
      ),
    );
  }

  Widget _vazio() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.attach_file, color: Colors.grey.shade400, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Nenhum arquivo anexado',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ),
          ],
        ),
      );
}

class _AnexoTile extends StatefulWidget {
  final Anexo anexo;

  const _AnexoTile({required this.anexo});

  @override
  State<_AnexoTile> createState() => _AnexoTileState();
}

class _AnexoTileState extends State<_AnexoTile> {
  bool _abrindo = false;

  Future<void> _abrir() async {
    if (_abrindo) return;
    setState(() => _abrindo = true);

    try {
      final uri = Uri.tryParse(widget.anexo.url);
      if (uri == null) {
        _mostrarErro('URL do anexo inválida');
        return;
      }

      final lancou = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!lancou && mounted) {
        _mostrarErro('Não foi possível abrir o anexo');
      }
    } catch (_) {
      if (mounted) _mostrarErro('Erro ao abrir o anexo');
    } finally {
      if (mounted) setState(() => _abrindo = false);
    }
  }

  void _mostrarErro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _abrindo ? null : _abrir,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              _IconePorFormato(formato: widget.anexo.formato),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.anexo.nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.anexo.formato.toUpperCase()} · '
                      '${widget.anexo.tamanhoFormatado}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (_abrindo)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(Icons.open_in_new, size: 20, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconePorFormato extends StatelessWidget {
  final String formato;

  const _IconePorFormato({required this.formato});

  @override
  Widget build(BuildContext context) {
    final (icone, cor) = switch (formato.toLowerCase()) {
      'pdf' => (Icons.picture_as_pdf, Colors.red.shade700),
      'docx' || 'doc' => (Icons.description, Colors.blue.shade700),
      'jpg' || 'jpeg' || 'png' => (Icons.image, Colors.purple.shade600),
      _ => (Icons.insert_drive_file, Colors.grey.shade700),
    };

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icone, color: cor, size: 22),
    );
  }
}
