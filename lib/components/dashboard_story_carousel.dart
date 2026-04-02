import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:gradeflow/components/animated_glow_border.dart';
import 'package:gradeflow/theme.dart';

enum DashboardStoryVisual {
  campus,
  studio,
  spotlight,
}

class DashboardStorySlide {
  final String overline;
  final String title;
  final String description;
  final List<String> chips;
  final String visualLabel;
  final String visualValue;
  final String visualCaption;
  final IconData icon;
  final DashboardStoryVisual visual;
  final String? imageUrl;
  final String? imageAssetPath;
  final String? ctaLabel;
  final String? secondaryCtaLabel;
  final VoidCallback? onTap;
  final VoidCallback? onSecondaryTap;

  const DashboardStorySlide({
    required this.overline,
    required this.title,
    required this.description,
    required this.chips,
    required this.visualLabel,
    required this.visualValue,
    required this.visualCaption,
    required this.icon,
    required this.visual,
    this.imageUrl,
    this.imageAssetPath,
    this.ctaLabel,
    this.secondaryCtaLabel,
    this.onTap,
    this.onSecondaryTap,
  });
}

class DashboardStoryCarousel extends StatefulWidget {
  final List<DashboardStorySlide> slides;
  final List<String> headlines;

  const DashboardStoryCarousel({
    super.key,
    required this.slides,
    required this.headlines,
  });

  @override
  State<DashboardStoryCarousel> createState() => _DashboardStoryCarouselState();
}

class _DashboardStoryCarouselState extends State<DashboardStoryCarousel> {
  static const _pageDuration = Duration(milliseconds: 900);
  static const _pageCurve = Curves.easeInOutCubic;
  static const _autoAdvanceInterval = Duration(seconds: 7);
  static const _headlineInterval = Duration(seconds: 4);

