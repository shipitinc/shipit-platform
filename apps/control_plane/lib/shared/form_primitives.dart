import 'package:flutter/material.dart';

import '../core/design_tokens.dart';
import '../core/theme.dart';

/// The form vocabulary shared by the two intake forms (`Report a bug` and
/// `Request a feature`).
///
/// Every measurement here is transcribed from the `Create Report` and
/// `Request Feature` boards and their `BPM ·` (390px) counterparts. The boards
/// are the same drawing at two widths, so one implementation serves both: the
/// fields stack full width on mobile and pair into columns on desktop.
class FormMetrics {
  const FormMetrics._();

  /// `Fld L n` — the label's own slot.
  static const double labelSlot = 14;

  /// Label baseline to the top of its box.
  static const double labelGap = 4;

  /// `Fld Box n` — the multi-line box height.
  static const double boxMulti = 70;

  /// Vertical padding that makes a single-line box paint 34px tall.
  static const double padSingle = 10.5;

  /// Vertical padding that makes a multi-line box paint 70px tall.
  static const double padMulti = 15.5;

  /// Vertical padding that makes a select paint 34px tall.
  static const double padSelect = 5;

  /// Gap between stacked fields. The board uses 18 everywhere except directly
  /// after the first field, where it uses 14.
  static const double fieldGap = 18;

  static const double fieldGapFirst = 14;
}

/// A section heading in the forms' 21px slot.
class FormSectionTitle extends StatelessWidget {
  const FormSectionTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 21,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: ShipItType.detailTitle.copyWith(
            color: context.palette.inkPrimary,
          ),
        ),
      ),
    );
  }
}

/// Label slot + control: the board draws `Fld L n` in a 14px box with the
/// control box 4px below it.
class FormFieldSlot extends StatelessWidget {
  const FormFieldSlot({
    super.key,
    required this.label,
    required this.control,
    this.labelGap,
  });

  final String label;
  final Widget control;

  /// Label baseline to the top of the box. The bug form sets its labels 4px
  /// above their boxes; the Request Feature board sets them 8px above, so the
  /// label rides closer to the answer it describes.
  final double? labelGap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: FormMetrics.labelSlot,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ShipItType.microLabel.copyWith(
                color: context.palette.inkTertiary,
              ),
            ),
          ),
        ),
        SizedBox(height: labelGap ?? FormMetrics.labelGap),
        control,
      ],
    );
  }
}

/// `contentPadding` is what actually sets a box's height: `InputDecorator`
/// paints its outline around `contentPadding + text`, not around the outer
/// constraints, so a `SizedBox` alone would leave the outline short of the
/// board's 34px / 70px boxes. The vertical values below are measured so the
/// painted box lands on those sizes (`10 + 13 + 10 + 1 = 34`,
/// `15.5 + 39 + 15.5 = 70`, `5 + 24 + 5 = 34`).
InputDecoration formBoxDecoration(
  BuildContext context, {
  required double vertical,
  String? hintText,
  String? errorText,
}) {
  final palette = context.palette;
  return InputDecoration(
    hintText: hintText,
    hintStyle: ShipItType.bodySmall.copyWith(color: palette.inkTertiary),
    errorText: errorText,
    filled: true,
    fillColor: palette.card,
    isDense: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(ShipItMetrics.radius),
      borderSide: BorderSide(color: palette.cardBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(ShipItMetrics.radius),
      borderSide: BorderSide(color: palette.cardBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(ShipItMetrics.radius),
      borderSide: BorderSide(color: palette.accent, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(ShipItMetrics.radius),
      borderSide: BorderSide(color: palette.negative),
    ),
    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: vertical),
  );
}

/// `Fld Box n` for a one-line answer: a 34px box with the text centred.
class SingleLineInput extends StatelessWidget {
  const SingleLineInput({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.errorText,
  });

  final String hintText;
  final String? errorText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      maxLines: 1,
      onChanged: onChanged,
      style: ShipItType.bodySmall.copyWith(color: context.palette.inkPrimary),
      decoration: formBoxDecoration(
        context,
        vertical: FormMetrics.padSingle,
        hintText: hintText,
        errorText: errorText,
      ),
    );
  }
}

/// `Fld Box n` for a multi-line answer: a fixed 70px box, three lines tall.
class TextAreaBox extends StatelessWidget {
  const TextAreaBox({
    super.key,
    required this.hintText,
    required this.onChanged,
  });

  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      maxLines: 3,
      minLines: 3,
      onChanged: onChanged,
      style: ShipItType.bodySmall.copyWith(color: context.palette.inkPrimary),
      decoration: formBoxDecoration(
        context,
        vertical: FormMetrics.padMulti,
        hintText: hintText,
      ),
    );
  }
}

/// A single-select answer: the board's 34px box with a disclosure caret.
class FormSelect extends StatelessWidget {
  const FormSelect({
    super.key,
    required this.hint,
    required this.value,
    required this.options,
    required this.onChanged,
    this.errorText,
  });

  final String hint;
  final String? value;
  final List<(String, String)> options;
  final ValueChanged<String?> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DropdownButtonFormField<String>(
      // Keyed so a programmatic clear (product list refresh) rebuilds the
      // field; `initialValue` alone would keep the stale selection.
      key: ValueKey('select-${value ?? hint}'),
      initialValue: options.any((o) => o.$1 == value) ? value : null,
      hint: Text(
        hint,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: ShipItType.bodySmall.copyWith(color: palette.inkTertiary),
      ),
      items: [
        for (final (id, label) in options)
          DropdownMenuItem(
            value: id,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ShipItType.bodySmall.copyWith(color: palette.inkPrimary),
            ),
          ),
      ],
      onChanged: onChanged,
      isDense: true,
      isExpanded: true,
      iconSize: 18,
      iconEnabledColor: palette.inkSecondary,
      iconDisabledColor: palette.inkSecondary,
      style: ShipItType.bodySmall.copyWith(color: palette.inkPrimary),
      dropdownColor: palette.card,
      decoration: formBoxDecoration(
        context,
        vertical: FormMetrics.padSelect,
        errorText: errorText,
      ),
    );
  }
}

/// Two fields side by side in the desktop layout's 20px-guttered columns.
class FieldPair extends StatelessWidget {
  const FieldPair({super.key, required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 20),
        Expanded(child: right),
      ],
    );
  }
}

/// A single-line text field with label, matching the design's form vocabulary.
class DesignTextField extends StatelessWidget {
  const DesignTextField({
    super.key,
    this.initialValue,
    required this.label,
    this.hintText,
    required this.onChanged,
  });

  final String? initialValue;
  final String label;
  final String? hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: initialValue);
    return FormFieldSlot(
      label: label,
      control: TextField(
        controller: controller,
        maxLines: 1,
        onChanged: onChanged,
        style: ShipItType.bodySmall.copyWith(color: context.palette.inkPrimary),
        decoration: formBoxDecoration(
          context,
          vertical: FormMetrics.padSingle,
          hintText: hintText,
        ),
      ),
    );
  }
}
