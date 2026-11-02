import 'package:flutter/material.dart';

import '../models/libro_model.dart';
import '../services/api_service.dart';
import '../services/local_user_preferences_store.dart';
import 'reading_mode_screen.dart';

/// Detalle del Tomo — Implementa el diseño Stitch "Detalle del Libro" (`300670b5...`).
class BookDetailScreen extends StatefulWidget {
  final String idLibro;
  final String titulo;
  final LibroModel? libroLocal;
  final String? errorSync;

  const BookDetailScreen({
    super.key,
    required this.idLibro,
    required this.titulo,
    this.libroLocal,
    this.errorSync,
  });

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  final LocalUserPreferencesStore _prefs = LocalUserPreferencesStore();
  bool _cargando = false;
  LibroModel? _libro;
  String? _error;
  String? _errorSync;
  ProgresoLectura? _progreso;
  bool _esFavorito = false;

  @override
  void initState() {
    super.initState();
    _libro = widget.libroLocal;
    _errorSync = widget.errorSync;
    _cargarPreferencias();
    if (widget.libroLocal == null) {
      _cargarDetalle();
    }
  }

  Future<void> _cargarPreferencias() async {
    try {
      final prog = await _prefs.obtenerProgreso(widget.idLibro);
      final fav = await _prefs.esFavorito(widget.idLibro);
      if (mounted) {
        setState(() {
          _progreso = prog;
          _esFavorito = fav;
        });
      }
    } catch (_) {}
  }

