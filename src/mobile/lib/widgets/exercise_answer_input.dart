import 'package:flutter/material.dart';

/// Shared answer control for lesson exercises and question review.
class ExerciseAnswerInput extends StatefulWidget {
  const ExerciseAnswerInput({
    required this.type,
    required this.options,
    required this.answer,
    required this.enabled,
    required this.onAnswerChanged,
    required this.onSubmit,
    required this.textFieldKey,
    required this.submitKey,
    required this.submitLabel,
    this.submitOnOptionTap = false,
    this.optionKeyBuilder,
    this.hintText,
    super.key,
  });

  final String type;
  final List<String> options;
  final String answer;
  final bool enabled;
  final ValueChanged<String> onAnswerChanged;
  final ValueChanged<String> onSubmit;
  final Key textFieldKey;
  final Key submitKey;
  final String submitLabel;
  final bool submitOnOptionTap;
  final Key Function(String option)? optionKeyBuilder;
  final String? hintText;

  @override
  State<ExerciseAnswerInput> createState() => _ExerciseAnswerInputState();
}

class _ExerciseAnswerInputState extends State<ExerciseAnswerInput> {
  late final TextEditingController _controller = TextEditingController(text: widget.answer);
  final List<int> _orderedIndexes = [];
  String _selectedOption = '';
  late String _typedAnswer = widget.answer;

  @override
  void didUpdateWidget(covariant ExerciseAnswerInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.answer != widget.answer && _controller.text != widget.answer) {
      _controller.value = TextEditingValue(text: widget.answer);
      _typedAnswer = widget.answer;
    }
    if (oldWidget.type != widget.type || oldWidget.options != widget.options) {
      _orderedIndexes.clear();
      _selectedOption = '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _update(String answer) {
    widget.onAnswerChanged(answer);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.type == 'mcq') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final option in widget.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                key: widget.optionKeyBuilder?.call(option) ?? Key('answer_option_$option'),
                onPressed: !widget.enabled
                    ? null
                    : () {
                        setState(() => _selectedOption = option);
                        _update(option);
                        if (widget.submitOnOptionTap) widget.onSubmit(option);
                      },
                child: Text(option),
              ),
            ),
          if (!widget.submitOnOptionTap)
            FilledButton(
              key: widget.submitKey,
            onPressed: !widget.enabled || _selectedOption.isEmpty
                  ? null
                  : () => widget.onSubmit(_selectedOption),
              child: Text(widget.submitLabel),
            ),
        ],
      );
    }
    if (widget.type == 'reorder') {
      final answer = _orderedIndexes.map((index) => widget.options[index]).join(' ');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(widget.options.length, (index) {
              final word = widget.options[index];
              final selected = _orderedIndexes.contains(index);
              return FilterChip(
                key: Key('answer_reorder_$index'),
                label: Text(word),
                selected: selected,
                onSelected: !widget.enabled
                    ? null
                    : (selected) => setState(() {
                          if (selected) {
                            _orderedIndexes.add(index);
                          } else {
                            _orderedIndexes.remove(index);
                          }
                          _update(_orderedIndexes
                              .map((selectedIndex) => widget.options[selectedIndex])
                              .join(' '));
                        }),
              );
            }),
          ),
          const SizedBox(height: 12),
          Text(answer),
          const SizedBox(height: 20),
          FilledButton(
            key: widget.submitKey,
            onPressed: !widget.enabled || answer.trim().isEmpty
                ? null
                : () => widget.onSubmit(answer),
            child: Text(widget.submitLabel),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: widget.textFieldKey,
          controller: _controller,
          enabled: widget.enabled,
          decoration: InputDecoration(hintText: widget.hintText),
          onChanged: (answer) {
            setState(() => _typedAnswer = answer);
            _update(answer);
          },
          onSubmitted: widget.enabled ? widget.onSubmit : null,
        ),
        const SizedBox(height: 20),
        FilledButton(
          key: widget.submitKey,
          onPressed: !widget.enabled || _typedAnswer.trim().isEmpty
              ? null
              : () => widget.onSubmit(_typedAnswer),
          child: Text(widget.submitLabel),
        ),
      ],
    );
  }
}
