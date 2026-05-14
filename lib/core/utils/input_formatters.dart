import 'package:flutter/services.dart';

/// Aplica máscara de telefone brasileiro conforme o usuário digita.
/// - 10 dígitos: (xx) xxxx-xxxx
/// - 11 dígitos: (xx) xxxxx-xxxx
class TelefoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    if (digits.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final buffer = StringBuffer();

    for (var i = 0; i < digits.length && i < 11; i++) {
      if (i == 0) buffer.write('(');
      if (i == 2) buffer.write(') ');
      // Posição do hífen muda conforme tamanho:
      // 10 dígitos: depois do 6º
      // 11 dígitos: depois do 7º
      if (digits.length <= 10 && i == 6) buffer.write('-');
      if (digits.length == 11 && i == 7) buffer.write('-');
      buffer.write(digits[i]);
    }

    final formatted = buffer.toString();

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Aplica máscara de CPF ou CNPJ conforme o usuário digita.
/// - Até 11 dígitos: xxx.xxx.xxx-xx
/// - 12+ dígitos: xx.xxx.xxx/xxxx-xx
class CpfCnpjInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    if (digits.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final buffer = StringBuffer();

    if (digits.length <= 11) {
      // Formato CPF: 000.000.000-00
      for (var i = 0; i < digits.length && i < 11; i++) {
        if (i == 3 || i == 6) buffer.write('.');
        if (i == 9) buffer.write('-');
        buffer.write(digits[i]);
      }
    } else {
      // Formato CNPJ: 00.000.000/0000-00
      for (var i = 0; i < digits.length && i < 14; i++) {
        if (i == 2 || i == 5) buffer.write('.');
        if (i == 8) buffer.write('/');
        if (i == 12) buffer.write('-');
        buffer.write(digits[i]);
      }
    }

    final formatted = buffer.toString();

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
