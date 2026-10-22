import 'pagina_model.dart';

class LibroModel {
  final String id;
  final String isbnOCodigo;
  final String titulo;
  final String autor;
  final String editorial;
  final String tipoLibro;
  final int anioInicio;
  final int anioFin;
  final List<String> palabrasClave;
  final List<PaginaModel> paginas;

  LibroModel({
    required this.id,
    required this.isbnOCodigo,
    required this.titulo,
    required this.autor,
    this.editorial = '',
    required this.tipoLibro,
    required this.anioInicio,
    required this.anioFin,
    required this.palabrasClave,
    required this.paginas,
  });

  Map<String, dynamic> toJson() {
    int totalCaracteres = paginas.fold(0, (sum, p) => sum + p.texto.length);

    return {
      '_id': id,
      'isbn_o_codigo': isbnOCodigo,
      'titulo': titulo,
      'autor': autor,
      if (editorial.isNotEmpty) 'editorial': editorial,
      'tipo_libro': tipoLibro,
      'periodo': {'anio_inicio': anioInicio, 'anio_fin': anioFin},
      'idioma': 'es',
      'categoria': 'Libro',
      'palabras_clave': palabrasClave,
      'caracteres_totales': totalCaracteres,
      'fecha_procesamiento': DateTime.now().toUtc().toIso8601String(),
      'capitulos': [
        {
          'numero': 1,
          'titulo': 'Sección Principal',
          'pagina_inicio': 1,
          'pagina_fin': paginas.length,
        },
      ],
      'paginas': paginas.map((p) => p.toJson()).toList(),
    };
  }

  factory LibroModel.fromJson(Map<String, dynamic> json) {
    final periodo = json['periodo'] as Map<String, dynamic>?;
    final anioInicio = periodo?['anio_inicio'] as int? ?? 1800;
    final anioFin = periodo?['anio_fin'] as int? ?? 1900;

    final rawPaginas = json['paginas'] as List?;
    final List<PaginaModel> listaPaginas = [];
    if (rawPaginas != null) {
      for (final p in rawPaginas) {
        if (p is Map<String, dynamic>) {
          listaPaginas.add(PaginaModel.fromJson(p));
        }
      }
    }

    final rawKeywords = json['palabras_clave'] as List?;
    final List<String> keywords = [];
    if (rawKeywords != null) {
      for (final k in rawKeywords) {
        if (k != null) keywords.add(k.toString());
      }
    }

    return LibroModel(
      id: json['_id'] as String? ?? json['isbn_o_codigo'] as String? ?? '',
      isbnOCodigo:
          json['isbn_o_codigo'] as String? ?? json['_id'] as String? ?? '',
      titulo: json['titulo'] as String? ?? 'Sin Título',
      autor: json['autor'] as String? ?? '',
      editorial: json['editorial'] as String? ?? '',
      tipoLibro: json['tipo_libro'] as String? ?? 'General',
      anioInicio: anioInicio,
      anioFin: anioFin,
      palabrasClave: keywords,
      paginas: listaPaginas,
    );
  }
}
