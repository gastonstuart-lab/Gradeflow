// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api

part of '../teacher_dashboard_screen.dart';

enum DashboardHeroStyle {
  midnight,
  horizon,
  studio,
  ember,
}

extension TeacherDashboardPersonalization on _TeacherDashboardScreenState {
  String _dashboardHeroStyleId(DashboardHeroStyle style) {
    switch (style) {
      case DashboardHeroStyle.midnight:
        return 'midnight';
      case DashboardHeroStyle.horizon:
        return 'horizon';
      case DashboardHeroStyle.studio:
        return 'studio';
      case DashboardHeroStyle.ember:
        return 'ember';
    }
  }

  DashboardHeroStyle _dashboardHeroStyleFromId(String? value) {
    switch (value) {
      case 'horizon':
        return DashboardHeroStyle.horizon;
      case 'studio':
        return DashboardHeroStyle.studio;
      case 'ember':
        return DashboardHeroStyle.ember;
      case 'midnight':
      default:
        return DashboardHeroStyle.midnight;
    }
  }

  String _dashboardHeroStyleLabel(DashboardHeroStyle style) {
    switch (style) {
      case DashboardHeroStyle.midnight:
        return 'Midnight';
      case DashboardHeroStyle.horizon:
        return 'Horizon';
      case DashboardHeroStyle.studio:
        return 'Studio';
      case DashboardHeroStyle.ember:
        return 'Ember';
    }
  }

  DashboardHeroPresentation _dashboardHeroPresentation() {
    switch (_dashboardHeroStyle) {
      case DashboardHeroStyle.midnight:
        return DashboardHeroPresentation(
          label: 'Midnight',
          gradientColors: const [
            Color(0xFF171E2B),
            Color(0xFF121926),
          ],
          primaryGlow: const Color(0xFF5C88FF),
          secondaryGlow: const Color(0xFF5EC7E6),
          tertiaryGlow: const Color(0xFF1D4ED8),
        );
      case DashboardHeroStyle.horizon:
        return DashboardHeroPresentation(
          label: 'Horizon',
          gradientColors: const [
            Color(0xFF142230),
            Color(0xFF111B25),
          ],
          primaryGlow: const Color(0xFF22C55E),
          secondaryGlow: const Color(0xFF67E8F9),
          tertiaryGlow: const Color(0xFF0EA5E9),
        );
      case DashboardHeroStyle.studio:
        return DashboardHeroPresentation(
          label: 'Studio',
          gradientColors: const [
            Color(0xFF1B202B),
            Color(0xFF141821),
          ],
          primaryGlow: const Color(0xFFF59E0B),
          secondaryGlow: const Color(0xFF60A5FA),
          tertiaryGlow: const Color(0xFFFB7185),
        );
      case DashboardHeroStyle.ember:
        return DashboardHeroPresentation(
          label: 'Ember',
          gradientColors: const [
            Color(0xFF24181A),
            Color(0xFF17171E),
          ],
          primaryGlow: const Color(0xFFEF7E67),
          secondaryGlow: const Color(0xFFF4B45F),
          tertiaryGlow: const Color(0xFFFB7185),
        );
    }
  }

  ImageProvider<Object>? _dashboardHeroImageProvider() {
    final bytes = _dashboardHeroImageBytes;
    if (bytes == null || bytes.isEmpty) {
      return null;
    }
    return MemoryImage(bytes);
  }

  Future<void> _openHeroPersonalizationSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> handleStyle(DashboardHeroStyle style) async {
              setState(() => _dashboardHeroStyle = style);
              setSheetState(() {});
              await _saveHeroPersonalization();
            }

            Future<void> handlePickImage() async {
              await _pickDashboardHeroImage();
              if (!mounted) return;
              setSheetState(() {});
            }

            Future<void> handleClearImage() async {
              setState(() {
                _dashboardHeroImageBase64 = null;
                _dashboardHeroImageBytes = null;
              });
              setSheetState(() {});
              await _saveHeroPersonalization();
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hero personalization',
                    style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose a built-in hero style and optionally add a custom background image. GradeFlow keeps readability protected with a dark cinematic overlay.',
                    style: Theme.of(sheetContext).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final style in DashboardHeroStyle.values)
                        ChoiceChip(
                          label: Text(_dashboardHeroStyleLabel(style)),
                          selected: _dashboardHeroStyle == style,
                          onSelected: (_) => unawaited(handleStyle(style)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(sheetContext)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.65),
                      ),
                      color: Theme.of(sheetContext)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.28),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _dashboardHeroImageBytes == null
                                    ? 'No custom background image'
                                    : 'Custom image ready',
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _dashboardHeroImageBytes == null
                                    ? 'Built-in premium gradients stay active by default.'
                                    : 'Your uploaded image is layered behind the selected hero style.',
                                style: Theme.of(sheetContext).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _updatingHeroBackground
                              ? null
                              : () => unawaited(handlePickImage()),
                          icon: Icon(_updatingHeroBackground
                              ? Icons.sync_rounded
                              : Icons.wallpaper_outlined),
                          label: Text(
                            _updatingHeroBackground
                                ? 'Loading...'
                                : 'Choose image',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_dashboardHeroImageBytes != null) ...[
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => unawaited(handleClearImage()),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Remove custom image'),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickDashboardHeroImage() async {
    if (_updatingHeroBackground) return;
    setState(() => _updatingHeroBackground = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
      final bytes = picked?.files.single.bytes;
      if (bytes == null || bytes.isEmpty) {
        return;
      }
      if (bytes.lengthInBytes > 1400000) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please choose an image under about 1.4 MB for fast local loading.',
              ),
            ),
          );
        }
        return;
      }

      setState(() {
        _dashboardHeroImageBytes = bytes;
        _dashboardHeroImageBase64 = base64Encode(bytes);
      });
      await _saveHeroPersonalization();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hero background updated')),
        );
      }
    } catch (e) {
      debugPrint('Failed to set dashboard hero image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not update hero background'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _updatingHeroBackground = false);
      }
    }
  }
}
