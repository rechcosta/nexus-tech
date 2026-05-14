/// Validadores de formulário com algoritmos reais de CPF/CNPJ
/// (módulo 11) e validação de DDDs brasileiros.
class Validators {
  // ! ============== CAMPOS BÁSICOS ==============

  static String? required(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName é obrigatório';
    }
    return null;
  }

  static String? nome(String? value) {
    final base = required(value, 'Nome');
    if (base != null) return base;

    final trimmed = value!.trim();

    if (trimmed.length < 3) return 'Nome muito curto';

    // Não pode ser só números
    if (RegExp(r'^\d+$').hasMatch(trimmed)) {
      return 'Nome inválido';
    }

    // Precisa ter pelo menos um espaço (nome + sobrenome)
    if (!trimmed.contains(' ')) {
      return 'Informe nome e sobrenome';
    }

    // Cada parte do nome precisa ter pelo menos 2 caracteres
    final partes = trimmed.split(RegExp(r'\s+'));
    if (partes.any((p) => p.length < 2)) {
      return 'Nome inválido';
    }

    // Apenas letras (incluindo acentos), espaços, hífen e apóstrofo
    if (!RegExp(r"^[a-zA-ZÀ-ÿ\s'\-]+$").hasMatch(trimmed)) {
      return 'Nome contém caracteres inválidos';
    }

    return null;
  }

  // ! ============== TELEFONE ==============

  /// Lista de DDDs válidos no Brasil conforme Anatel.
  static const Set<int> _dddsValidos = {
    11, 12, 13, 14, 15, 16, 17, 18, 19, // SP
    21, 22, 24, // RJ
    27, 28, // ES
    31, 32, 33, 34, 35, 37, 38, // MG
    41, 42, 43, 44, 45, 46, // PR
    47, 48, 49, // SC
    51, 53, 54, 55, // RS
    61, // DF
    62, 64, // GO
    63, // TO
    65, 66, // MT
    67, // MS
    68, // AC
    69, // RO
    71, 73, 74, 75, 77, // BA
    79, // SE
    81, 87, // PE
    82, // AL
    83, // PB
    84, // RN
    85, 88, // CE
    86, 89, // PI
    91, 93, 94, // PA
    92, 97, // AM
    95, // RR
    96, // AP
    98, 99, // MA
  };

  static String? telefone(String? value) {
    final base = required(value, 'Telefone');
    if (base != null) return base;

    final digits = value!.replaceAll(RegExp(r'\D'), '');

    if (digits.length != 10 && digits.length != 11) {
      return 'Telefone deve ter 10 ou 11 dígitos';
    }

    final ddd = int.tryParse(digits.substring(0, 2));
    if (ddd == null || !_dddsValidos.contains(ddd)) {
      return 'DDD inválido';
    }

    // Celular (11 dígitos): o terceiro dígito deve ser 9
    if (digits.length == 11 && digits[2] != '9') {
      return 'Celular deve começar com 9 após o DDD';
    }

    // Fixo (10 dígitos): o terceiro dígito não pode ser 0 ou 1
    if (digits.length == 10) {
      final terceiro = int.parse(digits[2]);
      if (terceiro == 0 || terceiro == 1) {
        return 'Telefone fixo inválido';
      }
    }

    return null;
  }

  // ! ============== SIAPE ==============

  static String? siape(String? value) {
    final base = required(value, 'SIAPE');
    if (base != null) return base;
    final digits = value!.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 7) return 'SIAPE deve ter 7 dígitos';
    return null;
  }

  // !============== CPF / CNPJ ==============

  static String? cpfCnpj(String? value) {
    final base = required(value, 'CPF/CNPJ');
    if (base != null) return base;

    final digits = value!.replaceAll(RegExp(r'\D'), '');

    if (digits.length == 11) {
      return _validarCpf(digits);
    } else if (digits.length == 14) {
      return _validarCnpj(digits);
    } else {
      return 'Digite um CPF (11 dígitos) ou CNPJ (14 dígitos)';
    }
  }

  /// Algoritmo oficial da Receita Federal para validação de CPF.
  /// Usa módulo 11 com pesos decrescentes para calcular dois dígitos
  /// verificadores.
  static String? _validarCpf(String cpf) {
    // Rejeita sequências repetidas (11111111111, 22222222222, etc.)
    if (RegExp(r'^(\d)\1+$').hasMatch(cpf)) {
      return 'CPF inválido';
    }

    // Primeiro dígito verificador
    var soma = 0;
    for (var i = 0; i < 9; i++) {
      soma += int.parse(cpf[i]) * (10 - i);
    }
    var resto = soma % 11;
    final dv1 = resto < 2 ? 0 : 11 - resto;
    if (int.parse(cpf[9]) != dv1) return 'CPF inválido';

    // Segundo dígito verificador
    soma = 0;
    for (var i = 0; i < 10; i++) {
      soma += int.parse(cpf[i]) * (11 - i);
    }
    resto = soma % 11;
    final dv2 = resto < 2 ? 0 : 11 - resto;
    if (int.parse(cpf[10]) != dv2) return 'CPF inválido';

    return null;
  }

  /// Algoritmo oficial da Receita Federal para validação de CNPJ.
  /// Usa módulo 11 com pesos específicos para calcular dois dígitos
  /// verificadores.
  static String? _validarCnpj(String cnpj) {
    if (RegExp(r'^(\d)\1+$').hasMatch(cnpj)) {
      return 'CNPJ inválido';
    }

    // Primeiro dígito verificador
    const pesos1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
    var soma = 0;
    for (var i = 0; i < 12; i++) {
      soma += int.parse(cnpj[i]) * pesos1[i];
    }
    var resto = soma % 11;
    final dv1 = resto < 2 ? 0 : 11 - resto;
    if (int.parse(cnpj[12]) != dv1) return 'CNPJ inválido';

    // Segundo dígito verificador
    const pesos2 = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
    soma = 0;
    for (var i = 0; i < 13; i++) {
      soma += int.parse(cnpj[i]) * pesos2[i];
    }
    resto = soma % 11;
    final dv2 = resto < 2 ? 0 : 11 - resto;
    if (int.parse(cnpj[13]) != dv2) return 'CNPJ inválido';

    return null;
  }

  // ! ============== ENDEREÇO ==============

  static String? endereco(String? value) {
    final base = required(value, 'Endereço');
    if (base != null) return base;
    if (value!.trim().length < 10) {
      return 'Informe rua, número e bairro';
    }
    return null;
  }
}
