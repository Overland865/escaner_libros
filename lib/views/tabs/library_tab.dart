import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/biblioteca_controller.dart';
import '../../models/libro_model.dart';
import '../../services/local_user_preferences_store.dart';
import '../book_detail_screen.dart';
import '../widgets/backend_connection_sheet.dart';
import '../widgets/book_card.dart';

/// Criterios de ordenamiento para el catálogo de libros.
enum CriterioOrden {
  tituloAZ,
  tituloZA,
  anioReciente,
  anioAntiguo,
  paginasMayor,
}

/// Pestaña 3 — Listado completo del archivo con buscador universal, filtros por categoría/lectura, favoritos y ordenamiento.
class LibraryTab extends StatefulWidget {
  final BibliotecaController biblioteca;

  const LibraryTab({super.key, required this.biblioteca});

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final LocalUserPreferencesStore _prefs = LocalUserPreferencesStore();

  Timer? _debounce;
  String _filtroRapido = 'todos'; // 'todos', 'favoritos', 'en_lectura'
  String _categoriaSeleccionada = 'Todas';
  CriterioOrden _criterioOrden = CriterioOrden.tituloAZ;
  bool _vistaCuadricula = true; // Vista cuadrícula por defecto modelada en Stitch
  Set<String> _favoritos = <String>{};
  Set<String> _librosConMarcadores = <String>{};
  Map<String, ProgresoLectura> _progresos = {};

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.biblioteca.busqueda;
    widget.biblioteca.addListener(_alCambiarBusqueda);
    _scrollController.addListener(_alScrollear);
    _cargarDatosLocales();
  }

  Future<void> _cargarDatosLocales() async {
    try {
      final favs = await _prefs.obtenerFavoritos();
      final progs = <String, ProgresoLectura>{};
      final enLectura = <String>{};
      for (final l in widget.biblioteca.libros) {
        try {
          final p = await _prefs.obtenerProgreso(l.id);
          if (p != null) {
            progs[l.id] = p;
            final totalReal =
                l.paginas.isNotEmpty ? l.paginas.length : p.totalPaginas;
            if (totalReal > 0 && p.ultimaPagina >= 0 && p.ultimaPagina < totalReal - 1) {
              enLectura.add(l.id);
            }
          }
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _favoritos = favs;
          _librosConMarcadores = enLectura;
          _progresos = progs;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.removeListener(_alScrollear);
    _scrollController.dispose();
    widget.biblioteca.removeListener(_alCambiarBusqueda);
    _searchController.dispose();
    super.dispose();
  }

  void _alScrollear() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 250) {
      widget.biblioteca.cargarMas();
    }
  }

  /// Mantiene el campo sincronizado si la búsqueda se borra desde otro lado.
  void _alCambiarBusqueda() {
    if (_searchController.text == widget.biblioteca.busqueda) return;
    _searchController.value = TextEditingValue(
      text: widget.biblioteca.busqueda,
      selection: TextSelection.collapsed(
        offset: widget.biblioteca.busqueda.length,
      ),
    );
  }

  /// Rebote de 400 ms: busca universalmente en todos los campos (título, autor, editorial, año, etc.).
  void _programarBusqueda(String texto) {
    widget.biblioteca.buscar(texto, campo: 'todos');
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      widget.biblioteca.cargar(busqueda: texto, campoBusqueda: 'todos');
    });
  }

  void _restablecerFiltros() {
    setState(() {
      _filtroRapido = 'todos';
      _categoriaSeleccionada = 'Todas';
      _criterioOrden = CriterioOrden.tituloAZ;
    });
    if (_searchController.text.isNotEmpty) {
      _debounce?.cancel();
      _searchController.clear();
      widget.biblioteca.cargar(busqueda: '', campoBusqueda: 'todos');
    }
  }

  List<String> _obtenerCategorias(List<LibroModel> libros) {
    final categorias = <String>{};
    for (final l in libros) {
      final t = l.tipoLibro.trim();
      if (t.isNotEmpty && t != 'General') {
        categorias.add(t);
      }
    }
    final lista = categorias.toList()..sort();
    return lista;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.biblioteca,
      builder: (context, _) {
        final b = widget.biblioteca;
        final hayFiltroActivo = b.busqueda.isNotEmpty ||
            _filtroRapido != 'todos' ||
            _categoriaSeleccionada != 'Todas';

        return Column(
          children: [
            // Buscador universal
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: TextField(
                controller: _searchController,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.search,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14.5),
                onChanged: _programarBusqueda,
                onSubmitted: (q) {
                  _debounce?.cancel();
                  widget.biblioteca.cargar(
                    busqueda: q,
                    campoBusqueda: 'todos',
                  );
                },
                decoration: InputDecoration(
                  hintText: 'Buscar por título, autor, editorial, año...',
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainer,
                  prefixIcon: Icon(Icons.search_rounded, color: Theme.of(context).colorScheme.secondary),
                  suffixIcon: b.busqueda.isEmpty
                      ? null
                      : IconButton(
                          icon: Icon(Icons.clear, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          onPressed: () {
                            _debounce?.cancel();
                            _searchController.clear();
                            widget.biblioteca.cargar(
                              busqueda: '',
                              campoBusqueda: 'todos',
                            );
                          },
                        ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant, width: 1.2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.secondary, width: 1.5),
                  ),
                ),
              ),
            ),

            // Barra de filtros rápidos por chips (Categorías, Favoritos, En lectura)
            _barraFiltrosRapidos(b),

            const SizedBox(height: 10),

            // Barra de herramientas: resumen de conteo, botón de orden y vista lista/cuadrícula
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      hayFiltroActivo
                          ? 'Filtro aplicado'
                          : '${b.libros.length} libros en catálogo',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                  if (hayFiltroActivo)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        visualDensity: VisualDensity.compact,
                        foregroundColor: Theme.of(context).colorScheme.secondary,
                      ),
                      onPressed: _restablecerFiltros,
                      icon: const Icon(Icons.close_rounded, size: 14),
                      label: const Text('Limpiar', style: TextStyle(fontSize: 12)),
                    ),
                  // Botón de ordenamiento
                  _botonOrdenar(),
                  const SizedBox(width: 4),
                  // Toggle Lista / Cuadrícula
                  IconButton(
                    icon: Icon(
                      _vistaCuadricula
                          ? Icons.view_list_rounded
                          : Icons.grid_view_rounded,
                      color: Theme.of(context).colorScheme.secondary,
                      size: 21,
                    ),
                    tooltip: _vistaCuadricula
                        ? 'Vista de lista'
                        : 'Vista de cuadrícula',
                    visualDensity: VisualDensity.compact,
                    onPressed: () =>
                        setState(() => _vistaCuadricula = !_vistaCuadricula),
                  ),
                ],
              ),
            ),
            Expanded(child: _cuerpo(b)),
          ],
        );
      },
    );
  }

  Widget _barraFiltrosRapidos(BibliotecaController b) {
    final theme = Theme.of(context);
    final categorias = _obtenerCategorias(b.libros);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Chip Todos
          _chipFiltro(
            etiqueta: 'Todos (${b.libros.length})',
            icono: Icons.auto_stories_rounded,
            esActivo: _filtroRapido == 'todos' && _categoriaSeleccionada == 'Todas',
            colorActivo: theme.colorScheme.secondary,
            alTocar: () {
              setState(() {
                _filtroRapido = 'todos';
                _categoriaSeleccionada = 'Todas';
              });
            },
          ),
          const SizedBox(width: 8),

          // Chip Favoritos
          _chipFiltro(
            etiqueta: _favoritos.isNotEmpty
                ? 'Favoritos (${_favoritos.length})'
                : 'Favoritos',
            icono: Icons.star_rounded,
            esActivo: _filtroRapido == 'favoritos',
            colorActivo: const Color(0xFFD4A373),
            colorIcono: const Color(0xFFD4A373),
            alTocar: () {
              setState(() {
                if (_filtroRapido == 'favoritos') {
                  _filtroRapido = 'todos';
                } else {
                  _filtroRapido = 'favoritos';
                  _categoriaSeleccionada = 'Todas';
                }
              });
            },
          ),
          const SizedBox(width: 8),

          // Chip En lectura
          _chipFiltro(
            etiqueta: _librosConMarcadores.isNotEmpty
                ? 'En lectura (${_librosConMarcadores.length})'
                : 'En lectura',
            icono: Icons.bookmark_rounded,
            esActivo: _filtroRapido == 'en_lectura',
            colorActivo: const Color(0xFF8C4E26),
            colorIcono: const Color(0xFF8C4E26),
            alTocar: () {
              setState(() {
                if (_filtroRapido == 'en_lectura') {
                  _filtroRapido = 'todos';
                } else {
                  _filtroRapido = 'en_lectura';
                  _categoriaSeleccionada = 'Todas';
                }
              });
            },
          ),

          // Chips de categorías dinámicas
          for (final cat in categorias) ...[
            const SizedBox(width: 8),
            _chipFiltro(
              etiqueta: cat,
              icono: Icons.category_outlined,
              esActivo: _categoriaSeleccionada == cat,
              colorActivo: theme.colorScheme.secondary,
              alTocar: () {
                setState(() {
                  if (_categoriaSeleccionada == cat) {
                    _categoriaSeleccionada = 'Todas';
                  } else {
                    _categoriaSeleccionada = cat;
                    _filtroRapido = 'todos';
                  }
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _chipFiltro({
    required String etiqueta,
    required IconData icono,
    required bool esActivo,
    required VoidCallback alTocar,
    required Color colorActivo,
    Color? colorIcono,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: alTocar,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: esActivo
                ? colorActivo.withValues(alpha: isDark ? 0.3 : 0.16)
                : theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: esActivo ? colorActivo : theme.colorScheme.outlineVariant,
              width: esActivo ? 1.4 : 1.0,
            ),
            boxShadow: esActivo
                ? [
                    BoxShadow(
                      color: colorActivo.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icono,
                size: 15,
                color: esActivo
                    ? colorActivo
                    : (colorIcono ?? theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(width: 6),
              Text(
                etiqueta,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: esActivo ? FontWeight.w600 : FontWeight.w500,
                  color: esActivo
                      ? (isDark ? Colors.white : colorActivo)
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _botonOrdenar() {
    final theme = Theme.of(context);

    return PopupMenuButton<CriterioOrden>(
      initialValue: _criterioOrden,
      tooltip: 'Ordenar libros',
      color: theme.cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Icon(
          Icons.swap_vert_rounded,
          color: theme.colorScheme.secondary,
          size: 19,
        ),
      ),
      onSelected: (criterio) => setState(() => _criterioOrden = criterio),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: CriterioOrden.tituloAZ,
          child: Row(
            children: [
              Icon(Icons.sort_by_alpha_rounded, size: 18, color: theme.colorScheme.secondary),
              const SizedBox(width: 10),
              Text('Título (A → Z)', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: CriterioOrden.tituloZA,
          child: Row(
            children: [
              Icon(Icons.sort_by_alpha_rounded, size: 18, color: theme.colorScheme.secondary),
              const SizedBox(width: 10),
              Text('Título (Z → A)', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: CriterioOrden.anioReciente,
          child: Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 18, color: theme.colorScheme.secondary),
              const SizedBox(width: 10),
              Text('Año (Más reciente)', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: CriterioOrden.anioAntiguo,
          child: Row(
            children: [
              Icon(Icons.history_rounded, size: 18, color: theme.colorScheme.secondary),
              const SizedBox(width: 10),
              Text('Año (Más antiguo)', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: CriterioOrden.paginasMayor,
          child: Row(
            children: [
              Icon(Icons.menu_book_rounded, size: 18, color: theme.colorScheme.secondary),
              const SizedBox(width: 10),
              Text('Páginas (Mayor a menor)', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cuerpo(BibliotecaController b) {
    if (b.estado == EstadoCarga.cargando) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF6366F1)),
            SizedBox(height: 12),
            Text(
              'Cargando biblioteca...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (b.estado == EstadoCarga.error) {
      final sinConexion = b.errorEsConexion;
      return ListView(
        children: [
          const SizedBox(height: 60),
          Icon(
            sinConexion ? Icons.cloud_off : Icons.error_outline,
            size: 54,
            color: sinConexion
                ? Colors.grey.shade400
                : Theme.of(context).colorScheme.tertiary,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              sinConexion ? 'Servidor no disponible' : 'No se pudo consultar',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              b.error ?? 'Error desconocido.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: sinConexion
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : Theme.of(context).colorScheme.tertiary,
              ),
            ),
          ),
          if (b.saludMongo != null && b.saludMongo != 'conectado')
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
              child: Text(
                'El servidor responde, pero MongoDB Atlas no. Atlas pausa el '
                'cluster tras 5 min de inactividad y tarda unos segundos en '
                'despertar. Reintenta en un momento.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ),
            ),
          const SizedBox(height: 18),
          Center(
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () =>
                      showBackendConnectionSheet(context, onRetry: b.refrescar),
                  icon: const Icon(Icons.cloud_outlined),
                  label: const Text('Ver conexión'),
                ),
                ElevatedButton.icon(
                  onPressed: b.refrescar,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // 1. Filtrado dinámico por favoritos o lecturas activas
    var librosFiltrados = List<LibroModel>.from(b.libros);
    if (_filtroRapido == 'favoritos') {
      librosFiltrados = librosFiltrados.where((l) => _favoritos.contains(l.id)).toList();
    } else if (_filtroRapido == 'en_lectura') {
      librosFiltrados = librosFiltrados.where((l) => _librosConMarcadores.contains(l.id)).toList();
    }

    // 2. Filtrado por género / categoría seleccionada
    if (_categoriaSeleccionada != 'Todas') {
      librosFiltrados = librosFiltrados.where((l) {
        return l.tipoLibro.trim().toLowerCase() ==
            _categoriaSeleccionada.trim().toLowerCase();
      }).toList();
    }

    // 3. Ordenamiento según el criterio seleccionado
    switch (_criterioOrden) {
      case CriterioOrden.tituloAZ:
        librosFiltrados.sort(
          (a, b) => a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase()),
        );
        break;
      case CriterioOrden.tituloZA:
        librosFiltrados.sort(
          (a, b) => b.titulo.toLowerCase().compareTo(a.titulo.toLowerCase()),
        );
        break;
      case CriterioOrden.anioReciente:
        librosFiltrados.sort((a, b) => b.anioInicio.compareTo(a.anioInicio));
        break;
      case CriterioOrden.anioAntiguo:
        librosFiltrados.sort((a, b) => a.anioInicio.compareTo(b.anioInicio));
        break;
      case CriterioOrden.paginasMayor:
        librosFiltrados.sort(
          (a, b) => b.paginas.length.compareTo(a.paginas.length),
        );
        break;
    }

    final hayFiltroActivo = b.busqueda.isNotEmpty ||
        _filtroRapido != 'todos' ||
        _categoriaSeleccionada != 'Todas';

    if (b.libros.isEmpty || librosFiltrados.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          await b.refrescar();
          await _cargarDatosLocales();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          children: [
            const SizedBox(height: 60),
            Center(
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  _filtroRapido == 'favoritos'
                      ? Icons.star_border_rounded
                      : _filtroRapido == 'en_lectura'
                          ? Icons.bookmark_border_rounded
                          : hayFiltroActivo
                              ? Icons.search_off_rounded
                              : Icons.menu_book_rounded,
                  size: 44,
                  color: _filtroRapido == 'favoritos'
                      ? const Color(0xFFD4A373)
                      : _filtroRapido == 'en_lectura'
                          ? const Color(0xFF8C4E26)
                          : Theme.of(context).colorScheme.secondary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                _filtroRapido == 'favoritos'
                    ? 'No hay libros favoritos'
                    : _filtroRapido == 'en_lectura'
                        ? 'No tienes lecturas iniciadas'
                        : _categoriaSeleccionada != 'Todas'
                            ? 'No hay libros en "$_categoriaSeleccionada"'
                            : b.busqueda.isNotEmpty
                                ? 'Sin resultados para "${b.busqueda}"'
                                : 'No hay libros registrados aún',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                _filtroRapido == 'favoritos'
                    ? 'Toca la estrella ⭐ en el detalle de cualquier libro para guardarlo en favoritos.'
                    : _filtroRapido == 'en_lectura'
                        ? 'Abre cualquier libro en modo lectura para continuar leyéndolo desde aquí.'
                        : hayFiltroActivo
                            ? 'Prueba seleccionando otra categoría o borra el texto de búsqueda.'
                            : 'Usa el botón Escanear o Subir PDF para digitalizar el primero.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
            if (hayFiltroActivo) ...[
              const SizedBox(height: 18),
              Center(
                child: OutlinedButton.icon(
                  onPressed: _restablecerFiltros,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Ver todos los libros'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.secondary,
                    side: BorderSide(color: Theme.of(context).colorScheme.secondary, width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    final tieneHeaderDegradado = b.modoDegradado;
    final tieneItemCargaMas = b.hayMas || b.cargandoMas;

    if (_vistaCuadricula) {
      return RefreshIndicator(
        onRefresh: () async {
          await b.refrescar();
          await _cargarDatosLocales();
        },
        child: GridView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.58,
            crossAxisSpacing: 14,
            mainAxisSpacing: 16,
          ),
          itemCount: librosFiltrados.length,
          itemBuilder: (context, i) {
            final libro = librosFiltrados[i];
            return _GridBookCard(
              libro: libro,
              pendiente: b.esPendiente(libro.id),
              esFavorito: _favoritos.contains(libro.id),
              progreso: _progresos[libro.id],
              onRetorno: _cargarDatosLocales,
            );
          },
        ),
      );
    }

    final totalItems =
        librosFiltrados.length +
        (tieneHeaderDegradado ? 1 : 0) +
        (tieneItemCargaMas ? 1 : 0);

    return RefreshIndicator(
      onRefresh: () async {
        await b.refrescar();
        await _cargarDatosLocales();
      },
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        itemCount: totalItems,
        itemBuilder: (context, i) {
          if (tieneHeaderDegradado && i == 0) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1912),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.amber.shade700.withValues(alpha: 0.5),
                  width: 1.1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 18,
                    color: Colors.amber.shade300,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Mostrando libros guardados en el dispositivo '
                      '(sin conexión al servidor).',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFC7BBA8),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final indiceLibro = tieneHeaderDegradado ? i - 1 : i;

          if (tieneItemCargaMas && indiceLibro == librosFiltrados.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: b.cargandoMas
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Cargando más libros...',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      )
                    : OutlinedButton.icon(
                        onPressed: b.cargarMas,
                        icon: const Icon(Icons.arrow_downward, size: 16),
                        label: const Text('Cargar más libros'),
                      ),
              ),
            );
          }

          final libro = librosFiltrados[indiceLibro];
          return BookCard(
            libro: libro,
            pendiente: b.esPendiente(libro.id),
            errorSync: b.errorSyncDe(libro.id),
            esFavorito: _favoritos.contains(libro.id),
            onRetorno: _cargarDatosLocales,
          );
        },
      ),
    );
  }
}

class _GridBookCard extends StatelessWidget {
  final LibroModel libro;
  final bool pendiente;
  final bool esFavorito;
  final ProgresoLectura? progreso;
  final VoidCallback? onRetorno;

  const _GridBookCard({
    required this.libro,
    required this.pendiente,
    required this.esFavorito,
    this.progreso,
    this.onRetorno,
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

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: pendiente
              ? Colors.amber.shade700.withValues(alpha: 0.5)
              : theme.colorScheme.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BookDetailScreen(
                  idLibro: libro.id,
                  titulo: libro.titulo,
                  libroLocal: pendiente ? libro : null,
                ),
              ),
            );
            onRetorno?.call();
          },
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Portada de libro con aspecto editorial y lomo
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                          blurRadius: 6,
                          offset: const Offset(1, 3),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Franja de efecto de lomo a la izquierda
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
                        // Contenido de la portada
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.65),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        tipo.contains('pdf')
                                            ? 'PDF'
                                            : libro.tipoLibro.replaceFirst(RegExp(r'^Category:\s*', caseSensitive: false), ''),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFFCF9F4),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (esFavorito) ...[
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.star_rounded,
                                      color: Color(0xFFD4A373),
                                      size: 16,
                                    ),
                                  ],
                                ],
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
                                  fontSize: 10.5,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                libro.autor,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Newsreader',
                                  color: const Color(0xFFFCF9F4).withValues(alpha: 0.8),
                                  fontSize: 9,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Metadatos fuera de la portada
                Text(
                  libro.titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Literata',
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  libro.autor.isEmpty ? 'Autor no especificado' : libro.autor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Newsreader',
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                // Medidor de progreso dorado
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      esCompletado
                          ? 'Completado'
                          : porcentajeEntero > 0
                              ? 'Leído'
                              : '${libro.anioInicio}',
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      esCompletado
                          ? '100%'
                          : porcentajeEntero > 0
                              ? '$porcentajeEntero%'
                              : '${libro.paginas.length} pág.',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: porcentajeEntero > 0 ? porcentaje : 0.0,
                    minHeight: 3,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.secondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
