import 'package:flutter/material.dart';

import '../../controllers/biblioteca_controller.dart';
import '../../models/libro_model.dart';
import '../../services/api_service.dart';
import '../../services/local_user_preferences_store.dart';
import '../book_detail_screen.dart';
import '../reading_mode_screen.dart';
import '../widgets/backend_connection_sheet.dart';

/// Pestaña 1 — Inicio con la estética editorial clásica modelada en Google Stitch.
///
/// Incluye:
/// - Buscador universal con estilo pergamino
/// - Acciones Rápidas: Escanear libro y Subir PDF en tarjetas con relieve
/// - Cinta minimalista de racha/progreso de lectura
/// - Ficha Heroica "Continuando tu lectura" con indicador de lomo, cinta de marcapáginas y botón Reanudar
/// - Estantería horizontal "Libros Recientes" con lomos reales y medidores dorados
/// - Banners de sincronización y estado sin conexión
class HomeTab extends StatefulWidget {
  final BibliotecaController biblioteca;
  final VoidCallback? onEscanear;
  final VoidCallback onVerLibros;
  final VoidCallback? onSubirPdf;

  const HomeTab({
    super.key,
    required this.biblioteca,
    this.onEscanear,
    required this.onVerLibros,
    this.onSubirPdf,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final LocalUserPreferencesStore _prefs = LocalUserPreferencesStore();
  Map<String, ProgresoLectura> _progresos = {};

  @override
  void initState() {
    super.initState();
    _cargarProgresos();
    widget.biblioteca.addListener(_alCambiarBiblioteca);
  }

  @override
  void didUpdateWidget(covariant HomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.biblioteca != widget.biblioteca) {
      oldWidget.biblioteca.removeListener(_alCambiarBiblioteca);
      widget.biblioteca.addListener(_alCambiarBiblioteca);
      _cargarProgresos();
    }
  }

  @override
  void dispose() {
    widget.biblioteca.removeListener(_alCambiarBiblioteca);
    super.dispose();
  }

  void _alCambiarBiblioteca() {
    _cargarProgresos();
  }

  Future<void> _cargarProgresos() async {
    final map = <String, ProgresoLectura>{};
    for (final libro in widget.biblioteca.libros) {
      try {
        final p = await _prefs.obtenerProgreso(libro.id);
        if (p != null) {
          map[libro.id] = p;
        }
      } catch (_) {}
    }
    if (mounted) {
      setState(() => _progresos = map);
    }
  }

  LibroModel? _obtenerLibroHero(List<LibroModel> libros) {
    if (libros.isEmpty) return null;
    // 1. Libro con lectura en curso (que aún no haya llegado a la última página)
    for (final l in libros) {
      final p = _progresos[l.id];
      final totalReal =
          l.paginas.isNotEmpty ? l.paginas.length : (p?.totalPaginas ?? 0);
      if (p != null && totalReal > 0 && p.ultimaPagina >= 0 && p.ultimaPagina < totalReal - 1) {
        return l;
      }
    }
    // 2. Primer libro pendiente de leer (que no esté completado)
    for (final l in libros) {
      final p = _progresos[l.id];
      if (p == null || !p.completado) {
        return l;
      }
    }
    return null;
  }

  Future<void> _reanudarLectura(
    BuildContext context,
    LibroModel libro,
    int paginaInicial,
  ) async {
    LibroModel libroCompleto = libro;

    // Si el libro viene del listado resumido sin páginas completas, intentar resolverlas
    if (libroCompleto.paginas.isEmpty) {
      // 1. Probar primero si ya está guardado en la caché local
      final enCache = await _prefs.obtenerDeCache(libro.id);
      if (enCache != null && enCache.paginas.isNotEmpty) {
        libroCompleto = enCache;
      } else {
        // 2. Consultar el detalle completo con todas sus páginas al backend
        if (!context.mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(ctx).colorScheme.outlineVariant,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Theme.of(ctx).colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Cargando lectura...',
                    style: TextStyle(
                      fontFamily: 'Literata',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(ctx).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        try {
          final remoto = await ApiService.obtenerDetalleLibro(libro.id);
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
          }
          if (remoto != null && remoto.paginas.isNotEmpty) {
            libroCompleto = remoto;
          } else if (remoto != null) {
            libroCompleto = remoto;
          }
        } catch (e) {
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
          }
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('No se pudieron obtener las páginas: $e'),
              ),
            );
          }
          return;
        }
      }
    }

    if (!context.mounted) return;

    if (libroCompleto.paginas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este documento aún no contiene páginas digitalizadas.'),
        ),
      );
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookDetailScreen(
            idLibro: libroCompleto.id,
            titulo: libroCompleto.titulo,
          ),
        ),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReadingModeScreen(
            libro: libroCompleto,
            idLibro: libroCompleto.id,
            paginaInicial: paginaInicial,
          ),
        ),
      );
    }
    if (mounted) {
      _cargarProgresos();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: widget.biblioteca,
      builder: (context, _) {
        final b = widget.biblioteca;
        final libros = b.libros;
        final heroLibro = _obtenerLibroHero(libros);
        final heroProgreso = heroLibro != null ? _progresos[heroLibro.id] : null;

        return RefreshIndicator(
          onRefresh: () async {
            await b.refrescar();
            await _cargarProgresos();
          },
          color: theme.colorScheme.secondary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              // Banners de conectividad / sincronización offline
              if (b.sinConexion) ...[
                _AnuncioSinConexion(biblioteca: b),
                const SizedBox(height: 14),
              ],
              if (b.pendientesCount > 0) ...[
                _TarjetaPendientes(biblioteca: b),
                const SizedBox(height: 14),
              ],

              // 2. Barra de búsqueda tipo pergamino incrustado
              _BuscadorPergamino(onTap: widget.onVerLibros),
              const SizedBox(height: 16),

              // 3. Tarjetas de Acciones Rápidas (Escanear y Subir PDF)
              _AccionesRapidasGrid(
                onEscanear: widget.onEscanear,
                onSubirPdf: widget.onSubirPdf ?? widget.onVerLibros,
              ),
              const SizedBox(height: 16),

              // 4. Cinta minimalista de hábito de lectura
              _CintaHabitoLectura(totalLibros: libros.length),
              const SizedBox(height: 20),

              // 5. Hero Section: "Continuando tu lectura"
              if (heroLibro != null) ...[
                _SeccionContinuarLectura(
                  libro: heroLibro,
                  progreso: heroProgreso,
                  onVerHistorial: widget.onVerLibros,
                  onReanudar: () => _reanudarLectura(
                    context,
                    heroLibro,
                    heroProgreso?.ultimaPagina ?? 0,
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // 6. Carrusel horizontal: "Libros Recientes / En tu estantería"
              if (libros.isNotEmpty) ...[
                _CarruselEstanteria(
                  libros: libros,
                  progresos: _progresos,
                  onVerTodos: widget.onVerLibros,
                  onSeleccionarLibro: (l) async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookDetailScreen(
                          idLibro: l.id,
                          titulo: l.titulo,
                          libroLocal: b.esPendiente(l.id) ? l : null,
                          errorSync: b.errorSyncDe(l.id),
                        ),
                      ),
                    );
                    _cargarProgresos();
                  },
                ),
                const SizedBox(height: 22),
              ] else if (b.estado == EstadoCarga.cargando) ...[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: CircularProgressIndicator(color: theme.colorScheme.secondary),
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                _EstadoVacio(onEscanear: widget.onEscanear),
                const SizedBox(height: 22),
              ],

            ],
          ),
        );
      },
    );
  }
}

