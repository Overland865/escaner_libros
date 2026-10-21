import 'package:flutter/material.dart';

import '../../models/libro_model.dart';
import '../book_detail_screen.dart';

class BookCard extends StatelessWidget {
  final LibroModel libro;
  final bool pendiente;

  const BookCard({super.key, required this.libro, this.pendiente = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

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
                  'Sincronízalo desde Inicio para ver el detalle completo.',
                ),
              ),
            );
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  BookDetailScreen(idLibro: libro.id, titulo: libro.titulo),
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
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.auto_stories,
                      color: colors.primary,
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
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          libro.iglesia.isNotEmpty
                              ? libro.iglesia
                              : 'Parroquia no especificada',
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
                ],
              ),
              const Divider(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(libro.tipoLibro),
                  ),
                  if (pendiente)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(
                        Icons.cloud_upload_outlined,
                        size: 16,
                        color: colors.tertiary,
                      ),
                      label: const Text('Pendiente de subir'),
                      backgroundColor: colors.tertiaryContainer,
                    ),
                  Text(
                    libro.anioInicio == libro.anioFin
                        ? '${libro.anioInicio}'
                        : '${libro.anioInicio} - ${libro.anioFin}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
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
