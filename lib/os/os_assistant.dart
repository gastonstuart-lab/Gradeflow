/// GradeFlow OS — AI Assistant Entry
///
/// [OSAssistantFab] is the always-visible floating AI orb button.
/// [OSAssistantPanel] is the slide-up panel with suggested actions
/// and a text entry for free-form AI requests.
///
/// This is Phase 1 scaffolding: the UI is complete but action routing is
/// placeholder — wire into OpenAI / action router in Phase 6.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/os/os_controller.dart';
import 'package:gradeflow/os/os_palette.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FLOATING BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class OSAssistantFab extends StatelessWidget {
  const OSAssistantFab({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GradeFlowOSController>();
    return GestureDetector(
      onTap: controller.toggleAssistant,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF5C8AFF), Color(0xFF7869F0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: OSColors.blue.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.auto_awesome_rounded,
          size: 22,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PANEL
// ─────────────────────────────────────────────────────────────────────────────

class OSAssistantPanel extends StatefulWidget {
  const OSAssistantPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<OSAssistantPanel> createState() => _OSAssistantPanelState();
}

class _OSAssistantPanelState extends State<OSAssistantPanel> {
  final TextEditingController _textCtrl = TextEditingController();
  bool _thinking = false;
  String? _lastResponse;

  static const List<_SuggestedAction> _suggestions = [
    _SuggestedAction(
      icon: Icons.summarize_outlined,
      label: 'Summarise today',
      prompt: 'Summarise my teaching schedule and priorities for today.',
    ),
    _SuggestedAction(
      icon: Icons.email_outlined,
      label: 'Draft a parent email',
      prompt: 'Help me draft a professional email to a parent.',
    ),
    _SuggestedAction(
      icon: Icons.grade_outlined,
      label: 'Grade rubric ideas',
      prompt: 'Suggest a grading rubric for a class assignment.',
    ),
    _SuggestedAction(
      icon: Icons.group_outlined,
      label: 'Group students',
      prompt: 'How should I group students for a collaborative activity?',
    ),
  ];

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitPrompt(String prompt) async {
    if (prompt.trim().isEmpty) return;
    setState(() {
      _thinking = true;
      _lastResponse = null;
    });

    // Phase 1 placeholder — wire real AI call in Phase 6
    await Future<void>.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      setState(() {
        _thinking = false;
        _lastResponse =
            'AI action routing will be connected in Phase 6. Prompt received: "$prompt"';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: OSColors.surface(dark),
        borderRadius: OSRadius.xlBr,
        border: Border.all(color: OSColors.border(dark), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.45 : 0.14),
            blurRadius: 40,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AssistantHeader(onClose: widget.onClose),
          if (_lastResponse != null) ...[
            _AssistantResponse(text: _lastResponse!, dark: dark),
            const SizedBox(height: 8),
          ],
          if (!_thinking) ...[
            _SuggestionsRow(
              suggestions: _suggestions,
              onTap: (s) {
                _textCtrl.text = s.prompt;
                _submitPrompt(s.prompt);
              },
            ),
            const SizedBox(height: 8),
          ],
          _AssistantInputBar(
            controller: _textCtrl,
            thinking: _thinking,
            onSubmit: _submitPrompt,
            dark: dark,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PANEL INTERNAL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _AssistantHeader extends StatelessWidget {
  const _AssistantHeader({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 6),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF5C8AFF), Color(0xFF7869F0)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 14,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'GradeFlow Assistant',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: OSColors.text(dark),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            iconSize: 20,
            color: OSColors.textSecondary(dark),
            style: IconButton.styleFrom(minimumSize: const Size(32, 32)),
          ),
        ],
      ),
    );
  }
}

class _AssistantResponse extends StatelessWidget {
  const _AssistantResponse({required this.text, required this.dark});
  final String text;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OSColors.blue.withValues(alpha: 0.07),
        borderRadius: OSRadius.lgBr,
        border: Border.all(
          color: OSColors.blue.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: OSColors.text(dark),
          height: 1.5,
        ),
      ),
    );
  }
}

class _SuggestedAction {
  const _SuggestedAction({
    required this.icon,
    required this.label,
    required this.prompt,
  });

  final IconData icon;
  final String label;
  final String prompt;
}

class _SuggestionsRow extends StatelessWidget {
  const _SuggestionsRow({required this.suggestions, required this.onTap});
  final List<_SuggestedAction> suggestions;
  final ValueChanged<_SuggestedAction> onTap;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: suggestions
            .map(
              (s) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _SuggestionChip(
                  suggestion: s,
                  dark: dark,
                  onTap: () => onTap(s),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.suggestion,
    required this.dark,
    required this.onTap,
  });

  final _SuggestedAction suggestion;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: dark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: OSRadius.pillBr,
          border: Border.all(color: OSColors.border(dark), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(suggestion.icon, size: 13, color: OSColors.blue),
            const SizedBox(width: 5),
            Text(
              suggestion.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: OSColors.textSecondary(dark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistantInputBar extends StatelessWidget {
  const _AssistantInputBar({
    required this.controller,
    required this.thinking,
    required this.onSubmit,
    required this.dark,
  });

  final TextEditingController controller;
  final bool thinking;
  final ValueChanged<String> onSubmit;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: dark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
                borderRadius: OSRadius.pillBr,
                border: Border.all(color: OSColors.border(dark), width: 1),
              ),
              child: TextField(
                controller: controller,
                enabled: !thinking,
                onSubmitted: onSubmit,
                style: TextStyle(
                  fontSize: 13,
                  color: OSColors.text(dark),
                ),
                decoration: InputDecoration(
                  hintText: 'Ask anything…',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: OSColors.textMuted(dark),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: thinking ? null : () => onSubmit(controller.text),
            child: AnimatedContainer(
              duration: OSMotion.fast,
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: thinking
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF5C8AFF), Color(0xFF7869F0)],
                      ),
                color: thinking ? OSColors.border(dark) : null,
                shape: BoxShape.circle,
              ),
              child: thinking
                  ? const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.arrow_upward_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
