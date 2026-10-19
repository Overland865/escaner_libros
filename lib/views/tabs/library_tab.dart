import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/biblioteca_controller.dart';
import '../../models/libro_model.dart';
import '../book_detail_screen.dart';
import '../widgets/server_settings_sheet.dart';

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

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.biblioteca.busqueda;
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
      selection: TextSelection.collapsed(offset: widget.biblioteca.busqueda.length),
    );
  }

  /// Rebote de 400 ms para no disparar una petición por tecla.
  void _programarBusqueda(String texto) {
    widget.biblioteca.buscar(texto);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      widget.biblioteca.cargar();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.biblioteca,
      builder: (context, _) {
        final b = widget.biblioteca;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onChanged: _programarBusqueda,
                onSubmitted: (q) {
                  _debounce?.cancel();
                  widget.biblioteca.cargar(busqueda: q);
                },
                decoration: InputDecoration(
                  hintText: 'Buscar libro, parroquia o año...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: b.busqueda.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _debounce?.cancel();
                            _searchController.clear();
                            widget.biblioteca.cargar(busqueda: '');
                          },
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Documentos Registrados',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                  if (b.estado == EstadoCarga.listo)
                    Text(
                      b.totalRemoto > b.libros.length
                          ? '${b.libros.length} de ${b.totalRemoto} libros'
                          : '${b.libros.length} encontrados',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
            Text('Cargando biblioteca...', style: TextStyle(color: Colors.grey)),
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
            color: sinConexion ? Colors.grey.shade400 : Colors.amber.shade700,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              sinConexion ? 'Servidor no disponible' : 'No se pudo consultar',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
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
                color: sinConexion ? Colors.grey : Colors.amber.shade900,
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
                style: TextStyle(fontSize: 12, color: Colors.amber.shade800),
              ),
            ),
          const SizedBox(height: 18),
          Center(
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => showServerSettingsSheet(
                    context,
                    onGuardado: b.refrescar,
                  ),
                  icon: const Icon(Icons.settings),
                  label: const Text('Cambiar servidor / Clave'),
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
    final totalItems = b.libros.length +
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
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_off, size: 18, color: Colors.amber.shade900),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Mostrando libros guardados en el dispositivo '
                          '(sin conexión al servidor).',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber.shade900,
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
          return _TarjetaLibro(
            libro: libro,
            pendiente: b.esPendiente(libro.id),
          );
        },
      ),
    );
  }
}

class _TarjetaLibro extends StatelessWidget {
  final LibroModel libro;
  final bool pendiente;

  const _TarjetaLibro({required this.libro, this.pendiente = false});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (pendiente) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Este libro aún no está en el servidor. '
                  'Sincronizalo desde Inicio para ver el detalle completo.',
                ),
              ),
            );
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BookDetailScreen(
                idLibro: libro.id,
                titulo: libro.titulo,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EAF6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.auto_stories,
                      color: Color(0xFF283593),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          libro.titulo,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A237E),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          libro.iglesia.isNotEmpty
                              ? libro.iglesia
                              : 'Parroquia no especificada',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          libro.tipoLibro,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (pendiente) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber.shade400),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.cloud_upload_outlined,
                                size: 12,
                                color: Colors.amber.shade900,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Pendiente de subir',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.date_range,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${libro.anioInicio} - ${libro.anioFin}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
