import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gradeflow/config/instructos_branding.dart';

class InstructOSMark extends StatelessWidget {
  const InstructOSMark({
    super.key,
    this.width,
    this.height = 32,
  });

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SvgPicture.asset(
      dark
          ? InstructOSBranding.platformMarkDarkAsset
          : InstructOSBranding.platformMarkLightAsset,
      width: width,
      height: height,
      fit: BoxFit.contain,
      semanticsLabel: InstructOSBranding.productShortName,
    );
  }
}

class InstructOSWordmark extends StatelessWidget {
  const InstructOSWordmark({
    super.key,
    this.width,
    this.height = 34,
  });

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SvgPicture.asset(
      dark
          ? InstructOSBranding.platformWordmarkDarkAsset
          : InstructOSBranding.platformWordmarkLightAsset,
      width: width,
      height: height,
      fit: BoxFit.contain,
      semanticsLabel: InstructOSBranding.productName,
    );
  }
}

class InstructOSLogoLockup extends StatelessWidget {
  const InstructOSLogoLockup({
    super.key,
    this.width,
    this.height = 40,
    this.showTagline = false,
    this.compact = false,
    this.taglineMaxLines = 1,
  });

  final double? width;
  final double height;
  final bool showTagline;
  final bool compact;
  final int taglineMaxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final logo = SvgPicture.asset(
      compact
          ? (dark
              ? InstructOSBranding.platformMarkDarkAsset
              : InstructOSBranding.platformMarkLightAsset)
          : (dark
              ? InstructOSBranding.platformLogoDarkAsset
              : InstructOSBranding.platformLogoLightAsset),
      width: width,
      height: height,
      fit: BoxFit.contain,
      semanticsLabel: compact
          ? InstructOSBranding.productShortName
          : InstructOSBranding.productName,
    );

    if (!showTagline) return logo;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        logo,
        const SizedBox(height: 4),
        Text(
          InstructOSBranding.productTagline,
          maxLines: taglineMaxLines,
          overflow: taglineMaxLines > 1
              ? TextOverflow.visible
              : TextOverflow.ellipsis,
          softWrap: taglineMaxLines > 1,
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class InstructOSTextLockup extends StatelessWidget {
  const InstructOSTextLockup({
    super.key,
    this.centered = false,
    this.markSize = 30,
    this.wordmarkSize = 30,
    this.spacing = 12,
  });

  final bool centered;
  final double markSize;
  final double wordmarkSize;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ) ??
        const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        );

    final markStyle = base.copyWith(
      fontSize: markSize,
      color: theme.colorScheme.onSurface,
    );

    final wordStyle = base.copyWith(
      fontSize: wordmarkSize,
      color: theme.colorScheme.onSurface,
      letterSpacing: -0.15,
    );

    return Wrap(
      alignment: centered ? WrapAlignment.center : WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: spacing,
      runSpacing: 6,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('I', style: markStyle),
            Text(
              '/',
              style: markStyle.copyWith(
                color: const Color(0xFF2A6BFF),
              ),
            ),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFF2A6BFF), Color(0xFF22D3EE)],
              ).createShader(bounds),
              child: Text(
                'OS',
                style: markStyle.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
        Text(
          InstructOSBranding.productName,
          style: wordStyle,
          textAlign: centered ? TextAlign.center : TextAlign.start,
        ),
      ],
    );
  }
}

class SchoolBrandBlock extends StatelessWidget {
  const SchoolBrandBlock({
    super.key,
    this.schoolName = InstructOSBranding.defaultSchoolName,
    this.compact = false,
  });

  final String schoolName;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logoSize = compact ? 34.0 : 42.0;
    return Row(
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      children: [
        Container(
          width: logoSize,
          height: logoSize,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.surface,
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          child: Image.asset(
            InstructOSBranding.schoolLogoAsset,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
        if (!compact) ...[
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              schoolName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class CoBrandingLockup extends StatelessWidget {
  const CoBrandingLockup({
    super.key,
    this.schoolName = InstructOSBranding.defaultSchoolName,
    this.compact = false,
    this.officialLine = false,
  });

  final String schoolName;
  final bool compact;
  final bool officialLine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (officialLine) {
      return Text(
        'Official classroom OS of $schoolName',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return Row(
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      children: [
        SchoolBrandBlock(schoolName: schoolName, compact: compact),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: SizedBox(
            height: compact ? 28 : 36,
            child: VerticalDivider(
              color: theme.colorScheme.outlineVariant,
              thickness: 1,
              width: 1,
            ),
          ),
        ),
        InstructOSLogoLockup(
          compact: compact,
          height: compact ? 28 : 34,
        ),
      ],
    );
  }
}
