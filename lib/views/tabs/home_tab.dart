import 'package:flutter/material.dart';

import '../../controllers/biblioteca_controller.dart';
import '../widgets/book_card.dart';
import '../widgets/backend_connection_sheet.dart';

/// Pestaña 1 — Resumen del archivo y acceso a libros.
class HomeTab extends StatelessWidget {
  final BibliotecaController biblioteca;
  final VoidCallback? onEscanear;
  final VoidCallback onVerLibros;

  const HomeTab({
    super.key,
    required this.biblioteca,
    this.onEscanear,
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
              if (biblioteca.sinConexion) ...[
                _AnuncioSinConexion(biblioteca: biblioteca),
                const SizedBox(height: 16),
              ],
              if (biblioteca.pendientesCount > 0) ...[
                _TarjetaPendientes(biblioteca: biblioteca),
                const SizedBox(height: 16),
              ],
              if (biblioteca.estado == EstadoCarga.cargando &&
                  biblioteca.libros.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (biblioteca.libros.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161824),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF26293A)),
                          ),
                          child: Icon(
                            biblioteca.sinConexion
                                ? Icons.cloud_off_rounded
                                : Icons.auto_stories_outlined,
                            size: 40,
                            color: const Color(0xFF818CF8),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          biblioteca.sinConexion
                              ? 'Sin conexión con el servidor para cargar libros.'
                              : biblioteca.estado == EstadoCarga.error
                              ? 'No se pudieron cargar los libros.'
                              : 'Aún no hay libros registrados.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
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

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1912),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.amber.shade700.withValues(alpha: 0.5),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                    color: Colors.amber.shade900.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.cloud_upload_outlined,
                    color: Colors.amber.shade300,
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
                      color: Colors.amber.shade200,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Están guardados en el dispositivo. Se subirán al servidor '
              'cuando haya conexión.',
              style: TextStyle(
                fontSize: 12.5,
                color: Color(0xFFC7BBA8),
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
                  backgroundColor: Colors.amber.shade900.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.amber.shade400),
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
                  color: Colors.amber.shade200,
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
                  backgroundColor: Colors.amber.shade700,
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
    final colorAlerta = Colors.amber.shade700;

    return Card(
      elevation: 0,
      color: colorAlerta.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorAlerta.withValues(alpha: 0.5), width: 1.2),
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
                    _reconectando
                        ? 'Restableciendo...'
                        : 'Restablecer conexión',
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
