import 'package:flutter/material.dart';

import '../../controllers/biblioteca_controller.dart';
import '../../services/api_service.dart';
import '../widgets/server_settings_sheet.dart';

/// Pestaña 1 — Resumen del archivo y estado de la conexión con el backend.
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
                titulo: 'Estado del Archivo',
                accion:
                    biblioteca.estado == EstadoCarga.listo ? 'Ver todos' : null,
                onAccion: onVerLibros,
              ),
              const SizedBox(height: 12),
              _TarjetasMetricas(biblioteca: biblioteca),
              const SizedBox(height: 20),
              _SeccionTitulo(titulo: 'Conexión'),
              const SizedBox(height: 12),
              _TarjetaConexion(biblioteca: biblioteca),
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
      color: const Color(0xFFFFF8E1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.amber.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_upload_outlined, color: Colors.amber.shade900),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    etiqueta,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Están guardados en el dispositivo. Se subirán al servidor '
              'cuando haya conexión.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(msg)),
                        );
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

class _TarjetasMetricas extends StatelessWidget {
  final BibliotecaController biblioteca;
  const _TarjetasMetricas({required this.biblioteca});

  @override
  Widget build(BuildContext context) {
    final cargando = biblioteca.estado == EstadoCarga.cargando;
    return Row(
      children: [
        Expanded(
          child: _Metrica(
            icono: Icons.auto_stories,
            valor: cargando ? '—' : '${biblioteca.libros.length}',
            etiqueta: 'Documentos',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _Metrica(
            icono: Icons.category_outlined,
            valor: cargando ? '—' : '${biblioteca.totalTipos}',
            etiqueta: 'Tipos',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _Metrica(
            icono: Icons.history_toggle_off,
            valor: cargando || biblioteca.antiguedadAnios == 0
                ? '—'
                : '${biblioteca.antiguedadAnios} años',
            etiqueta: 'Antigüedad',
          ),
        ),
      ],
    );
  }
}

class _Metrica extends StatelessWidget {
  final IconData icono;
  final String valor;
  final String etiqueta;

  const _Metrica({
    required this.icono,
    required this.valor,
    required this.etiqueta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icono, color: const Color(0xFF283593), size: 24),
          const SizedBox(height: 8),
          FittedBox(
            child: Text(
              valor,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF1A237E),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            etiqueta,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _TarjetaConexion extends StatelessWidget {
  final BibliotecaController biblioteca;
  const _TarjetaConexion({required this.biblioteca});

  static String _etiquetaEntorno(String url) {
    final u = url.toLowerCase();
    if (u.startsWith('https://') &&
        !u.contains('localhost') &&
        !u.contains('10.0.2.2') &&
        !u.contains('192.168.')) {
      return 'Modo producción (backend desplegado)';
    }
    if (u.contains('10.0.2.2')) {
      return 'Desarrollo: emulador Android → PC';
    }
    if (u.contains('localhost') || u.contains('127.0.0.1')) {
      return 'Desarrollo: solo funciona en la misma máquina';
    }
    if (u.startsWith('http://')) {
      return 'Desarrollo: red local (PC debe estar encendida)';
    }
    return 'Backend configurado';
  }

  @override
  Widget build(BuildContext context) {
    // Hay tres estados distintos y antes todos se veían igual:
    // servidor caído, Atlas caído y error puntual del servidor.
    final caido = !biblioteca.servidorAlcanzable;
    final atlasCaido = biblioteca.saludMongo == 'desconectado';

    final Color color;
    final IconData icono;
    final String titulo;
    if (caido) {
      color = Colors.red.shade700;
      icono = Icons.cloud_off;
      titulo = 'Backend no disponible';
    } else if (atlasCaido) {
      color = Colors.amber.shade800;
      icono = Icons.cloud_queue;
      titulo = 'Atlas despertando';
    } else if (biblioteca.error != null) {
      color = Colors.amber.shade800;
      icono = Icons.warning_amber;
      titulo = 'Error en la consulta';
    } else {
      color = Colors.green.shade700;
      icono = Icons.cloud_done;
      titulo = 'Backend conectado';
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    titulo,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              ApiService.baseUrl,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _etiquetaEntorno(ApiService.baseUrl),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ),
            if (atlasCaido)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'El servidor está arriba, pero MongoDB Atlas no responde. El '
                  'plan gratuito de Atlas pausa el cluster tras 5 minutos de '
                  'inactividad y suele recuperarse solo en unos segundos.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            if (biblioteca.error != null && !caido)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  biblioteca.error!,
                  style: TextStyle(fontSize: 12, color: color),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => showServerSettingsSheet(
                    context,
                    onGuardado: biblioteca.refrescar,
                  ),
                  icon: const Icon(Icons.settings, size: 18),
                  label: const Text('Cambiar servidor'),
                ),
                const SizedBox(width: 10),
                TextButton.icon(
                  onPressed: biblioteca.refrescar,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ],
        ),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A237E),
          ),
        ),
        if (accion != null)
          TextButton(onPressed: onAccion, child: Text(accion!)),
      ],
    );
  }
}