  Future<void> _cargarDetalle() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final libro = await ApiService.obtenerDetalleLibro(widget.idLibro);
      if (mounted) {
        setState(() {
          _libro = libro;
          _cargando = false;
          if (libro == null) {
            _error = 'No se encontró el documento en el servidor.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error de conexión: $e';
          _cargando = false;
        });
      }
    }
  }

  Future<void> _eliminar() async {
    final libro = _libro;
    if (libro == null) return;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar documento'),
        content: Text(
          '¿Seguro que quieres eliminar "${libro.titulo}"? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmado != true || !mounted) return;

    try {
      await ApiService.eliminarLibro(libro.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Documento eliminado correctamente.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e')));
    }
  }

  Future<void> _abrirModoLectura(LibroModel libro, {int desde = 0}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReadingModeScreen(
          libro: libro,
          idLibro: widget.idLibro,
          paginaInicial: desde,
        ),
      ),
    );
    if (mounted) {
      await _cargarPreferencias();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Detalle del Tomo',
          style: TextStyle(
            fontFamily: 'Literata',
            fontStyle: FontStyle.italic,
            fontSize: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _esFavorito
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color: _esFavorito
                  ? theme.colorScheme.secondary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            tooltip: _esFavorito
                ? 'Quitar de favoritos'
                : 'Marcar como favorito',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final nuevoFav = await _prefs.alternarFavorito(widget.idLibro);
              if (!mounted) return;
              setState(() => _esFavorito = nuevoFav);
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    nuevoFav
                        ? 'Tomo guardado en tus destacados ⭐'
                        : 'Tomo quitado de destacados',
                  ),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          if (_libro != null && widget.libroLocal == null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Eliminar documento',
              onPressed: _eliminar,
            ),
        ],
      ),
      body: _cargando
          ? Center(
              child: CircularProgressIndicator(
                color: theme.colorScheme.secondary,
              ),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _cargarDetalle,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          : _construirDetalle(),
    );
  }

  Widget _construirDetalle() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final libro = _libro!;
    final paginas = libro.paginas;
    final totalPalabras = paginas.fold<int>(0, (s, p) => s + p.conteoPalabras);
    final porcentaje = (_progreso != null && _progreso!.totalPaginas > 0)
        ? _progreso!.porcentajeEntero
        : 0;
    final paginaActual = (_progreso != null && _progreso!.ultimaPagina > 0)
        ? _progreso!.ultimaPagina + 1
        : 1;
    final lecturaCompletada = _progreso != null && _progreso!.completado;

    final tipo = libro.tipoLibro.toLowerCase();
    final gradientColors = tipo.contains('historia')
        ? const [Color(0xFF5A2525), Color(0xFF7E3838)]
        : tipo.contains('ficci') || tipo.contains('novela')
        ? const [Color(0xFF8C4E26), Color(0xFFC48B5E)]
        : tipo.contains('pdf')
        ? const [Color(0xFF1B3B4B), Color(0xFF2C5E78)]
        : const [Color(0xFF2C1810), Color(0xFF4A2A1E)];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        // Banner de estado local / offline
        if (widget.libroLocal != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF261D15) : const Color(0xFFFFF9F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.amber.shade700.withValues(alpha: 0.5),
                width: 1.2,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.cloud_upload_outlined,
                  color: isDark ? Colors.amber.shade300 : Colors.amber.shade900,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Guardado en este dispositivo; aún no está en el servidor.',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.amber.shade200
                              : Colors.amber.shade900,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _errorSync != null ? 'Error de subida: $_errorSync' : 'Los cambios se subirán automáticamente en cuanto se restablezca la conexión.',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 1. Hero Cover Section Centrada con Lomo de Nervios y Listón (Stitch detalle.html)
        Center(
          child: Column(
            children: [
              SizedBox(
                width: 148,
                height: 214,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Listón Ex Libris sobresaliendo arriba
                    Positioned(
                      top: -8,
                      right: 22,
                      child: Container(
                        width: 18,
                        height: 28,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondary,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    // Portada encuadernada en cuero con nervios en el lomo
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          bottomLeft: Radius.circular(4),
                          topRight: Radius.circular(10),
                          bottomRight: Radius.circular(10),
                        ),
                        border: Border.all(
                          color: const Color(0xFFD4A373).withValues(alpha: 0.4),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.5 : 0.25,
                            ),
                            blurRadius: 20,
                            offset: const Offset(6, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Lomo izquierdo con nervios dorados (Raised Cord Hubs)
                          Container(
                            width: 16,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.28),
                              border: Border(
                                right: BorderSide(
                                  color: Colors.black.withValues(alpha: 0.35),
                                ),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(
                                4,
                                (_) => Container(
                                  height: 2,
                                  color: const Color(0xFFD4A373)
                                      .withValues(alpha: 0.45),
                                ),
                              ),
                            ),
                          ),
                          // Cubierta grabada en pan de oro
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xFFD4A373)
                                        .withValues(alpha: 0.35),
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Icon(
                                      Icons.auto_stories_rounded,
                                      size: 20,
                                      color: Color(0xFFD4A373),
                                    ),
                                    Text(
                                      libro.titulo,
                                      textAlign: TextAlign.center,
                                      maxLines: 4,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'Literata',
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFFCF9F4),
                                        height: 1.2,
                                      ),
                                    ),
                                    Column(
                                      children: [
                                        Container(
                                          width: 28,
                                          height: 1,
                                          color: const Color(0xFFD4A373)
                                              .withValues(alpha: 0.5),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'COLECCIÓN CLÁSICA',
                                          style: TextStyle(
                                            fontSize: 6.5,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.2,
                                            color: Color(0xFFD4A373),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Píldora "Edición Digitalizada • Escaneado en HD"
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      size: 14,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'EDICIÓN DIGITALIZADA • ESCANEADO EN HD',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Información Bibliográfica Centrada
        Text(
          libro.titulo,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Literata',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          libro.autor.isNotEmpty ? libro.autor : 'Autor no especificado',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Newsreader',
            fontStyle: FontStyle.italic,
            fontSize: 16.5,
            color: theme.colorScheme.secondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          [
            if (libro.editorial.isNotEmpty) libro.editorial,
            'Año ${libro.anioInicio}',
            if (libro.tipoLibro.isNotEmpty) libro.tipoLibro,
          ].join(' • '),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),

        // 3. Bento Grid de 2 Columnas + Gilded Book Edge Tracker (Stitch)
        Row(
          children: [
            Expanded(
              child: _bentoStatCard(
                theme,
                icon: Icons.document_scanner_outlined,
                label: 'DIGITALIZADO',
                value: '${paginas.length} págs.',
                sub: '$totalPalabras palabras',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _bentoStatCard(
                theme,
                icon: Icons.auto_stories_outlined,
                label: 'PROGRESO',
                value: '$porcentaje%',
                sub: lecturaCompletada ? 'Completado' : 'Pág. $paginaActual',
                highlight: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Barra dorada de progreso de cantos de libro
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progreso en el tomo actual',
                    style: TextStyle(
                      fontFamily: 'Newsreader',
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    'Página $paginaActual de ${paginas.isEmpty ? 1 : paginas.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (_progreso != null && _progreso!.totalPaginas > 0)
                      ? _progreso!.porcentaje
                      : 0.04,
                  minHeight: 6,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.secondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4. Botón Primario: Continuar Lectura / Comenzar Lectura
        if (paginas.isNotEmpty) ...[
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: () => _abrirModoLectura(
                libro,
                desde: (_progreso != null &&
                        !lecturaCompletada &&
                        _progreso!.ultimaPagina > 0)
                    ? _progreso!.ultimaPagina
                    : 0,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.menu_book_rounded, size: 20),
              label: Text(
                lecturaCompletada
                    ? 'VOLVER A LEER DESDE EL INICIO'
                    : (_progreso != null && _progreso!.ultimaPagina > 0)
                        ? 'CONTINUAR LECTURA (PÁG. $paginaActual)'
                        : 'ABRIR EN MODO LECTURA',
                style: const TextStyle(
                  fontFamily: 'Literata',
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // 5. Sección de Páginas Digitalizadas
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Páginas Digitalizadas',
              style: TextStyle(
                fontFamily: 'Literata',
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              '${paginas.length} páginas',
              style: TextStyle(
                fontFamily: 'Newsreader',
                fontStyle: FontStyle.italic,
                fontSize: 13,
                color: theme.colorScheme.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (paginas.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No hay páginas registradas para este documento.',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          )
        else
          ...paginas.map(
            (pag) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              color: theme.cardTheme.color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: ExpansionTile(
                leading: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.4),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${pag.numeroPagina}',
                    style: TextStyle(
                      fontFamily: 'Literata',
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.secondary,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                title: Text(
                  'Página ${pag.numeroPagina}',
                  style: TextStyle(
                    fontFamily: 'Literata',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  '${pag.conteoPalabras} palabras transcritas',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: SelectableText(
                      pag.texto.trim().isEmpty
                          ? '[Sin texto transcrito]'
                          : pag.texto,
                      style: TextStyle(
                        fontFamily: 'Newsreader',
                        fontSize: 14,
                        height: 1.55,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8, bottom: 6),
                      child: TextButton.icon(
                        onPressed: () => _abrirModoLectura(
                          libro,
                          desde: paginas.indexOf(pag),
                        ),
                        icon: Icon(
                          Icons.auto_stories_rounded,
                          size: 17,
                          color: theme.colorScheme.secondary,
                        ),
                        label: Text(
                          'Leer desde esta página',
                          style: TextStyle(
                            color: theme.colorScheme.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
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

  Widget _bentoStatCard(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
    required String sub,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlight
              ? theme.colorScheme.secondary.withValues(alpha: 0.45)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.secondary),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Literata',
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: highlight
                  ? theme.colorScheme.secondary
                  : theme.colorScheme.onSurface,
            ),
          ),
          Text(
            sub,
            style: TextStyle(
              fontSize: 9.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