  late final PageController _pageController = PageController();
  Timer? _autoAdvanceTimer;
  Timer? _headlineTimer;
  int _currentIndex = 0;
  int _headlineIndex = 0;
  double _pageValue = 0;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_handlePageScroll);
    _startAutoAdvance();
    _startHeadlineRotation();
  }

  @override
  void didUpdateWidget(covariant DashboardStoryCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slides.length != widget.slides.length) {
      _currentIndex =
          _currentIndex.clamp(0, math.max(0, widget.slides.length - 1));
      _pageValue = _currentIndex.toDouble();
      _startAutoAdvance();
    }
    if (oldWidget.headlines.length != widget.headlines.length) {
      _headlineIndex = 0;
      _startHeadlineRotation();
    }
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _headlineTimer?.cancel();
    _pageController
      ..removeListener(_handlePageScroll)
      ..dispose();
    super.dispose();
  }

  void _handlePageScroll() {
    if (!_pageController.hasClients) return;
    final nextValue = _pageController.page ?? _currentIndex.toDouble();
    if ((nextValue - _pageValue).abs() < 0.001) return;
    setState(() {
      _pageValue = nextValue;
    });
  }

  void _startAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    if (widget.slides.length <= 1) return;

    _autoAdvanceTimer = Timer.periodic(_autoAdvanceInterval, (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_currentIndex + 1) % widget.slides.length;
      _pageController.animateToPage(
        next,
        duration: _pageDuration,
        curve: _pageCurve,
      );
    });
  }

  void _startHeadlineRotation() {
    _headlineTimer?.cancel();
    if (widget.headlines.length <= 1) return;

    _headlineTimer = Timer.periodic(_headlineInterval, (_) {
      if (!mounted) return;
      setState(() {
        _headlineIndex = (_headlineIndex + 1) % widget.headlines.length;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.slides.isEmpty) {
      return const SizedBox.shrink();
    }

    final viewportWidth = MediaQuery.of(context).size.width;
    final isNarrow = viewportWidth < 860;
    final isTightViewport = viewportWidth < 620;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedGlowBorder(
          radius: 30,
          borderWidth: 2.5,
          child: SizedBox(
            height: isNarrow ? (isTightViewport ? 560 : 540) : 400,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: widget.slides.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                        _pageValue = index.toDouble();
                      });
                      _startAutoAdvance();
                    },
                    itemBuilder: (context, index) {
                      final slide = widget.slides[index];
                      final delta = (_pageValue - index).clamp(-1.0, 1.0);
                      return _StorySlideView(
                        slide: slide,
                        isNarrow: isNarrow,
                        pageDelta: delta,
                      );
                    },
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    top: 18,
                    child: Row(
                      children: List.generate(widget.slides.length, (index) {
                        final isActive = index == _currentIndex;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: index == widget.slides.length - 1 ? 0 : 8,
                            ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeOutCubic,
                              height: isActive ? 5 : 3,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: isActive
                                    ? Colors.white.withValues(alpha: 0.92)
                                    : Colors.white.withValues(alpha: 0.26),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  if (!isNarrow && widget.slides.length > 1) ...[
                    Positioned(
                      left: 18,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _CarouselArrow(
                          icon: Icons.arrow_back_rounded,
                          onPressed: () => _jumpBy(-1),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 18,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _CarouselArrow(
                          icon: Icons.arrow_forward_rounded,
                          onPressed: () => _jumpBy(1),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (widget.headlines.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          AnimatedGlowBorder(
            radius: 22,
            borderWidth: 1.6,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.66),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.podcasts_rounded,
                          size: 16,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Pulse Reel',
                          style:
                              context.textStyles.labelLarge?.semiBold.withColor(
                            Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        final offsetAnimation = Tween<Offset>(
                          begin: const Offset(0.05, 0),
                          end: Offset.zero,
                        ).animate(animation);
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: offsetAnimation,
                            child: child,
                          ),
                        );
                      },
                      child: Text(
                        widget.headlines[
                            _headlineIndex % widget.headlines.length],
                        key: ValueKey<int>(_headlineIndex),
                        style: context.textStyles.bodyMedium?.semiBold,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      math.min(widget.headlines.length, 4),
                      (index) {
                        final active = index ==
                            (_headlineIndex %
                                math.min(widget.headlines.length, 4));
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 280),
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: active ? 16 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: active
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context)
                                    .colorScheme
                                    .outline
                                    .withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _jumpBy(int direction) async {
    if (!_pageController.hasClients || widget.slides.isEmpty) return;
    final next = (_currentIndex + direction + widget.slides.length) %
        widget.slides.length;
    await _pageController.animateToPage(
      next,
      duration: _pageDuration,
      curve: _pageCurve,
    );
    _startAutoAdvance();
  }
}

class _StorySlideView extends StatelessWidget {
  final DashboardStorySlide slide;
  final bool isNarrow;
  final double pageDelta;

  const _StorySlideView({
    required this.slide,
    required this.isNarrow,
    required this.pageDelta,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _StoryPalette.forVisual(
      slide.visual,
      Theme.of(context).brightness,
    );
    final clampedDelta = pageDelta.clamp(-1.0, 1.0);
    final artTranslation = Offset(clampedDelta * -32, 0);
    final textTranslation = Offset(clampedDelta * -14, 0);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.surfaceGradient,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _StoryBackdropPainter(
              palette: palette,
              visual: slide.visual,
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.02),
                  Colors.black.withValues(alpha: 0.08),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              isNarrow ? 22 : 28,
              isNarrow ? 42 : 42,
              isNarrow ? 22 : 28,
              isNarrow ? 18 : 26,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final useColumn = isNarrow || constraints.maxWidth < 780;
                final isTightColumn = useColumn && constraints.maxWidth < 620;
                final text = Transform.translate(
                  offset: textTranslation,
                  child: _StoryTextPane(
                    slide: slide,
                    palette: palette,
                  ),
                );
                final visual = Transform.translate(
                  offset: artTranslation,
                  child: _StoryArtCard(
                    slide: slide,
                    palette: palette,
                    expanded: !useColumn,
                  ),
                );

                if (useColumn) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: isTightColumn ? 170 : 190,
                        child: visual,
                      ),
                      SizedBox(
                        height: isTightColumn ? AppSpacing.md : AppSpacing.lg,
                      ),
                      Expanded(child: text),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      flex: 8,
                      child: text,
                    ),
                    const SizedBox(width: AppSpacing.xl),
                    Expanded(
                      flex: 5,
                      child: visual,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryTextPane extends StatelessWidget {
  final DashboardStorySlide slide;
  final _StoryPalette palette;

  const _StoryTextPane({
    required this.slide,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isTight = constraints.maxHeight < 280 || screenWidth < 620;
        final useCompactLayout = isTight ||
            slide.title.length > 72 ||
            slide.description.length > 190 ||
            slide.secondaryCtaLabel != null ||
            slide.chips.length > 3;
        final maxChipCount = isTight ? 2 : (useCompactLayout ? 3 : 4);
        final visibleChips = slide.chips.take(maxChipCount).toList();
        final titleStyle = (screenWidth < 860
                ? (isTight
                    ? context.textStyles.headlineSmall
                    : context.textStyles.headlineMedium)
                : useCompactLayout
                    ? context.textStyles.headlineLarge
                    : context.textStyles.displaySmall)
            ?.bold
            .withColor(Colors.white)
            .copyWith(
              height: isTight ? 1.08 : (useCompactLayout ? 1.04 : 1.02),
              letterSpacing: isTight ? -0.45 : (useCompactLayout ? -0.7 : -1.1),
            );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isTight ? 12 : 14,
                vertical: isTight ? 7 : 9,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.16),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(slide.icon,
                      size: isTight ? 15 : 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    slide.overline,
                    style: context.textStyles.labelLarge?.semiBold.withColor(
                      Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isTight ? AppSpacing.sm : AppSpacing.md),
            Text(
              slide.title,
              maxLines: isTight ? 2 : (useCompactLayout ? 3 : 4),
              overflow: TextOverflow.ellipsis,
              style: titleStyle,
            ),
            SizedBox(height: isTight ? 6 : AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Text(
                slide.description,
                maxLines: isTight ? 2 : (useCompactLayout ? 3 : 4),
                overflow: TextOverflow.ellipsis,
                style: (isTight
                        ? context.textStyles.bodyMedium
                        : context.textStyles.bodyLarge)
                    ?.withColor(
                  Colors.white.withValues(alpha: 0.88),
                ),
              ),
            ),
            SizedBox(height: isTight ? AppSpacing.sm : AppSpacing.md),
            if (visibleChips.isNotEmpty)
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: visibleChips.map((chip) {
                  return Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTight ? 10 : (useCompactLayout ? 11 : 12),
                      vertical: isTight ? 6 : (useCompactLayout ? 7 : 9),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Text(
                      chip,
                      style: context.textStyles.labelMedium?.medium.withColor(
                        Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                  );
                }).toList(),
              ),
            const Spacer(),
            if (slide.ctaLabel != null || slide.secondaryCtaLabel != null) ...[
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.sm,
                children: [
                  if (slide.ctaLabel != null && slide.onTap != null)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: palette.buttonForeground,
                        padding: EdgeInsets.symmetric(
                          horizontal: isTight ? 14 : 18,
                          vertical: isTight ? 12 : 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                      ),
                      onPressed: slide.onTap,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text(slide.ctaLabel!),
                    ),
                  if (slide.secondaryCtaLabel != null &&
                      slide.onSecondaryTap != null)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.38),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: isTight ? 14 : 18,
                          vertical: isTight ? 12 : 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                      ),
                      onPressed: slide.onSecondaryTap,
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: Text(slide.secondaryCtaLabel!),
                    ),
                ],
              ),
              SizedBox(height: isTight ? AppSpacing.xs : AppSpacing.sm),
            ],
            if (!isTight)
              Text(
                slide.visualCaption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.bodySmall?.medium.withColor(
                  Colors.white.withValues(alpha: 0.80),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StoryArtCard extends StatelessWidget {
  final DashboardStorySlide slide;
  final _StoryPalette palette;
  final bool expanded;

  const _StoryArtCard({
    required this.slide,
    required this.palette,
    required this.expanded,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: palette.shadowColor,
            blurRadius: 28,
            spreadRadius: -14,
            offset: const Offset(0, 22),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.cardGradient,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (slide.imageAssetPath != null &&
                slide.imageAssetPath!.isNotEmpty)
              Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    slide.imageAssetPath!,
                    fit: BoxFit.cover,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.14),
                          Colors.black.withValues(alpha: 0.04),
                          Colors.black.withValues(alpha: 0.36),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ],
              )
            else if (slide.imageUrl != null && slide.imageUrl!.isNotEmpty)
              Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    slide.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return CustomPaint(
                        painter: _StoryArtworkPainter(
                          palette: palette,
                          visual: slide.visual,
                        ),
                      );
                    },
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.14),
                          Colors.black.withValues(alpha: 0.04),
                          Colors.black.withValues(alpha: 0.36),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ],
              )
            else
              CustomPaint(
                painter: _StoryArtworkPainter(
                  palette: palette,
                  visual: slide.visual,
                ),
              ),
            Positioned(
              left: 18,
              top: 18,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(slide.icon, size: 17, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      slide.overline,
                      style: context.textStyles.labelMedium?.semiBold.withColor(
                        Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 18,
              top: 18,
              child: Image.asset(
                'assets/images/school_logo2.png',
                width: 48,
                height: 48,
                opacity: const AlwaysStoppedAnimation(0.92),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                          child: Icon(slide.icon, color: Colors.white),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                slide.visualLabel,
                                style: context.textStyles.labelLarge?.semiBold
                                    .withColor(
                                  Colors.white.withValues(alpha: 0.86),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                slide.visualValue,
                                style: context.textStyles.headlineLarge?.bold
                                    .withColor(Colors.white)
                                    .copyWith(letterSpacing: -0.7),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Widget builtCard = card;
    if (slide.onTap != null) {
      builtCard = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: slide.onTap,
          behavior: HitTestBehavior.opaque,
          child: builtCard,
        ),
      );
    }

    if (!expanded) {
      return builtCard;
    }

    return Center(
      child: AspectRatio(
        aspectRatio: 0.86,
        child: builtCard,
      ),
    );
  }
}

class _CarouselArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _CarouselArrow({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Material(
          color: Colors.white.withValues(alpha: 0.10),
          child: InkWell(
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(icon, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _StoryPalette {
  final List<Color> surfaceGradient;
  final List<Color> cardGradient;
  final Color accent;
  final Color accentSoft;
  final Color secondary;
  final Color shadowColor;
  final Color buttonForeground;

  const _StoryPalette({
    required this.surfaceGradient,
    required this.cardGradient,
    required this.accent,
    required this.accentSoft,
    required this.secondary,
    required this.shadowColor,
    required this.buttonForeground,
  });

  factory _StoryPalette.forVisual(
    DashboardStoryVisual visual,
    Brightness brightness,
  ) {
    final isDark = brightness == Brightness.dark;
    switch (visual) {
      case DashboardStoryVisual.campus:
        return _StoryPalette(
          surfaceGradient: isDark
              ? const [Color(0xFF10203C), Color(0xFF183B6B), Color(0xFF0C1629)]
              : const [Color(0xFF113A70), Color(0xFF2B6EA6), Color(0xFF78C7E8)],
          cardGradient: isDark
              ? const [Color(0xFF17345F), Color(0xFF21578E), Color(0xFF11203C)]
              : const [Color(0xFF295B93), Color(0xFF4FA4D8), Color(0xFF97DBF0)],
          accent: const Color(0xFFFFD166),
          accentSoft: const Color(0xFFFFF0B8),
          secondary: const Color(0xFF8EE3FF),
          shadowColor: const Color(0xFF0F3B74).withValues(alpha: 0.42),
          buttonForeground: const Color(0xFF163B70),
        );
      case DashboardStoryVisual.studio:
        return _StoryPalette(
          surfaceGradient: isDark
              ? const [Color(0xFF171B34), Color(0xFF28306B), Color(0xFF0E1020)]
              : const [Color(0xFF3D3FE0), Color(0xFF4C7DF7), Color(0xFF7ED7F8)],
          cardGradient: isDark
              ? const [Color(0xFF202756), Color(0xFF3140A6), Color(0xFF171B34)]
              : const [Color(0xFF4250E3), Color(0xFF6A89FF), Color(0xFFA2F2FF)],
          accent: const Color(0xFFFF7A59),
          accentSoft: const Color(0xFFFFC7A6),
          secondary: const Color(0xFF6EE7F9),
          shadowColor: const Color(0xFF2E37A4).withValues(alpha: 0.40),
          buttonForeground: const Color(0xFF273496),
        );
      case DashboardStoryVisual.spotlight:
        return _StoryPalette(
          surfaceGradient: isDark
              ? const [Color(0xFF1A1432), Color(0xFF4C2C77), Color(0xFF120E20)]
              : const [Color(0xFF4F2B88), Color(0xFF7C4FC6), Color(0xFFEE9AD1)],
          cardGradient: isDark
              ? const [Color(0xFF251A46), Color(0xFF6A3AA8), Color(0xFF1A1432)]
              : const [Color(0xFF5A35A0), Color(0xFF8D64D8), Color(0xFFFFC8D8)],
          accent: const Color(0xFFFFD29D),
          accentSoft: const Color(0xFFFFF0C8),
          secondary: const Color(0xFFFF99C8),
          shadowColor: const Color(0xFF51178C).withValues(alpha: 0.40),
          buttonForeground: const Color(0xFF4B2D85),
        );
    }
  }
}

class _StoryBackdropPainter extends CustomPainter {
  final _StoryPalette palette;
  final DashboardStoryVisual visual;

  const _StoryBackdropPainter({
    required this.palette,
    required this.visual,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;

    for (double x = 24; x < size.width; x += 44) {
      canvas.drawLine(
        Offset(x, size.height * 0.55),
        Offset(x + 12, size.height),
        gridPaint,
      );
    }

    final glowPaint = Paint()
      ..color = palette.secondary.withValues(alpha: 0.18)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 48);
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.18),
      size.width * 0.18,
      glowPaint,
    );

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = Colors.white.withValues(alpha: 0.10);
    canvas.drawCircle(
      Offset(size.width * 0.86, size.height * 0.26),
      size.width * 0.17,
      ringPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.84, size.height * 0.22),
      size.width * 0.11,
      ringPaint,
    );

    switch (visual) {
      case DashboardStoryVisual.campus:
        _paintCampusBackdrop(canvas, size);
        break;
      case DashboardStoryVisual.studio:
        _paintStudioBackdrop(canvas, size);
        break;
      case DashboardStoryVisual.spotlight:
        _paintSpotlightBackdrop(canvas, size);
        break;
    }
  }

  void _paintCampusBackdrop(Canvas canvas, Size size) {
    final sun = Paint()..color = palette.accent.withValues(alpha: 0.38);
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.22),
      size.width * 0.09,
      sun,
    );

    final hillA = Path()
      ..moveTo(0, size.height * 0.78)
      ..quadraticBezierTo(
        size.width * 0.30,
        size.height * 0.54,
        size.width * 0.58,
        size.height * 0.74,
      )
      ..quadraticBezierTo(
        size.width * 0.82,
        size.height * 0.88,
        size.width,
        size.height * 0.66,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      hillA,
      Paint()..color = const Color(0xFF0B2443).withValues(alpha: 0.38),
    );
  }

  void _paintStudioBackdrop(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.11)
      ..strokeWidth = 1.2;

    for (var i = 0; i < 7; i++) {
      final y = size.height * (0.16 + (i * 0.09));
      canvas.drawLine(
        Offset(size.width * 0.52, y),
        Offset(size.width, y),
        linePaint,
      );
    }

    final graphPaint = Paint()
      ..color = palette.accent.withValues(alpha: 0.58)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final graph = Path()
      ..moveTo(size.width * 0.60, size.height * 0.70)
      ..lineTo(size.width * 0.70, size.height * 0.62)
      ..lineTo(size.width * 0.76, size.height * 0.65)
      ..lineTo(size.width * 0.86, size.height * 0.44)
      ..lineTo(size.width * 0.94, size.height * 0.50);
    canvas.drawPath(graph, graphPaint);
  }

  void _paintSpotlightBackdrop(Canvas canvas, Size size) {
    final beam = Paint()
      ..color = palette.accentSoft.withValues(alpha: 0.10)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 18);

    final leftBeam = Path()
      ..moveTo(size.width * 0.10, 0)
      ..lineTo(size.width * 0.28, 0)
      ..lineTo(size.width * 0.46, size.height)
      ..lineTo(size.width * 0.26, size.height)
      ..close();
    final rightBeam = Path()
      ..moveTo(size.width * 0.70, 0)
      ..lineTo(size.width * 0.88, 0)
      ..lineTo(size.width * 0.76, size.height)
      ..lineTo(size.width * 0.56, size.height)
      ..close();
    canvas.drawPath(leftBeam, beam);
    canvas.drawPath(rightBeam, beam);
  }

  @override
  bool shouldRepaint(covariant _StoryBackdropPainter oldDelegate) {
    return oldDelegate.visual != visual || oldDelegate.palette != palette;
  }
}

class _StoryArtworkPainter extends CustomPainter {
  final _StoryPalette palette;
  final DashboardStoryVisual visual;

  const _StoryArtworkPainter({
    required this.palette,
    required this.visual,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backdrop = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(size.width, size.height),
        palette.cardGradient,
      );
    canvas.drawRect(Offset.zero & size, backdrop);

    switch (visual) {
      case DashboardStoryVisual.campus:
        _paintCampusScene(canvas, size);
        break;
      case DashboardStoryVisual.studio:
        _paintStudioScene(canvas, size);
        break;
      case DashboardStoryVisual.spotlight:
        _paintSpotlightScene(canvas, size);
        break;
    }
  }

  void _paintCampusScene(Canvas canvas, Size size) {
    final skyGlow = Paint()
      ..color = palette.accent.withValues(alpha: 0.22)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 24);
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.20),
      42,
      skyGlow,
    );

    final horizon = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(size.width * 0.14, size.height * 0.58),
      Offset(size.width * 0.86, size.height * 0.58),
      horizon,
    );

    final campusBody = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.20,
        size.height * 0.42,
        size.width * 0.48,
        size.height * 0.24,
      ),
      const Radius.circular(24),
    );
    canvas.drawRRect(
      campusBody,
      Paint()..color = const Color(0xFFEDF8FF).withValues(alpha: 0.28),
    );

    final roofPath = Path()
      ..moveTo(size.width * 0.16, size.height * 0.46)
      ..lineTo(size.width * 0.44, size.height * 0.30)
      ..lineTo(size.width * 0.72, size.height * 0.46)
      ..close();
    canvas.drawPath(
      roofPath,
      Paint()..color = palette.accent.withValues(alpha: 0.70),
    );

    final windowPaint = Paint()..color = Colors.white.withValues(alpha: 0.78);
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 4; col++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              size.width * 0.26 + (col * size.width * 0.09),
              size.height * 0.48 + (row * size.height * 0.048),
              size.width * 0.05,
              size.height * 0.026,
            ),
            const Radius.circular(8),
          ),
          windowPaint,
        );
      }
    }

    final path = Path()
      ..moveTo(0, size.height * 0.82)
      ..quadraticBezierTo(
        size.width * 0.30,
        size.height * 0.66,
        size.width * 0.58,
        size.height * 0.80,
      )
      ..quadraticBezierTo(
        size.width * 0.80,
        size.height * 0.90,
        size.width,
        size.height * 0.72,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = const Color(0xFF0D2646).withValues(alpha: 0.55),
    );
  }

  void _paintStudioScene(Canvas canvas, Size size) {
    final deck = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.12,
        size.height * 0.18,
        size.width * 0.76,
        size.height * 0.62,
      ),
      const Radius.circular(28),
    );
    canvas.drawRRect(
      deck,
      Paint()..color = Colors.white.withValues(alpha: 0.12),
    );

    final card = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.18,
        size.height * 0.24,
        size.width * 0.64,
        size.height * 0.52,
      ),
      const Radius.circular(24),
    );
    canvas.drawRRect(
      card,
      Paint()..color = Colors.white.withValues(alpha: 0.80),
    );

    final textLine = Paint()..color = const Color(0xFFCBD5F5);
    for (var i = 0; i < 5; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * 0.26,
            size.height * (0.33 + i * 0.07),
            size.width * (i == 4 ? 0.28 : 0.46),
            size.height * 0.022,
          ),
          const Radius.circular(9),
        ),
        textLine,
      );
    }

    final chartArea = Rect.fromLTWH(
      size.width * 0.56,
      size.height * 0.34,
      size.width * 0.18,
      size.height * 0.24,
    );
    canvas.drawRect(
      chartArea,
      Paint()..color = palette.secondary.withValues(alpha: 0.16),
    );

    final sparkPaint = Paint()
      ..color = palette.accent
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.58, size.height * 0.54),
      Offset(size.width * 0.64, size.height * 0.42),
      sparkPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.64, size.height * 0.42),
      Offset(size.width * 0.69, size.height * 0.47),
      sparkPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.69, size.height * 0.47),
      Offset(size.width * 0.74, size.height * 0.36),
      sparkPaint,
    );
  }

  void _paintSpotlightScene(Canvas canvas, Size size) {
    final stage = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.12,
        size.height * 0.66,
        size.width * 0.76,
        size.height * 0.18,
      ),
      const Radius.circular(32),
    );
    canvas.drawRRect(
      stage,
      Paint()..color = Colors.black.withValues(alpha: 0.30),
    );

    final beamPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width * 0.28, 0),
        Offset(size.width * 0.28, size.height),
        [
          palette.accentSoft.withValues(alpha: 0.44),
          Colors.transparent,
        ],
        const [0.0, 1.0],
      );
    final beamLeft = Path()
      ..moveTo(size.width * 0.18, 0)
      ..lineTo(size.width * 0.32, 0)
      ..lineTo(size.width * 0.46, size.height)
      ..lineTo(size.width * 0.28, size.height)
      ..close();
    final beamRight = Path()
      ..moveTo(size.width * 0.66, 0)
      ..lineTo(size.width * 0.80, 0)
      ..lineTo(size.width * 0.68, size.height)
      ..lineTo(size.width * 0.52, size.height)
      ..close();
    canvas.drawPath(beamLeft, beamPaint);
    canvas.drawPath(beamRight, beamPaint);

    final orbPaint = Paint()
      ..color = palette.secondary.withValues(alpha: 0.22)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 16);
    canvas.drawCircle(
      Offset(size.width * 0.26, size.height * 0.28),
      24,
      orbPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.74, size.height * 0.22),
      18,
      orbPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _StoryArtworkPainter oldDelegate) {
    return oldDelegate.visual != visual || oldDelegate.palette != palette;
  }
}
