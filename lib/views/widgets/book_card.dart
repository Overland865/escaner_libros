import 'package:flutter/material.dart';

import '../../models/libro_model.dart';
import '../book_detail_screen.dart';

class BookCard extends StatelessWidget {
  final LibroModel libro;
  final bool pendiente;
  final String? errorSync;
  final bool esFavorito;
  final VoidCallback? onRetorno;

  const BookCard({
    super.key,
    required this.libro,
    this.pendiente = false,
    this.errorSync,
    this.esFavorito = false,
    this.onRetorno,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // Categorized gradient colors for book icons
    final isFiction = libro.tipoLibro.toLowerCase().contains('ficci') ||
        libro.tipoLibro.toLowerCase().contains('misterio') ||
        libro.tipoLibro.toLowerCase().contains('terror');
    final isFantasy = libro.tipoLibro.toLowerCase().contains('fantas') ||
        libro.tipoLibro.toLowerCase().contains('magia');

    final gradientColors = isFantasy
        ? const [Color(0xFF8B5CF6), Color(0xFFEC4899)]
        : isFiction
            ? const [Color(0xFF3B82F6), Color(0xFF6366F1)]
            : const [Color(0xFF6366F1), Color(0xFF38BDF8)];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF141724),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: pendiente
              ? Colors.amber.shade700.withValues(alpha: 0.4)
              : const Color(0xFF26293A),
          width: pendiente ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BookDetailScreen(
                  idLibro: libro.id,
                  titulo: libro.titulo,
                  libroLocal: pendiente ? libro : null,
                  errorSync: errorSync,
                ),
              ),
            );
            onRetorno?.call();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dynamic Book Avatar with glow
                    Container(
                      width: 48,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: gradientColors.first.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.auto_stories,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            libro.titulo,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF1F0FB),
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline_rounded,
                                size: 14,
                                color: colors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  libro.autor.isNotEmpty
                                      ? libro.autor
                                      : 'Autor no especificado',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (esFavorito) ...[
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFF59E0B),
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                      size: 22,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFF222638)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Chip(
                      visualDensity: VisualDensity.compact,
                      side: const BorderSide(color: Color(0xFF2D3247)),
                      backgroundColor: const Color(0xFF1B1E2D),
                      label: Text(
                        libro.tipoLibro,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFFC6BFFF),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (libro.editorial.isNotEmpty)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        side: const BorderSide(color: Color(0xFF2D3247)),
                        backgroundColor: const Color(0xFF1B1E2D),
                        label: Text(
                          libro.editorial,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                      ),
                    if (pendiente)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        side: BorderSide(
                          color: Colors.amber.shade700.withValues(alpha: 0.6),
                        ),
                        avatar: Icon(
                          Icons.cloud_upload_outlined,
                          size: 15,
                          color: Colors.amber.shade300,
                        ),
                        label: Text(
                          'Pendiente de subir',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade200,
                          ),
                        ),
                        backgroundColor: Colors.amber.shade900.withValues(alpha: 0.35),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B1E2D),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 12,
                            color: Color(0xFF8B8FA8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            libro.anioInicio == libro.anioFin
                                ? '${libro.anioInicio}'
                                : '${libro.anioInicio} - ${libro.anioFin}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFCBD5E1),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (libro.paginas.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B1E2D),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.description_outlined,
                              size: 12,
                              color: Color(0xFF8B8FA8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${libro.paginas.length} págs',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF8B8FA8),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
