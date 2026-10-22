import 'package:flutter/material.dart';

import '../../controllers/biblioteca_controller.dart';
import '../widgets/book_card.dart';

/// Pestaña 1 — Resumen del archivo y acceso a libros.
class HomeTab extends StatelessWidget {
  final BibliotecaController biblioteca;
  final VoidCallback onEscanear;
  final VoidCallback onVerLibros;

  const HomeTab({
    super.key,
    required this.biblioteca,
    required this.onEscanear,
    required this.onVerLibros,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: biblioteca,
      builder: (context, _) {
        return RefreshIndicator(
          onRefresh: biblioteca.refrescar,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              _Banner(onEscanear: onEscanear),
              const SizedBox(height: 20),
              if (biblioteca.pendientesCount > 0) ...[
                _TarjetaPendientes(biblioteca: biblioteca),
                const SizedBox(height: 20),
              ],
              _SeccionTitulo(
                titulo: 'Libros registrados',
                accion: biblioteca.estado == EstadoCarga.listo
                    ? 'Ver todos (${biblioteca.totalRemoto})'
                    : null,
                onAccion: onVerLibros,
              ),
              const SizedBox(height: 12),
              if (biblioteca.estado == EstadoCarga.cargando &&
                  biblioteca.libros.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (biblioteca.libros.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Text(
                      biblioteca.estado == EstadoCarga.error
                          ? 'No se pudieron cargar los libros.'
                          : 'Aún no hay libros registrados.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                ...biblioteca.libros.map(
                  (libro) => BookCard(
                    libro: libro,
                    pendiente: biblioteca.esPendiente(libro.id),
                    errorSync: biblioteca.errorSyncDe(libro.id),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TarjetaPendientes extends StatelessWidget {
  final BibliotecaController biblioteca;
  const _TarjetaPendientes({required this.biblioteca});

  @override
  Widget build(BuildContext context) {
    final n = biblioteca.pendientesCount;
    final etiqueta = n == 1
        ? '1 libro pendiente de sincronizar'
        : '$n libros pendientes de sincronizar';

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.tertiaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.tertiary),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.cloud_upload_outlined,
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    etiqueta,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Están guardados en el dispositivo. Se subirán al servidor '
              'cuando haya conexión.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onTertiaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: biblioteca.sincronizando
                    ? null
                    : () async {
                        final r = await biblioteca.sincronizarAhora();
                        if (!context.mounted) return;
                        final msg = r.sinConexion
                            ? 'Sin conexión con el servidor. Los pendientes se mantienen.'
                            : r.exitosos > 0
                            ? 'Sincronizados: ${r.exitosos}.'
                            : r.fallidos > 0
                            ? 'No se pudo sincronizar. Reintentá más tarde.'
                            : 'No había pendientes.';
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(msg)));
                      },
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
                      ? 'Sincronizando...'
                      : 'Sincronizar ahora',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final VoidCallback onEscanear;
  const _Banner({required this.onEscanear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Archivo Histórico',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Digitalización y transcripción de libros parroquiales con IA.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: onEscanear,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1A237E),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text(
                    'Nuevo Libro',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.menu_book, color: Colors.white, size: 44),
          ),
        ],
      ),
    );
  }
}

class _SeccionTitulo extends StatelessWidget {
  final String titulo;
  final String? accion;
  final VoidCallback? onAccion;

  const _SeccionTitulo({required this.titulo, this.accion, this.onAccion});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          titulo,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        if (accion != null)
          TextButton(onPressed: onAccion, child: Text(accion!)),
      ],
    );
  }
}