/// 1. Barra de búsqueda estilo pergamino empotrado
class _BuscadorPergamino extends StatelessWidget {
  final VoidCallback onTap;

  const _BuscadorPergamino({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1A16) : const Color(0xFFF6F3EE),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Buscar título, autor o cita...',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2B241E) : const Color(0xFFEBE8E3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Filtros',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 3. Acciones rápidas (Binding Embossed Style)
class _AccionesRapidasGrid extends StatelessWidget {
  final VoidCallback? onEscanear;
  final VoidCallback onSubirPdf;

  const _AccionesRapidasGrid({
    this.onEscanear,
    required this.onSubirPdf,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        // Tarjeta Escanear
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onEscanear,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF221C18) : const Color(0xFFFAF7F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer.withValues(alpha: isDark ? 0.3 : 0.6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Icon(
                        Icons.document_scanner_rounded,
                        color: theme.colorScheme.secondary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Escanear',
                            style: TextStyle(
                              fontFamily: 'Literata',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Reconocer lomo',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Tarjeta Subir PDF
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onSubirPdf,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF221C18) : const Color(0xFFFAF7F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer.withValues(alpha: isDark ? 0.3 : 0.6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Icon(
                        Icons.upload_file_rounded,
                        color: theme.colorScheme.secondary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Subir PDF',
                            style: TextStyle(
                              fontFamily: 'Literata',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'EPUB o archivo',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 4. Cinta minimalista de hábito de lectura
class _CintaHabitoLectura extends StatelessWidget {
  final int totalLibros;

  const _CintaHabitoLectura({required this.totalLibros});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF201B17) : const Color(0xFFF9F6F0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFD4A373).withValues(alpha: isDark ? 0.3 : 0.25),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              color: Color(0xFFC07033),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Racha de lectura activa',
                  style: TextStyle(
                    fontFamily: 'Literata',
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  totalLibros == 1
                      ? '1 volumen registrado en tu archivo'
                      : '$totalLibros volúmenes en tu archivo personal',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$totalLibros vol.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.secondary,
                  ),
                ),
                Text(
                  'colección',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 5. Hero Card: "Continuando tu lectura" (Parchment Deckle Card con lazo)
class _SeccionContinuarLectura extends StatelessWidget {
  final LibroModel libro;
  final ProgresoLectura? progreso;
  final VoidCallback onVerHistorial;
  final VoidCallback onReanudar;

  const _SeccionContinuarLectura({
    required this.libro,
    this.progreso,
    required this.onVerHistorial,
    required this.onReanudar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final paginasTotal = libro.paginas.isNotEmpty
        ? libro.paginas.length
        : (progreso?.totalPaginas ?? 1);
    final paginaActual = (progreso != null && progreso!.ultimaPagina >= 0)
        ? (progreso!.ultimaPagina + 1)
        : 1;
    final porcentaje = progreso != null && paginasTotal > 0
        ? (paginaActual / paginasTotal).clamp(0.0, 1.0)
        : 0.0;
    final porcentajeEntero = (porcentaje * 100).round();

    // Tonos de portada clásicos
    final tipo = libro.tipoLibro.toLowerCase();
    final gradientColors = tipo.contains('historia')
        ? const [Color(0xFF5A2525), Color(0xFF7E3838)]
        : tipo.contains('ficci') || tipo.contains('novela')
            ? const [Color(0xFF2C1810), Color(0xFF4A2A1E)]
            : const [Color(0xFF263D33), Color(0xFF3B5E50)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado de sección
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Continuar Lectura',
              style: TextStyle(
                fontFamily: 'Literata',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.2,
              ),
            ),
            InkWell(
              onTap: onVerHistorial,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'HISTORIAL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.secondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: theme.colorScheme.secondary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Tarjeta con detalle, marcapáginas colgante y botón de reanudar
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF241D18) : const Color(0xFFFAF7F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Portada de libro con efecto de lomo encuadernado
                      Container(
                        width: 95,
                        height: 135,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: gradientColors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(2, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // Línea ilusión de lomo a la izquierda
                            Positioned(
                              top: 0,
                              bottom: 0,
                              left: 0,
                              width: 8,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(8),
                                    bottomLeft: Radius.circular(8),
                                  ),
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.black.withValues(alpha: 0.45),
                                      Colors.white.withValues(alpha: 0.1),
                                      Colors.black.withValues(alpha: 0.3),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Detalles en portada
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    libro.titulo,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'Literata',
                                      color: Color(0xFFFCF9F4),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    libro.autor,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: const Color(0xFFFCF9F4).withValues(alpha: 0.75),
                                      fontSize: 9.5,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  const Spacer(),
                                  // Badge de porcentaje leído
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '$porcentajeEntero% LEÍDO',
                                      style: const TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFD4A373),
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Metadatos y detalles de lectura
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                                ),
                              ),
                              child: Text(
                                libro.tipoLibro.isNotEmpty ? libro.tipoLibro : 'Literatura',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              libro.titulo,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Literata',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              libro.autor.isNotEmpty ? libro.autor : 'Autor clásico',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(
                                  Icons.menu_book_rounded,
                                  size: 15,
                                  color: theme.colorScheme.secondary,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Pág. $paginaActual de $paginasTotal',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Barra de progreso dorada y botón REANUDAR
                  const SizedBox(height: 14),
                  Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7)),
                  const SizedBox(height: 12),
                  // Medidor dorado de lectura
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: porcentaje,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.secondary),
                      minHeight: 5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        porcentajeEntero > 0
                            ? 'Progreso: $porcentajeEntero%'
                            : 'Comenzar lectura',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: onReanudar,
                        style: FilledButton.styleFrom(
                          backgroundColor: isDark
                              ? theme.colorScheme.secondary
                              : theme.colorScheme.primary,
                          foregroundColor: isDark
                              ? theme.colorScheme.onSecondary
                              : theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: Text(
                          porcentajeEntero > 0 ? 'REANUDAR' : 'LEER AHORA',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Lazo / Cinta de marcapáginas decorativo colgando arriba a la derecha
            Positioned(
              top: -4,
              right: 22,
              child: Container(
                width: 18,
                height: 28,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(3),
                    bottomRight: Radius.circular(3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD4A373),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 6. Carrusel horizontal: "En tu estantería / Libros Recientes"
class _CarruselEstanteria extends StatelessWidget {
  final List<LibroModel> libros;
  final Map<String, ProgresoLectura> progresos;
  final VoidCallback onVerTodos;
  final ValueChanged<LibroModel> onSeleccionarLibro;

  const _CarruselEstanteria({
    required this.libros,
    required this.progresos,
    required this.onVerTodos,
    required this.onSeleccionarLibro,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'En tu estantería',
                  style: TextStyle(
                    fontFamily: 'Literata',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${libros.length} vol.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: onVerTodos,
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.secondary,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Ver todos'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: libros.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final l = libros[index];
              final prog = progresos[l.id];
              return _LibroEstanteriaItem(
                libro: l,
                progreso: prog,
                onTap: () => onSeleccionarLibro(l),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Elemento de libro individual en la estantería horizontal
class _LibroEstanteriaItem extends StatelessWidget {
  final LibroModel libro;
  final ProgresoLectura? progreso;
  final VoidCallback onTap;

  const _LibroEstanteriaItem({
    required this.libro,
    this.progreso,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final tipo = libro.tipoLibro.toLowerCase();
    final gradientColors = tipo.contains('historia')
        ? const [Color(0xFF5A2525), Color(0xFF7E3838)]
        : tipo.contains('ficci') || tipo.contains('novela')
            ? const [Color(0xFF8C4E26), Color(0xFFC48B5E)]
            : tipo.contains('pdf')
                ? const [Color(0xFF1B3B4B), Color(0xFF2C5E78)]
                : const [Color(0xFF2C1810), Color(0xFF4A2A1E)];

    final porcentaje = progreso?.porcentaje ?? 0.0;
    final porcentajeEntero = (porcentaje * 100).round();
    final esCompletado = porcentaje >= 1.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 130,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Portada vertical de libro
              Container(
                width: 130,
                height: 160,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                      blurRadius: 8,
                      offset: const Offset(2, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Efecto de lomo a la izquierda
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: 0,
                      width: 6,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            bottomLeft: Radius.circular(8),
                          ),
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.45),
                              Colors.white.withValues(alpha: 0.15),
                              Colors.black.withValues(alpha: 0.25),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Título y contenido de portada
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Badge de estado o formato
                          Align(
                            alignment: Alignment.topRight,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                esCompletado
                                    ? 'Leído'
                                    : porcentajeEntero > 0
                                        ? '$porcentajeEntero%'
                                        : (libro.tipoLibro.toLowerCase().contains('pdf') ? 'PDF' : 'Libro'),
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: esCompletado ? const Color(0xFF90BE6D) : const Color(0xFFFCF9F4),
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            libro.titulo,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Literata',
                              color: Color(0xFFFCF9F4),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            libro.autor,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: const Color(0xFFFCF9F4).withValues(alpha: 0.75),
                              fontSize: 9.5,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              // Título debajo de la portada
              Text(
                libro.titulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Literata',
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                libro.autor.isNotEmpty ? libro.autor : 'Desconocido',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (porcentajeEntero > 0) ...[
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: porcentaje,
                    minHeight: 3,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.secondary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Estado vacío si aún no hay libros
class _EstadoVacio extends StatelessWidget {
  final VoidCallback? onEscanear;

  const _EstadoVacio({this.onEscanear});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Icon(
                Icons.auto_stories_outlined,
                size: 44,
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Aún no hay libros en tu archivo personal.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Literata',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Digitaliza un tomo físico con la cámara o importa un archivo PDF.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (onEscanear != null)
              FilledButton.icon(
                onPressed: onEscanear,
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.secondary,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.camera_alt, size: 18),
                label: const Text('Digitalizar primer libro'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de pendientes de sincronización (mantiene textos exactos para pruebas)
class _TarjetaPendientes extends StatelessWidget {
  final BibliotecaController biblioteca;
  const _TarjetaPendientes({required this.biblioteca});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final n = biblioteca.pendientesCount;
    final etiqueta = n == 1
        ? '1 libro pendiente de sincronizar'
        : '$n libros pendientes de sincronizar';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF261D15) : const Color(0xFFFFF9F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.amber.shade700.withValues(alpha: 0.5),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade900.withValues(alpha: isDark ? 0.35 : 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.cloud_upload_outlined,
                    color: isDark ? Colors.amber.shade300 : Colors.amber.shade900,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    etiqueta,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Están guardados en el dispositivo. Se subirán al servidor cuando haya conexión.',
              style: TextStyle(
                fontSize: 12.5,
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            if (biblioteca.sincronizando) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (biblioteca.syncTotal > 0 && biblioteca.syncActual > 0)
                      ? (biblioteca.syncActual / biblioteca.syncTotal).clamp(0.0, 1.0)
                      : null,
                  backgroundColor: Colors.amber.shade900.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.amber.shade700),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                biblioteca.syncTotal > 0
                    ? 'Sincronizando ${biblioteca.syncActual} de ${biblioteca.syncTotal}...'
                    : 'Preparando sincronización...',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: biblioteca.sincronizando
                    ? null
                    : () async {
                        final r = await biblioteca.sincronizarAhora();
                        if (!context.mounted) return;
                        final detalle = biblioteca.ultimoErrorDeSync;
                        final msg = r.sinConexion
                            ? 'Sin conexión con el servidor. Los pendientes se mantienen.'
                            : r.exitosos > 0 && r.fallidos == 0
                            ? 'Sincronizados: ${r.exitosos}.'
                            : r.fallidos > 0
                            ? 'No se pudo sincronizar${detalle != null ? ': $detalle' : '.'}'
                            : 'No había pendientes.';
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(msg),
                            duration: const Duration(seconds: 8),
                          ),
                        );
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.amber.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: biblioteca.sincronizando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.sync, size: 18),
                label: Text(
                  biblioteca.sincronizando
                      ? (biblioteca.syncTotal > 0
                          ? 'Subiendo ${biblioteca.syncActual}/${biblioteca.syncTotal}'
                          : 'Sincronizando...')
                      : 'Sincronizar ahora',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Anuncio de sin conexión (mantiene textos exactos para pruebas unitarias)
class _AnuncioSinConexion extends StatefulWidget {
  final BibliotecaController biblioteca;

  const _AnuncioSinConexion({required this.biblioteca});

  @override
  State<_AnuncioSinConexion> createState() => _AnuncioSinConexionState();
}

class _AnuncioSinConexionState extends State<_AnuncioSinConexion> {
  bool _reconectando = false;

  Future<void> _intentarRestablecer() async {
    setState(() => _reconectando = true);
    final exito = await widget.biblioteca.restablecerConexion();
    if (!mounted) return;
    setState(() => _reconectando = false);

    if (exito) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conexión con el servidor restablecida con éxito.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo restablecer la conexión. El backend sigue sin responder.',
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorAlerta = Colors.amber.shade800;

    return Card(
      elevation: 0,
      color: colorAlerta.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorAlerta.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorAlerta.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.cloud_off_rounded,
                    color: colorAlerta,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sin conexión con el backend',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: colorAlerta,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Modo fuera de línea activo',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'No se puede comunicar con el servidor backend. Puedes seguir consultando o registrando libros guardados en este dispositivo.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => showBackendConnectionSheet(
                    context,
                    onRetry: widget.biblioteca.refrescar,
                  ),
                  icon: const Icon(Icons.info_outline, size: 16),
                  label: const Text('Diagnóstico'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _reconectando ? null : _intentarRestablecer,
                  style: FilledButton.styleFrom(
                    backgroundColor: colorAlerta,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: _reconectando
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.refresh, size: 16),
                  label: Text(
                    _reconectando ? 'Restableciendo...' : 'Restablecer conexión',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
