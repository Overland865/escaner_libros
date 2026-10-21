import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/biblioteca_controller.dart';
import '../widgets/backend_connection_sheet.dart';
import '../widgets/book_card.dart';

/// Pestaña 3 — Listado completo del archivo con buscador, filtros y paginación incremental.
class LibraryTab extends StatefulWidget {
  final BibliotecaController biblioteca;

  const LibraryTab({super.key, required this.biblioteca});

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;
  String _campoBusqueda = 'todos';

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.biblioteca.busqueda;
    _campoBusqueda = widget.biblioteca.campoBusqueda;
    widget.biblioteca.addListener(_alCambiarBusqueda);
    _scrollController.addListener(_alScrollear);
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

  /// Rebote de 400 ms para no disparar una petición por tecla.
  void _programarBusqueda(String texto, {String? campo}) {
    if (campo != null) _campoBusqueda = campo;
    widget.biblioteca.buscar(texto, campo: _campoBusqueda);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      widget.biblioteca.cargar(busqueda: texto, campoBusqueda: _campoBusqueda);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.biblioteca,
      builder: (context, _) {
        final b = widget.biblioteca;
        final colors = Theme.of(context).colorScheme;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                keyboardType: _campoBusqueda == 'anio'
                    ? TextInputType.number
                    : TextInputType.text,
                textInputAction: TextInputAction.search,
                onChanged: _programarBusqueda,
                onSubmitted: (q) {
                  _debounce?.cancel();
                  widget.biblioteca.cargar(
                    busqueda: q,
                    campoBusqueda: _campoBusqueda,
                  );
                },
                decoration: InputDecoration(
                  hintText: 'Escribe lo que quieres buscar...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: b.busqueda.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _debounce?.cancel();
                            _searchController.clear();
                            widget.biblioteca.cargar(
                              busqueda: '',
                              campoBusqueda: _campoBusqueda,
                            );
                          },
                        ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: DropdownButtonFormField<String>(
                initialValue: _campoBusqueda,
                decoration: const InputDecoration(
                  labelText: 'Buscar por',
                  prefixIcon: Icon(Icons.filter_list),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'todos',
                    child: Text('Todos los campos'),
                  ),
                  DropdownMenuItem(value: 'titulo', child: Text('Título')),
                  DropdownMenuItem(value: 'iglesia', child: Text('Parroquia')),
                  DropdownMenuItem(value: 'autor', child: Text('Autor')),
                  DropdownMenuItem(
                    value: 'tipo_libro',
                    child: Text('Tipo de libro'),
                  ),
                  DropdownMenuItem(value: 'anio', child: Text('Año')),
                  DropdownMenuItem(
                    value: 'isbn_o_codigo',
                    child: Text('Código'),
                  ),
                ],
                onChanged: (campo) {
                  if (campo != null) {
                    _programarBusqueda(_searchController.text, campo: campo);
                  }
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Documentos Registrados',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                    ),
                  ),
                  if (b.estado == EstadoCarga.listo)
                    Text(
                      b.totalRemoto > b.libros.length
                          ? '${b.libros.length} de ${b.totalRemoto} libros'
                          : '${b.libros.length} encontrados',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
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

  Widget _cuerpo(BibliotecaController b) {
    if (b.estado == EstadoCarga.cargando) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
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

    if (b.libros.isEmpty) {
      final filtrando = b.busqueda.isNotEmpty;
      return RefreshIndicator(
        onRefresh: b.refrescar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 60),
            Icon(
              filtrando ? Icons.search_off : Icons.library_books,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                filtrando
                    ? 'Sin resultados para "${b.busqueda}"'
                    : 'No hay libros registrados aún',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                filtrando
                    ? 'Prueba con otro término de búsqueda.'
                    : 'Usa la pestaña Escanear para digitalizar el primero.',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    final tieneHeaderDegradado = b.modoDegradado;
    final tieneItemCargaMas = b.hayMas || b.cargandoMas;
    final totalItems =
        b.libros.length +
        (tieneHeaderDegradado ? 1 : 0) +
        (tieneItemCargaMas ? 1 : 0);

    return RefreshIndicator(
      onRefresh: b.refrescar,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        itemCount: totalItems,
        itemBuilder: (context, i) {
          if (tieneHeaderDegradado && i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.cloud_off,
                        size: 18,
                        color: Theme.of(context)
                            .colorScheme
                            .onTertiaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Mostrando libros guardados en el dispositivo '
                          '(sin conexión al servidor).',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onTertiaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final indiceLibro = tieneHeaderDegradado ? i - 1 : i;

          if (tieneItemCargaMas && indiceLibro == b.libros.length) {
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

          final libro = b.libros[indiceLibro];
          return BookCard(libro: libro, pendiente: b.esPendiente(libro.id));
        },
      ),
    );
  }
}
