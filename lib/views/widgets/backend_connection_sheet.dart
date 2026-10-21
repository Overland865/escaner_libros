import 'package:flutter/material.dart';

import '../../services/api_service.dart';

Future<void> showBackendConnectionSheet(
  BuildContext context, {
  Future<void> Function()? onRetry,
}) async {
  var prueba = ApiService.probarConexion();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setStateModal) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(sheetContext).viewInsets.bottom + 24,
        ),
        child: FutureBuilder<String?>(
          future: prueba,
          builder: (context, snapshot) {
            final verificando =
                snapshot.connectionState != ConnectionState.done;
            final error = snapshot.error?.toString() ?? snapshot.data;
            final conectado =
                !verificando && snapshot.error == null && error == null;
            final color = verificando
                ? Colors.blueGrey
                : conectado
                ? Colors.green.shade700
                : Colors.red.shade700;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cloud, color: Color(0xFF283593)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Conexión del backend',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Backend de Render',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  ApiService.baseUrl,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (verificando)
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: color,
                          ),
                        )
                      else
                        Icon(
                          conectado ? Icons.cloud_done : Icons.cloud_off,
                          color: color,
                          size: 20,
                        ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          verificando
                              ? 'Verificando conexión...'
                              : conectado
                              ? 'Backend conectado'
                              : error ?? 'No se pudo verificar el backend.',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: verificando
                        ? null
                        : () async {
                            final nuevaPrueba = ApiService.probarConexion();
                            setStateModal(() => prueba = nuevaPrueba);
                            final resultado = await nuevaPrueba;
                            if (resultado == null && onRetry != null) {
                              await onRetry();
                            }
                          },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
