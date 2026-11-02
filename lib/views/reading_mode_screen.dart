import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/theme_controller.dart';
import '../models/libro_model.dart';
import '../models/pagina_model.dart';
import '../services/local_user_preferences_store.dart';

/// Modo lectura inmersivo — Implementa el diseño Stitch "Modo Lectura" (`e4e35d0c...`):
/// - Reanudación automática en la página donde se quedó el lector
/// - Encabezado de página con ornamento clásico `— ❦ —`
/// - Barra flotante de tinta de resaltado (sepia/ámbar/salvia)
/// - Pie de lectura con barra dorada de cantos de libro y controles de página.
class ReadingModeScreen extends StatefulWidget {
  final LibroModel libro;
  final String? idLibro;
  final int paginaInicial;

  const ReadingModeScreen({
    super.key,
    required this.libro,
    this.idLibro,
    this.paginaInicial = 0,
  });

  @override
  State<ReadingModeScreen> createState() => _ReadingModeScreenState();
}

class _TemaLectura {
  final String nombre;
  final IconData icono;
  final Color fondo;
  final Color texto;
  final Color barra;
  final Color acento;

  const _TemaLectura(
    this.nombre,
    this.icono,
    this.fondo,
    this.texto,
    this.barra,
    this.acento,
  );
}

class _ResultadoBusqueda {
  final int indicePagina;
  final int numeroPagina;
  final String fragmento;

  const _ResultadoBusqueda({
    required this.indicePagina,
    required this.numeroPagina,
    required this.fragmento,
  });
}

class _ReadingModeScreenState extends State<ReadingModeScreen> {
  static const _temas = [
    _TemaLectura(
      'Pergamino',
      Icons.menu_book_outlined,
      Color(0xFFFCF9F4),
      Color(0xFF1C1C19),
      Color(0xFFF6F3EE),
      Color(0xFF8C4E26),
    ),
    _TemaLectura(
      'Noche',
      Icons.dark_mode_outlined,
      Color(0xFF14110F),
      Color(0xFFEAE0D5),
      Color(0xFF211B18),
      Color(0xFFD4A373),
    ),
    _TemaLectura(
      'Sepia',
      Icons.wb_sunny_outlined,
      Color(0xFFF4ECD8),
      Color(0xFF2C1810),
      Color(0xFFEAE0C8),
      Color(0xFF8C4E26),
    ),
  ];

  static const double _tamanoMin = 14;
  static const double _tamanoMax = 32;

  final LocalUserPreferencesStore _prefs = LocalUserPreferencesStore();

  late final PageController _controller;
  late int _actual;
  bool _controlesVisibles = true;
  double _tamanoTexto = 19;
  int _tema = 0;
  int _colorSubrayado = 0; // 0: Ninguno, 1: Ámbar, 2: Cuero, 3: Salvia
  String _busquedaActiva = '';

  List<PaginaModel> get _paginas => widget.libro.paginas;
  _TemaLectura get _t => _temas[_tema];

  String get _libroId {
    if (widget.idLibro != null && widget.idLibro!.trim().isNotEmpty) {
      return widget.idLibro!.trim();
    }
    if (widget.libro.id.trim().isNotEmpty) return widget.libro.id.trim();
    if (widget.libro.isbnOCodigo.trim().isNotEmpty) {
      return widget.libro.isbnOCodigo.trim();
    }
    return widget.libro.titulo.trim();
  }

  @override
  void initState() {
    super.initState();
    final total = widget.libro.paginas.length;
    _actual = total == 0 ? 0 : widget.paginaInicial.clamp(0, total - 1);
    _controller = PageController(initialPage: _actual);
    _tema = ThemeController.instance.esOscuro ? 1 : 0;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _cargarPreferencias();
  }

  Future<void> _cargarPreferencias() async {
    try {
      final prog = await _prefs.obtenerProgreso(_libroId);
      if (!mounted) return;
      if (prog != null &&
          widget.paginaInicial == 0 &&
          !prog.completado &&
          prog.ultimaPagina > 0 &&
          prog.ultimaPagina < _paginas.length) {
        setState(() {
          _actual = prog.ultimaPagina;
          if (_controller.hasClients) {
            _controller.jumpToPage(_actual);
          }
        });
      }
      _guardarProgresoActual();
    } catch (e) {
      debugPrint('Error cargando preferencias de lectura: $e');
    }
  }

