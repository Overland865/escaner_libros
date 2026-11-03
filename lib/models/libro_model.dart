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

    final ahora = DateTime.now().toUtc().toIso8601String();

    return {
      '_id': id,
      'isbn_o_codigo': isbnOCodigo,
      // Campos exigidos por el validador de la colección de Atlas:
      // titulo, autor, isbn, editorial, categorias, idioma, fecha_actualizacion.
      'isbn': isbnOCodigo,
      'titulo': titulo,
      'autor': autor,
      'editorial': editorial,
      'categorias': [tipoLibro],
      'anio_publicacion': anioInicio,
      'total_paginas': paginas.length,
      'fecha_actualizacion': ahora,
      'tipo_libro': tipoLibro,
      'periodo': {'anio_inicio': anioInicio, 'anio_fin': anioFin},
      'idioma': 'es',
      'categoria': 'Libro',
      'palabras_clave': palabrasClave,
      'caracteres_totales': totalCaracteres,
      'fecha_procesamiento': ahora,
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
    final periodo = json['periodo'] is Map ? (json['periodo'] as Map) : null;
    final anioInicio = (periodo?['anio_inicio'] as num?)?.toInt() ??
        (json['anio_publicacion'] as num?)?.toInt() ??
        1800;
    final anioFin = (periodo?['anio_fin'] as num?)?.toInt() ??
        (json['anio_publicacion'] as num?)?.toInt() ??
        1900;

    final rawPaginas = json['paginas'] as List?;
    final List<PaginaModel> listaPaginas = [];
    if (rawPaginas != null) {
      for (final p in rawPaginas) {
        if (p is Map) {
          listaPaginas.add(PaginaModel.fromJson(Map<String, dynamic>.from(p)));
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
      id: json['_id']?.toString() ?? json['isbn_o_codigo']?.toString() ?? '',
      isbnOCodigo:
          json['isbn_o_codigo']?.toString() ?? json['_id']?.toString() ?? '',
      titulo: json['titulo']?.toString() ?? 'Sin Título',
      autor: json['autor']?.toString() ?? '',
      editorial: json['editorial']?.toString() ?? '',
      tipoLibro: json['tipo_libro']?.toString() ?? 'General',
      anioInicio: anioInicio,
      anioFin: anioFin,
      palabrasClave: keywords,
      paginas: listaPaginas,
    );
  }
}
