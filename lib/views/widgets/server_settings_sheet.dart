import 'package:flutter/material.dart';

import '../../services/api_service.dart';

/// Hoja modal para configurar el backend (URL y Clave de API / Token de autenticación).
Future<void> showServerSettingsSheet(
  BuildContext context, {
  required Future<void> Function() onGuardado,
}) async {
  final urlController = TextEditingController(text: ApiService.baseUrl);
  final keyController = TextEditingController(text: ApiService.apiKey);
  bool ocultarClave = true;

  final guardo = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      bool probando = false;
      String? resultadoPrueba;
      bool exitoPrueba = false;

      return StatefulBuilder(
        builder: (context, setStateModal) => SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.dns, color: Color(0xFF283593)),
                    const SizedBox(width: 8),
                    const Text(
                      'Configuración del Servidor',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Configura la dirección del backend y tu clave de autenticación. '
                  'La clave es obligatoria si el backend tiene autenticación activa.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Dirección del backend',
                    hintText: 'https://tu-api.onrender.com',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: keyController,
                  obscureText: ocultarClave,
                  decoration: InputDecoration(
                    labelText: 'Clave de API / Token (Seguridad)',
                    hintText: 'Clave secreta configurada en el servidor',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.key),
                    suffixIcon: IconButton(
                      icon: Icon(
                        ocultarClave ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setStateModal(() {
                          ocultarClave = !ocultarClave;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Producción',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A237E),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.cloud, size: 16),
                      label: Text(
                        ApiService.tieneUrlProduccion
                            ? 'Backend desplegado'
                            : 'Pegá la URL del deploy',
                      ),
                      onPressed: () {
                        if (ApiService.tieneUrlProduccion) {
                          urlController.text = ApiService.urlProduccion;
                        } else {
                          urlController.text = 'https://';
                        }
                        setStateModal(() => resultadoPrueba = null);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Desarrollo local (PC encendida)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.phone_android, size: 16),
                      label: const Text('Celular + IP de la PC'),
                      onPressed: () {
                        urlController.text = 'http://192.168.1.0:3000';
                        setStateModal(() => resultadoPrueba = null);
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.android, size: 16),
                      label: const Text('Emulador Android'),
                      onPressed: () {
                        urlController.text = 'http://10.0.2.2:3000';
                        setStateModal(() => resultadoPrueba = null);
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.computer, size: 16),
                      label: const Text('Localhost (misma PC)'),
                      onPressed: () {
                        urlController.text = 'http://localhost:3000';
                        setStateModal(() => resultadoPrueba = null);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (resultadoPrueba != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: exitoPrueba ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: exitoPrueba
                            ? Colors.green.shade300
                            : Colors.red.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          exitoPrueba ? Icons.check_circle : Icons.error_outline,
                          size: 18,
                          color: exitoPrueba ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            resultadoPrueba!,
                            style: TextStyle(
                              fontSize: 12,
                              color: exitoPrueba
                                  ? Colors.green.shade900
                                  : Colors.red.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: probando
                            ? null
                            : () async {
                                setStateModal(() {
                                  probando = true;
                                  resultadoPrueba = null;
                                });
                                final urlAnterior = ApiService.baseUrl;
                                final keyAnterior = ApiService.apiKey;
                                ApiService.baseUrl = urlController.text;
                                ApiService.apiKey = keyController.text;

                                final ok = await ApiService.probarConexion();
                                if (!ok) {
                                  ApiService.baseUrl = urlAnterior;
                                  ApiService.apiKey = keyAnterior;
                                }
                                setStateModal(() {
                                  probando = false;
                                  exitoPrueba = ok;
                                  resultadoPrueba = ok
                                      ? '¡Conexión y credenciales verificadas!'
                                      : 'No se pudo conectar o la clave fue rechazada.';
                                });
                              },
                        icon: probando
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.sensors, size: 18),
                        label: Text(probando ? 'Probando...' : 'Probar conexión'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF283593),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          await ApiService.guardarBaseUrl(urlController.text);
                          await ApiService.guardarApiKey(keyController.text);
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        },
                        child: const Text('Guardar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  if (guardo == true && context.mounted) {
    await onGuardado();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Servidor actualizado: ${ApiService.baseUrl}'),
        ),
      );
    }
  }
}