  void _guardarProgresoActual() {
    if (_paginas.isEmpty) return;
    unawaited(
      _prefs.guardarProgreso(
        libroId: _libroId,
        pagina: _actual,
        totalPaginas: _paginas.length,
      ),
    );
  }

  Future<void> _guardarProgresoYSaliendo() async {
    if (_paginas.isEmpty) return;
    try {
      await _prefs.guardarProgreso(
        libroId: _libroId,
        pagina: _actual,
        totalPaginas: _paginas.length,
      );
    } catch (e) {
      debugPrint('Error guardando progreso al salir: $e');
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller.dispose();
    super.dispose();
  }

  void _toggleControles() =>
      setState(() => _controlesVisibles = !_controlesVisibles);

  void _irA(int indice) {
    if (indice < 0 || indice >= _paginas.length) return;
    _controller.animateToPage(
      indice,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _cambiarTamano(double delta) {
    setState(() {
      _tamanoTexto = (_tamanoTexto + delta).clamp(_tamanoMin, _tamanoMax);
    });
  }

  void _mostrarPanelTipografia() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _t.barra,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: _t.acento.withValues(alpha: 0.3)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _t.texto.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'APARIENCIA Y TIPOGRAFÍA',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: _t.acento,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Icon(Icons.close, size: 18, color: _t.texto),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: List.generate(_temas.length, (idx) {
                        final item = _temas[idx];
                        final sel = _tema == idx;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: idx < _temas.length - 1 ? 8 : 0,
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                setState(() => _tema = idx);
                                setModalState(() {});
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: item.fondo,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: sel
                                        ? item.acento
                                        : item.texto.withValues(alpha: 0.2),
                                    width: sel ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      item.icono,
                                      size: 18,
                                      color: item.acento,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.nombre,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: sel
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: item.texto,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _t.fondo,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _t.acento.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            onPressed: _tamanoTexto > _tamanoMin
                                ? () {
                                    _cambiarTamano(-2);
                                    setModalState(() {});
                                  }
                                : null,
                            icon: Icon(Icons.text_decrease, color: _t.texto),
                            label: Text(
                              'A-',
                              style: TextStyle(
                                fontFamily: 'Literata',
                                fontWeight: FontWeight.bold,
                                color: _t.texto,
                              ),
                            ),
                          ),
                          Text(
                            'Cuerpo ${_tamanoTexto.round()} pt',
                            style: TextStyle(
                              fontFamily: 'Newsreader',
                              fontStyle: FontStyle.italic,
                              fontSize: 14,
                              color: _t.acento,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _tamanoTexto < _tamanoMax
                                ? () {
                                    _cambiarTamano(2);
                                    setModalState(() {});
                                  }
                                : null,
                            icon: Icon(Icons.text_increase, color: _t.texto),
                            label: Text(
                              'A+',
                              style: TextStyle(
                                fontFamily: 'Literata',
                                fontWeight: FontWeight.bold,
                                color: _t.texto,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _abrirBuscador() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF2C1810),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _BuscadorEnLibroSheet(
        paginas: _paginas,
        busquedaInicial: _busquedaActiva,
        onSeleccionarResultado: (indicePagina, termino) {
          Navigator.pop(ctx);
          setState(() => _busquedaActiva = termino);
          _irA(indicePagina);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _paginas.length;
    final overlay = _t.fondo.computeLuminance() > 0.5
        ? SystemUiOverlayStyle.dark
        : SystemUiOverlayStyle.light;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            _guardarProgresoYSaliendo();
          }
        },
        child: Scaffold(
          backgroundColor: _t.fondo,
          body: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                  _irA(_actual + 1),
              const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                  _irA(_actual - 1),
              const SingleActivator(LogicalKeyboardKey.escape): () async {
                await _guardarProgresoYSaliendo();
                if (!context.mounted) return;
                Navigator.of(context).maybePop();
              },
            },
            child: Focus(
              autofocus: true,
              child: total == 0
                  ? _vacio()
                  : Stack(
                      children: [
                        // Sombra sutil de pliegue de encuadernación a la izquierda
                        Positioned(
                          top: 0,
                          bottom: 0,
                          left: 0,
                          width: 14,
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.black.withValues(alpha: 0.08),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        PageView.builder(
                          controller: _controller,
                          itemCount: total,
                          onPageChanged: (i) {
                            setState(() => _actual = i);
                            _guardarProgresoActual();
                          },
                          itemBuilder: (_, i) => _pagina(i, total),
                        ),
                        if (_busquedaActiva.isNotEmpty) _bannerBusquedaActiva(),
                        _barraSuperior(total),
                        _barraInferior(total),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bannerBusquedaActiva() {
    return Positioned(
      top: 64,
      left: 16,
      right: 16,
      child: AnimatedOpacity(
        opacity: _controlesVisibles ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF2C1810),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFD4A373), width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.search_rounded,
                size: 16,
                color: Color(0xFFD4A373),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Buscando: "$_busquedaActiva"',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFCF9F4),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: Color(0xFFD4A373),
                ),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Quitar resaltado',
                onPressed: () => setState(() => _busquedaActiva = ''),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _vacio() {
    return SafeArea(
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              icon: Icon(Icons.close, color: _t.texto),
              onPressed: () async {
                await _guardarProgresoYSaliendo();
                if (!mounted) return;
                Navigator.of(context).maybePop();
              },
            ),
          ),
          Center(
            child: Text(
              'No hay páginas para leer.',
              style: TextStyle(color: _t.texto, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pagina(int i, int total) {
    final pag = _paginas[i];
    final texto = pag.texto.trim().isEmpty
        ? '[Sin texto transcrito]'
        : pag.texto.trim();

    Color? bgHighlight;
    if (_colorSubrayado == 1) {
      bgHighlight = const Color(0xFFD4A373).withValues(alpha: 0.22);
    } else if (_colorSubrayado == 2) {
      bgHighlight = const Color(0xFF8C4E26).withValues(alpha: 0.16);
    } else if (_colorSubrayado == 3) {
      bgHighlight = const Color(0xFF708264).withValues(alpha: 0.22);
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 68, 28, 128),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Encabezado clásico de la página
                Center(
                  child: Column(
                    children: [
                      Text(
                        'Página ${pag.numeroPagina}',
                        style: TextStyle(
                          fontFamily: 'Literata',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _t.texto,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 32,
                            height: 1,
                            color: _t.acento.withValues(alpha: 0.35),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            child: Text(
                              '❦',
                              style: TextStyle(
                                fontSize: 12,
                                color: _t.acento,
                              ),
                            ),
                          ),
                          Container(
                            width: 32,
                            height: 1,
                            color: _t.acento.withValues(alpha: 0.35),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Barra Contextual de Tinta de Resaltado (sin marcador manual)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C1810),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFD4A373).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _tintDot(1, const Color(0xFFD4A373), 'Tinta ámbar'),
                        const SizedBox(width: 6),
                        _tintDot(2, const Color(0xFFC48B5E), 'Tinta sepia'),
                        const SizedBox(width: 6),
                        _tintDot(3, const Color(0xFF708264), 'Tinta salvia'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Cuerpo literario
                Container(
                  padding: bgHighlight != null
                      ? const EdgeInsets.all(12)
                      : EdgeInsets.zero,
                  decoration: bgHighlight != null
                      ? BoxDecoration(
                          color: bgHighlight,
                          borderRadius: BorderRadius.circular(8),
                        )
                      : null,
                  child: _busquedaActiva.isEmpty
                      ? SelectableText(
                          texto,
                          onTap: _toggleControles,
                          style: TextStyle(
                            color: _t.texto,
                            fontFamily: 'Newsreader',
                            fontSize: _tamanoTexto,
                            height: 1.75,
                          ),
                        )
                      : SelectableText.rich(
                          TextSpan(
                            children: _construirSpansResaltados(
                              texto,
                              _busquedaActiva,
                            ),
                            style: TextStyle(
                              color: _t.texto,
                              fontFamily: 'Newsreader',
                              fontSize: _tamanoTexto,
                              height: 1.75,
                            ),
                          ),
                          onTap: _toggleControles,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tintDot(int index, Color color, String tooltip) {
    final activo = _colorSubrayado == index;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () => setState(
          () => _colorSubrayado = (_colorSubrayado == index ? 0 : index),
        ),
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: activo ? Colors.white : Colors.white38,
              width: activo ? 2 : 1,
            ),
          ),
        ),
      ),
    );
  }

  List<TextSpan> _construirSpansResaltados(
    String textoCompleto,
    String termino,
  ) {
    if (termino.isEmpty) {
      return [TextSpan(text: textoCompleto)];
    }
    final spans = <TextSpan>[];
    final regex = RegExp(RegExp.escape(termino), caseSensitive: false);
    var start = 0;
    for (final match in regex.allMatches(textoCompleto)) {
      if (match.start > start) {
        spans.add(TextSpan(text: textoCompleto.substring(start, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: TextStyle(
            backgroundColor: const Color(0xFFD4A373).withValues(alpha: 0.55),
            color: _t.texto,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      start = match.end;
    }
    if (start < textoCompleto.length) {
      spans.add(TextSpan(text: textoCompleto.substring(start)));
    }
    return spans;
  }

  Widget _barraSuperior(int total) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedSlide(
        offset: _controlesVisibles ? Offset.zero : const Offset(0, -1),
        duration: const Duration(milliseconds: 220),
        child: AnimatedOpacity(
          opacity: _controlesVisibles ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          child: IgnorePointer(
            ignoring: !_controlesVisibles,
            child: Material(
              color: _t.barra.withValues(alpha: 0.96),
              elevation: 1,
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_rounded, color: _t.texto),
                        tooltip: 'Salir del modo lectura',
                        onPressed: () async {
                          await _guardarProgresoYSaliendo();
                          if (!mounted) return;
                          Navigator.of(context).maybePop();
                        },
                      ),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.libro.titulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Literata',
                                fontStyle: FontStyle.italic,
                                color: _t.texto,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'PÁGINA ${_actual + 1} DE $total',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                color: _t.acento,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(Icons.search_rounded, color: _t.texto),
                        tooltip: 'Buscar en el libro',
                        onPressed: _abrirBuscador,
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.text_fields_rounded,
                          color: _t.acento,
                        ),
                        tooltip: 'Opciones de tipografía y tema',
                        onPressed: _mostrarPanelTipografia,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _barraInferior(int total) {
    final puedeAtras = _actual > 0;
    final puedeAdelante = _actual < total - 1;
    final porcentaje = total > 0 ? (((_actual + 1) / total) * 100).round() : 0;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedSlide(
        offset: _controlesVisibles ? Offset.zero : const Offset(0, 1),
        duration: const Duration(milliseconds: 220),
        child: AnimatedOpacity(
          opacity: _controlesVisibles ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          child: IgnorePointer(
            ignoring: !_controlesVisibles,
            child: Material(
              color: _t.barra.withValues(alpha: 0.96),
              elevation: 4,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Página ${_paginas[_actual].numeroPagina} de $total',
                                style: TextStyle(
                                  fontFamily: 'Literata',
                                  color: _t.texto,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '($porcentaje%)',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: _t.acento,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Tema: ${_t.nombre}',
                            style: TextStyle(
                              fontFamily: 'Newsreader',
                              fontStyle: FontStyle.italic,
                              fontSize: 11.5,
                              color: _t.texto.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.chevron_left, color: _t.texto),
                            iconSize: 30,
                            tooltip: 'Página anterior',
                            onPressed:
                                puedeAtras ? () => _irA(_actual - 1) : null,
                          ),
                          Expanded(
                            child: total > 1
                                ? SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: _t.acento,
                                      thumbColor: _t.acento,
                                      inactiveTrackColor: _t.acento
                                          .withValues(alpha: 0.22),
                                    ),
                                    child: Slider(
                                      value: _actual.toDouble(),
                                      min: 0,
                                      max: (total - 1).toDouble(),
                                      divisions: total - 1,
                                      onChanged: (v) =>
                                          _controller.jumpToPage(v.round()),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          IconButton(
                            icon: Icon(Icons.chevron_right, color: _t.texto),
                            iconSize: 30,
                            tooltip: 'Página siguiente',
                            onPressed: puedeAdelante
                                ? () => _irA(_actual + 1)
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BuscadorEnLibroSheet extends StatefulWidget {
  final List<PaginaModel> paginas;
  final String busquedaInicial;
  final void Function(int indicePagina, String termino) onSeleccionarResultado;

  const _BuscadorEnLibroSheet({
    required this.paginas,
    required this.busquedaInicial,
    required this.onSeleccionarResultado,
  });

  @override
  State<_BuscadorEnLibroSheet> createState() => _BuscadorEnLibroSheetState();
}

class _BuscadorEnLibroSheetState extends State<_BuscadorEnLibroSheet> {
  late final TextEditingController _inputController;
  List<_ResultadoBusqueda> _resultados = [];
  bool _buscando = false;

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController(text: widget.busquedaInicial);
    if (widget.busquedaInicial.trim().isNotEmpty) {
      _ejecutarBusqueda(widget.busquedaInicial);
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _ejecutarBusqueda(String q) {
    final query = q.trim();
    if (query.isEmpty) {
      setState(() {
        _resultados = [];
        _buscando = false;
      });
      return;
    }

    setState(() => _buscando = true);

    final regex = RegExp(RegExp.escape(query), caseSensitive: false);
    final resultados = <_ResultadoBusqueda>[];

    for (var i = 0; i < widget.paginas.length; i++) {
      final p = widget.paginas[i];
      final texto = p.texto;
      final match = regex.firstMatch(texto);
      if (match != null) {
        final start = (match.start - 30).clamp(0, texto.length);
        final end = (match.end + 40).clamp(0, texto.length);
        final snippet = texto.substring(start, end).replaceAll('\n', ' ');
        resultados.add(
          _ResultadoBusqueda(
            indicePagina: i,
            numeroPagina: p.numeroPagina,
            fragmento: '...$snippet...',
          ),
        );
      }
    }

    setState(() {
      _resultados = resultados;
      _buscando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SizedBox(
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.search_rounded, color: Color(0xFFD4A373)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Buscar dentro del tomo',
                    style: TextStyle(
                      fontFamily: 'Literata',
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFCF9F4),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFFD4A373)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _inputController,
              autofocus: true,
              style: const TextStyle(color: Color(0xFFFCF9F4)),
              textInputAction: TextInputAction.search,
              onSubmitted: _ejecutarBusqueda,
              decoration: InputDecoration(
                hintText: 'Palabra o pasaje a buscar...',
                hintStyle: TextStyle(
                  color: const Color(0xFFEDE7DF).withValues(alpha: 0.55),
                ),
                filled: true,
                fillColor: const Color(0xFF1A110D),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFFD4A373),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Color(0xFFD4A373),
                  ),
                  onPressed: () => _ejecutarBusqueda(_inputController.text),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF8C4E26)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_buscando)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(color: Color(0xFFD4A373)),
                ),
              )
            else if (_inputController.text.trim().isNotEmpty &&
                _resultados.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No se encontraron coincidencias en las páginas.',
                    style: TextStyle(color: Color(0xFFEDE7DF), fontSize: 13),
                  ),
                ),
              )
            else ...[
              if (_resultados.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${_resultados.length} ${_resultados.length == 1 ? 'coincidencia encontrada' : 'coincidencias encontradas'}:',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFD4A373),
                    ),
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  itemCount: _resultados.length,
                  separatorBuilder: (context, index) => Divider(
                    color: const Color(0xFFD4A373).withValues(alpha: 0.2),
                    height: 1,
                  ),
                  itemBuilder: (ctx, i) {
                    final r = _resultados[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8C4E26),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Pág. ${r.numeroPagina}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFCF9F4),
                          ),
                        ),
                      ),
                      title: Text(
                        r.fragmento,
                        style: const TextStyle(
                          fontFamily: 'Newsreader',
                          fontSize: 13,
                          color: Color(0xFFEDE7DF),
                        ),
                      ),
                      onTap: () => widget.onSeleccionarResultado(
                        r.indicePagina,
                        _inputController.text.trim(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
