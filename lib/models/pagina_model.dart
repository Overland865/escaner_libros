class PaginaModel {
  final int numeroPagina;
  final String nombreArchivo;
  final int conteoPalabras;
  final String texto;
  final double? confianza;
  final String? motor;

  PaginaModel({
    required this.numeroPagina,
    required this.nombreArchivo,
    required this.conteoPalabras,
    required this.texto,
    this.confianza,
    this.motor,
  });

  Map<String, dynamic> toJson() => {
        'numero_pagina': numeroPagina,
        'nombre_archivo': nombreArchivo,
        'conteo_palabras': conteoPalabras,
        'texto': texto,
        if (confianza != null) 'confianza': confianza,
        if (motor != null) 'motor_transcripcion': motor,
      };

  factory PaginaModel.fromJson(Map<String, dynamic> json) {
    final rawNumero = json['numero_pagina'] ?? json['numeroPagina'] ?? json['numero'];
    final rawConteo = json['conteo_palabras'] ?? json['conteoPalabras'];
    final texto = (json['texto'] ?? '').toString();

    return PaginaModel(
      numeroPagina: (rawNumero is num) ? rawNumero.toInt() : (int.tryParse('$rawNumero') ?? 1),
      nombreArchivo: (json['nombre_archivo'] ?? 'pagina.txt').toString(),
      conteoPalabras: (rawConteo is num)
          ? rawConteo.toInt()
          : texto.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length,
      texto: texto,
      confianza: (json['confianza'] as num?)?.toDouble(),
      motor: json['motor_transcripcion'] as String? ?? json['motor'] as String?,
    );
  }

  static int contarPalabras(String texto) {
    final t = texto.trim();
    if (t.isEmpty) return 0;
    return t.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
  }

  PaginaModel copyWith({
    int? numeroPagina,
    String? nombreArchivo,
    int? conteoPalabras,
    String? texto,
    double? confianza,
    String? motor,
  }) {
    final nuevoTexto = texto ?? this.texto;
    return PaginaModel(
      numeroPagina: numeroPagina ?? this.numeroPagina,
      nombreArchivo: nombreArchivo ?? this.nombreArchivo,
      conteoPalabras: conteoPalabras ?? (texto != null ? contarPalabras(nuevoTexto) : this.conteoPalabras),
      texto: nuevoTexto,
      confianza: confianza ?? this.confianza,
      motor: motor ?? this.motor,
    );
  }
}

