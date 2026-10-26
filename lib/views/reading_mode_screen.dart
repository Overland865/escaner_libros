import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/libro_model.dart';
import '../models/pagina_model.dart';
import '../services/local_user_preferences_store.dart';

/// Modo lectura: muestra las páginas del libro a pantalla completa y permite
/// pasar de una a otra deslizando, con los botones o con la barra inferior.
///
/// Un toque sobre el texto muestra/oculta los controles.
/// Incluye: buscador de texto en el libro, marcadores de página y guardado automático de progreso.
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

  const _TemaLectura(this.nombre, this.icono, this.fondo, this.texto, this.barra);
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
      'Noche',
      Icons.dark_mode_outlined,
      Color(0xFF0B0C12),
      Color(0xFFF1F0FB),
      Color(0xFF141724),
    ),
    _TemaLectura(
      'Sepia',
      Icons.menu_book_outlined,
      Color(0xFFF4ECD8),
      Color(0xFF3B2F1E),
      Color(0xFFE8DCBF),
    ),
    _TemaLectura(
      'Claro',
      Icons.light_mode_outlined,
      Color(0xFFFFFFFF),
      Color(0xFF1A1A1A),
      Color(0xFFEFEFF4),
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

  // Marcadores y búsqueda
  Set<int> _marcadores = <int>{};
  String _busquedaActiva = '';
  String? _mensajeAvisoMarcador;
  Timer? _temporizadorAvisoMarcador;

  List<PaginaModel> get _paginas => widget.libro.paginas;
  _TemaLectura get _t => _temas[_tema];

  String get _libroId {
    if (widget.idLibro != null && widget.idLibro!.trim().isNotEmpty) {
      return widget.idLibro!.trim();
    }
    if (widget.libro.id.trim().isNotEmpty) return widget.libro.id.trim();
    if (widget.libro.isbnOCodigo.trim().isNotEmpty) return widget.libro.isbnOCodigo.trim();
    return widget.libro.titulo.trim();
  }

  @override
  void initState() {
    super.initState();
    final total = widget.libro.paginas.length;
    _actual = total == 0 ? 0 : widget.paginaInicial.clamp(0, total - 1);
    _controller = PageController(initialPage: _actual);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _cargarPreferencias();
  }

  Future<void> _cargarPreferencias() async {
    try {
      final prog = await _prefs.obtenerProgreso(_libroId);
      if (!mounted) return;
      if (prog != null) {
        setState(() {
          _marcadores = Set<int>.from(prog.marcadores);
          // Si iniciamos sin especificar página (0) pero el usuario ya tenía progreso guardado, saltar a ella
          if (widget.paginaInicial == 0 &&
              prog.ultimaPagina > 0 &&
              prog.ultimaPagina < _paginas.length) {
            _actual = prog.ultimaPagina;
            if (_controller.hasClients) {
              _controller.jumpToPage(_actual);
            }
          }
        });
      }
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
        marcadores: _marcadores,
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
        marcadores: _marcadores,
      );
    } catch (e) {
      debugPrint('Error guardando progreso al salir: $e');
    }
  }

  @override
  void dispose() {
    _temporizadorAvisoMarcador?.cancel();
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

  void _alternarMarcador() {
    if (_paginas.isEmpty) return;
    final pagNum = _paginas[_actual].numeroPagina;
    final estabaMarcado = _marcadores.contains(_actual);
    final ahoraMarcado = !estabaMarcado;

    // 1. Actualización inmediata y reactiva de la interfaz
    setState(() {
      if (ahoraMarcado) {
        _marcadores.add(_actual);
      } else {
        _marcadores.remove(_actual);
      }
      _mensajeAvisoMarcador = ahoraMarcado
          ? '¡Página $pagNum marcada con éxito! ⭐'
          : 'Página $pagNum eliminada de marcadores';
    });

    _temporizadorAvisoMarcador?.cancel();
    _temporizadorAvisoMarcador = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _mensajeAvisoMarcador = null);
    });

    // 2. Notificación flotante de confirmación (visible incluso con controles activos)
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              ahoraMarcado ? Icons.bookmark_added_rounded : Icons.bookmark_remove_outlined,
              color: ahoraMarcado ? const Color(0xFFF59E0B) : const Color(0xFF9499B3),
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                ahoraMarcado
                    ? 'Página $pagNum ha sido marcada en tus marcadores'
                    : 'Página $pagNum desmarcada',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: _controlesVisibles ? 100 : 24,
          left: 16,
          right: 16,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFF1B1E2D),
      ),
    );

    // 3. Persistencia asíncrona segura en almacenamiento local
    unawaited(
      _prefs.alternarMarcador(
        _libroId,
        _actual,
        totalPaginas: _paginas.length,
      ).catchError((e) {
        debugPrint('Error guardando marcador en preferencias: $e');
        return false;
      }),
    );
  }

  void _mostrarMarcadores() {
    final marcadoresOrdenados = _marcadores.toList()..sort();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141724),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.bookmark_rounded, color: Color(0xFF818CF8)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Marcadores guardados',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFF1F0FB),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF9499B3)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFF26293A)),
              if (marcadoresOrdenados.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(28.0),
                  child: Center(
                    child: Text(
                      'No tienes páginas marcadas aún.\nToca el icono de marcador en la barra superior para guardar una página.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF9499B3), fontSize: 13),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: marcadoresOrdenados.length,
                    itemBuilder: (c, i) {
                      final pagIdx = marcadoresOrdenados[i];
                      if (pagIdx >= _paginas.length) return const SizedBox.shrink();
                      final pag = _paginas[pagIdx];
                      final snippet = pag.texto.trim().replaceAll('\n', ' ');
                      final preview = snippet.length > 70
                          ? '${snippet.substring(0, 70)}...'
                          : snippet;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
                          foregroundColor: const Color(0xFFC6BFFF),
                          child: Text('${pag.numeroPagina}'),
                        ),
                        title: Text(
                          'Página ${pag.numeroPagina}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF1F0FB),
                          ),
                        ),
                        subtitle: Text(
                          preview.isEmpty ? '[Sin texto]' : preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFF8B8FA8), fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right, color: Color(0xFF6366F1)),
                        onTap: () {
                          Navigator.pop(ctx);
                          _irA(pagIdx);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _abrirBuscador() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141724),
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
                        PageView.builder(
                          controller: _controller,
                          itemCount: total,
                          onPageChanged: (i) {
                            setState(() => _actual = i);
                            _guardarProgresoActual();
                          },
                          itemBuilder: (_, i) => _pagina(i),
                        ),
                        if (_busquedaActiva.isNotEmpty) _bannerBusquedaActiva(),
                        if (_mensajeAvisoMarcador != null) _bannerAvisoMarcador(),
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
      top: 60,
      left: 16,
      right: 16,
      child: AnimatedOpacity(
        opacity: _controlesVisibles ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1C2033),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF6366F1), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_rounded, size: 16, color: Color(0xFF818CF8)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Buscando: "$_busquedaActiva"',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF1F0FB),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF9499B3)),
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

  Widget _bannerAvisoMarcador() {
    return Positioned(
      top: 64,
      left: 20,
      right: 20,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2438),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFF59E0B), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bookmark_added_rounded, color: Color(0xFFF59E0B), size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _mensajeAvisoMarcador!,
                  style: const TextStyle(
                    color: Color(0xFFF1F0FB),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pagina(int i) {
    final pag = _paginas[i];
    final texto = pag.texto.trim().isEmpty
        ? '[Sin texto transcrito]'
        : pag.texto.trim();
    final estaMarcado = _marcadores.contains(i);

    return SafeArea(
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 72, 24, 96),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: _busquedaActiva.isEmpty
                    ? SelectableText(
                        texto,
                        onTap: _toggleControles,
                        style: TextStyle(
                          color: _t.texto,
                          fontFamily: 'serif',
                          fontSize: _tamanoTexto,
                          height: 1.7,
                        ),
                      )
                    : SelectableText.rich(
                        TextSpan(
                          children: _construirSpansResaltados(texto, _busquedaActiva),
                          style: TextStyle(
                            color: _t.texto,
                            fontFamily: 'serif',
                            fontSize: _tamanoTexto,
                            height: 1.7,
                          ),
                        ),
                        onTap: _toggleControles,
                      ),
              ),
            ),
          ),
          if (estaMarcado)
            Positioned(
              top: 14,
              right: 18,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.7)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bookmark_rounded, color: Color(0xFFF59E0B), size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Página marcada',
                      style: TextStyle(
                        color: Color(0xFFF59E0B),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<TextSpan> _construirSpansResaltados(String textoCompleto, String termino) {
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
            backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.55),
            color: Colors.white,
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
    final estaMarcado = _marcadores.contains(_actual);

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
              color: _t.barra,
              elevation: 2,
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.close, color: _t.texto),
                        tooltip: 'Salir del modo lectura',
                        onPressed: () async {
                          await _guardarProgresoYSaliendo();
                          if (!mounted) return;
                          Navigator.of(context).maybePop();
                        },
                      ),
                      Expanded(
                        child: Text(
                          widget.libro.titulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _t.texto,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
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
                          estaMarcado
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: estaMarcado ? const Color(0xFFF59E0B) : _t.texto,
                          size: 24,
                        ),
                        tooltip: estaMarcado
                            ? 'Quitar marcador de esta página'
                            : 'Marcar esta página',
                        onPressed: _alternarMarcador,
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(Icons.bookmarks_outlined, color: _t.texto),
                        tooltip: 'Ver lista de marcadores',
                        onPressed: _mostrarMarcadores,
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(Icons.text_decrease, color: _t.texto),
                        tooltip: 'Reducir letra',
                        onPressed: _tamanoTexto > _tamanoMin
                            ? () => _cambiarTamano(-2)
                            : null,
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(Icons.text_increase, color: _t.texto),
                        tooltip: 'Aumentar letra',
                        onPressed: _tamanoTexto < _tamanoMax
                            ? () => _cambiarTamano(2)
                            : null,
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(_t.icono, color: _t.texto),
                        tooltip: 'Tema: ${_t.nombre}',
                        onPressed: () => setState(
                          () => _tema = (_tema + 1) % _temas.length,
                        ),
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
              color: _t.barra,
              elevation: 4,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Página ${_paginas[_actual].numeroPagina} de $total',
                        style: TextStyle(
                          color: _t.texto,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.chevron_left, color: _t.texto),
                            iconSize: 32,
                            tooltip: 'Página anterior',
                            onPressed:
                                puedeAtras ? () => _irA(_actual - 1) : null,
                          ),
                          Expanded(
                            child: total > 1
                                ? Slider(
                                    value: _actual.toDouble(),
                                    min: 0,
                                    max: (total - 1).toDouble(),
                                    divisions: total - 1,
                                    onChanged: (v) =>
                                        _controller.jumpToPage(v.round()),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          IconButton(
                            icon: Icon(Icons.chevron_right, color: _t.texto),
                            iconSize: 32,
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
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.search_rounded, color: Color(0xFF818CF8)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Buscar dentro del libro',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF1F0FB),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF9499B3)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _inputController,
              autofocus: true,
              style: const TextStyle(color: Color(0xFFF1F0FB)),
              textInputAction: TextInputAction.search,
              onSubmitted: _ejecutarBusqueda,
              decoration: InputDecoration(
                hintText: 'Palabra o frase a buscar...',
                hintStyle: const TextStyle(color: Color(0xFF646B87)),
                filled: true,
                fillColor: const Color(0xFF1B1E2E),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF818CF8)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF818CF8)),
                  onPressed: () => _ejecutarBusqueda(_inputController.text),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2E3249)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_buscando)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                ),
              )
            else if (_inputController.text.trim().isNotEmpty && _resultados.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No se encontraron coincidencias en las páginas.',
                    style: TextStyle(color: Color(0xFF9499B3), fontSize: 13),
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
                      color: Color(0xFFC6BFFF),
                    ),
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  itemCount: _resultados.length,
                  separatorBuilder: (context, index) => const Divider(color: Color(0xFF26293A), height: 1),
                  itemBuilder: (ctx, i) {
                    final r = _resultados[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Pág. ${r.numeroPagina}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF818CF8),
                          ),
                        ),
                      ),
                      title: Text(
                        r.fragmento,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFFD4D8EE),
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
