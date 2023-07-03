import 'package:flutter/material.dart';
import 'package:parchment/parchment.dart';

import 'controller.dart';

const double kToolbarHeight = 56.0;

class InsertEmbedButton extends StatelessWidget {
  final FleatherController controller;
  final IconData icon;

  const InsertEmbedButton({
    Key? key,
    required this.controller,
    required this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FLIconButton(
      highlightElevation: 0,
      hoverElevation: 0,
      size: 32,
      icon: Icon(
        icon,
        size: 18,
        color: Theme.of(context).iconTheme.color,
      ),
      fillColor: Theme.of(context).canvasColor,
      onPressed: () {
        final index = controller.selection.baseOffset;
        final length = controller.selection.extentOffset - index;
        // Move the cursor to the beginning of the line right after the embed.
        // 2 = 1 for the embed itself and 1 for the newline after it
        final newSelection = controller.selection.copyWith(
          baseOffset: index + 2,
          extentOffset: index + 2,
        );
        controller.replaceText(index, length, BlockEmbed.horizontalRule,
            selection: newSelection);
      },
    );
  }
}

class UndoRedoButton extends StatelessWidget {
  final FleatherController controller;
  final _UndoRedoButtonVariant _variant;

  const UndoRedoButton._(this.controller, this._variant, {Key? key})
      : super(key: key);

  const UndoRedoButton.undo({
    Key? key,
    required FleatherController controller,
  }) : this._(controller, _UndoRedoButtonVariant.undo, key: key);

  const UndoRedoButton.redo({
    Key? key,
    required FleatherController controller,
  }) : this._(controller, _UndoRedoButtonVariant.redo, key: key);

  bool _isEnabled() {
    if (_variant == _UndoRedoButtonVariant.undo) {
      return controller.canUndo;
    } else {
      return controller.canRedo;
    }
  }

  void _onPressed() {
    if (_variant == _UndoRedoButtonVariant.undo) {
      controller.undo();
    } else {
      controller.redo();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final icon =
              _variant == _UndoRedoButtonVariant.undo ? Icons.undo : Icons.redo;
          final isEnabled = _isEnabled();
          final theme = Theme.of(context);

          return FLIconButton(
            highlightElevation: 0,
            hoverElevation: 0,
            size: 32,
            icon: Icon(
              icon,
              size: 18,
              color: isEnabled ? theme.iconTheme.color : theme.disabledColor,
            ),
            fillColor: Theme.of(context).canvasColor,
            onPressed: isEnabled ? _onPressed : null,
          );
        });
  }
}

enum _UndoRedoButtonVariant {
  undo,
  redo,
}

/// Toolbar button for formatting text as a link.
class LinkStyleButton extends StatefulWidget {
  final FleatherController controller;
  final IconData? icon;

  const LinkStyleButton({
    Key? key,
    required this.controller,
    this.icon,
  }) : super(key: key);

  @override
  State<LinkStyleButton> createState() => _LinkStyleButtonState();
}

class _LinkStyleButtonState extends State<LinkStyleButton> {
  void _didChangeSelection() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_didChangeSelection);
  }

  @override
  void didUpdateWidget(covariant LinkStyleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_didChangeSelection);
      widget.controller.addListener(_didChangeSelection);
    }
  }

  @override
  void dispose() {
    super.dispose();
    widget.controller.removeListener(_didChangeSelection);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = !widget.controller.selection.isCollapsed;
    final pressedHandler = isEnabled ? () => _openLinkDialog(context) : null;
    return FLIconButton(
      highlightElevation: 0,
      hoverElevation: 0,
      size: 32,
      icon: Icon(
        widget.icon ?? Icons.link,
        size: 18,
        color: isEnabled ? theme.iconTheme.color : theme.disabledColor,
      ),
      fillColor: Theme.of(context).canvasColor,
      onPressed: pressedHandler,
    );
  }

  void _openLinkDialog(BuildContext context) {
    showDialog<String>(
      context: context,
      builder: (ctx) {
        return const _LinkDialog();
      },
    ).then(_linkSubmitted);
  }

  void _linkSubmitted(String? value) {
    if (value == null || value.isEmpty) return;
    widget.controller
        .formatSelection(ParchmentAttribute.link.fromString(value));
  }
}

class _LinkDialog extends StatefulWidget {
  const _LinkDialog({Key? key}) : super(key: key);

  @override
  _LinkDialogState createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  String _link = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: TextField(
        decoration: const InputDecoration(labelText: 'Paste a link'),
        autofocus: true,
        onChanged: _linkChanged,
      ),
      actions: [
        //TODO: Update to use TextButton
        TextButton(
          onPressed: _link.isNotEmpty ? _applyLink : null,
          child: const Text('Apply'),
        ),
      ],
    );
  }

  void _linkChanged(String value) {
    setState(() {
      _link = value;
    });
  }

  void _applyLink() {
    Navigator.pop(context, _link);
  }
}

/// Builder for toolbar buttons handling toggleable style attributes.
///
/// See [defaultToggleStyleButtonBuilder] as a reference implementation.
typedef ToggleStyleButtonBuilder = Widget Function(
  BuildContext context,
  ParchmentAttribute attribute,
  IconData icon,
  bool isToggled,
  VoidCallback? onPressed,
);

/// Toolbar button which allows to toggle a style attribute on or off.
class ToggleStyleButton extends StatefulWidget {
  /// The style attribute controlled by this button.
  final ParchmentAttribute attribute;

  /// The icon representing the style [attribute].
  final IconData icon;

  /// Controller attached to a Fleather editor.
  final FleatherController controller;

  /// Builder function to customize visual representation of this button.
  final ToggleStyleButtonBuilder childBuilder;

  const ToggleStyleButton({
    Key? key,
    required this.attribute,
    required this.icon,
    required this.controller,
    this.childBuilder = defaultToggleStyleButtonBuilder,
  }) : super(key: key);

  @override
  State<ToggleStyleButton> createState() => _ToggleStyleButtonState();
}

class _ToggleStyleButtonState extends State<ToggleStyleButton> {
  late bool _isToggled;

  ParchmentStyle get _selectionStyle => widget.controller.getSelectionStyle();

  void _didChangeEditingValue() {
    setState(() => _checkIsToggled());
  }

  @override
  void initState() {
    super.initState();
    _checkIsToggled();
    widget.controller.addListener(_didChangeEditingValue);
  }

  @override
  void didUpdateWidget(covariant ToggleStyleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_didChangeEditingValue);
      widget.controller.addListener(_didChangeEditingValue);
      _checkIsToggled();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_didChangeEditingValue);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If the cursor is currently inside a code block we disable all
    // toggle style buttons (except the code block button itself) since there
    // is no point in applying styles to a unformatted block of text.
    // TODO: Add code block checks to heading and embed buttons as well.
    final isInCodeBlock =
        _selectionStyle.containsSame(ParchmentAttribute.block.code);
    final isEnabled =
        !isInCodeBlock || widget.attribute == ParchmentAttribute.block.code;
    return widget.childBuilder(context, widget.attribute, widget.icon,
        _isToggled, isEnabled ? _toggleAttribute : null);
  }

  void _toggleAttribute() {
    if (_isToggled) {
      if (!widget.attribute.isUnset) {
        widget.controller.formatSelection(widget.attribute.unset);
      }
    } else {
      widget.controller.formatSelection(widget.attribute);
    }
  }

  void _checkIsToggled() {
    if (widget.attribute.isUnset) {
      _isToggled = !_selectionStyle.contains(widget.attribute);
    } else {
      _isToggled = _selectionStyle.containsSame(widget.attribute);
    }
  }
}

/// Default builder for toggle style buttons.
Widget defaultToggleStyleButtonBuilder(
  BuildContext context,
  ParchmentAttribute attribute,
  IconData icon,
  bool isToggled,
  VoidCallback? onPressed,
) {
  final theme = Theme.of(context);
  final isEnabled = onPressed != null;
  final iconColor = isEnabled
      ? isToggled
          ? theme.primaryIconTheme.color
          : theme.iconTheme.color
      : theme.disabledColor;
  final fillColor = isToggled ? theme.colorScheme.secondary : theme.canvasColor;
  return FLIconButton(
    highlightElevation: 0,
    hoverElevation: 0,
    size: 32,
    icon: Icon(icon, size: 18, color: iconColor),
    fillColor: fillColor,
    onPressed: onPressed,
  );
}

/// Toolbar button which allows to apply heading style to a line of text in
/// Fleather editor.
///
/// Works as a dropdown menu button.
// TODO: Add "dense" parameter which if set to true changes the button to use an icon instead of text (useful for mobile layouts)
class SelectHeadingStyleButton extends StatefulWidget {
  final FleatherController controller;

  final List<HeadingStyle> headingStyles;

  final Map<HeadingStyle, String>? headingStylesText;

  const SelectHeadingStyleButton({
    Key? key,
    required this.controller,
    required this.headingStyles,
    this.headingStylesText,
  }) : super(key: key);

  @override
  State<SelectHeadingStyleButton> createState() =>
      _SelectHeadingStyleButtonState();
}

class _SelectHeadingStyleButtonState extends State<SelectHeadingStyleButton> {
  ParchmentAttribute? _value;

  ParchmentStyle get _selectionStyle => widget.controller.getSelectionStyle();

  void _didChangeEditingValue() {
    setState(() {
      _value = _selectionStyle.get(ParchmentAttribute.heading) ??
          ParchmentAttribute.heading.unset;
    });
  }

  void _selectAttribute(value) {
    widget.controller.formatSelection(value);
  }

  @override
  void initState() {
    super.initState();
    _value = _selectionStyle.get(ParchmentAttribute.heading) ??
        ParchmentAttribute.heading.unset;
    widget.controller.addListener(_didChangeEditingValue);
  }

  @override
  void didUpdateWidget(covariant SelectHeadingStyleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_didChangeEditingValue);
      widget.controller.addListener(_didChangeEditingValue);
      _value = _selectionStyle.get(ParchmentAttribute.heading) ??
          ParchmentAttribute.heading.unset;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_didChangeEditingValue);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _selectHeadingStyleButtonBuilder(
      context,
      _value,
      widget.headingStyles
          .map((style) => style.toParchmentAttribute())
          .toList(),
      widget.headingStylesText
          ?.map((key, value) => MapEntry(key.toParchmentAttribute(), value)),
      _selectAttribute,
    );
  }
}

Widget _selectHeadingStyleButtonBuilder(
  BuildContext context,
  ParchmentAttribute? value,
  List<ParchmentAttribute> values,
  Map<ParchmentAttribute, String>? map,
  ValueChanged<ParchmentAttribute?> onSelected,
) {
  const style = TextStyle(fontSize: 12);

  final valueToText = map ??
      {
        ParchmentAttribute.heading.unset: 'Normal text',
        ParchmentAttribute.heading.level1: 'Heading 1',
        ParchmentAttribute.heading.level2: 'Heading 2',
        ParchmentAttribute.heading.level3: 'Heading 3',
      };

  return FLDropdownButton<ParchmentAttribute?>(
    highlightElevation: 0,
    hoverElevation: 0,
    height: 32,
    initialValue: value,
    items: values
        .map((value) => PopupMenuItem(
              value: value,
              height: 32,
              child: Text(valueToText[value]!, style: style),
            ))
        .toList(),
    onSelected: onSelected,
    child: Text(
      valueToText[value as ParchmentAttribute<int>]!,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );
}

class IndentationButton extends StatefulWidget {
  final bool increase;
  final FleatherController controller;

  const IndentationButton(
      {Key? key, this.increase = true, required this.controller})
      : super(key: key);

  @override
  State<IndentationButton> createState() => _IndentationButtonState();
}

class _IndentationButtonState extends State<IndentationButton> {
  ParchmentStyle get _selectionStyle => widget.controller.getSelectionStyle();

  void _didChangeEditingValue() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_didChangeEditingValue);
  }

  @override
  void didUpdateWidget(covariant IndentationButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_didChangeEditingValue);
      widget.controller.addListener(_didChangeEditingValue);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_didChangeEditingValue);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled =
        !_selectionStyle.containsSame(ParchmentAttribute.block.code);
    final theme = Theme.of(context);
    final iconColor = isEnabled ? theme.iconTheme.color : theme.disabledColor;
    return FLIconButton(
      highlightElevation: 0,
      hoverElevation: 0,
      size: 32,
      icon: Icon(
          widget.increase
              ? Icons.format_indent_increase
              : Icons.format_indent_decrease,
          size: 18,
          color: iconColor),
      fillColor: theme.canvasColor,
      onPressed: isEnabled
          ? () {
              final indentLevel =
                  _selectionStyle.get(ParchmentAttribute.indent)?.value ?? 0;
              if (indentLevel == 0 && !widget.increase) {
                return;
              }
              if (indentLevel == 1 && !widget.increase) {
                widget.controller
                    .formatSelection(ParchmentAttribute.indent.unset);
              } else {
                widget.controller.formatSelection(ParchmentAttribute.indent
                    .withLevel(indentLevel + (widget.increase ? 1 : -1)));
              }
            }
          : null,
    );
  }
}

class FleatherToolbar extends StatefulWidget implements PreferredSizeWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  const FleatherToolbar({Key? key, this.padding, required this.children})
      : super(key: key);

  factory FleatherToolbar.basic({
    Key? key,
    required FleatherController controller,
    EdgeInsetsGeometry? padding,
    bool hideBoldButton = false,
    bool hideItalicButton = false,
    bool hideUnderLineButton = false,
    bool hideStrikeThrough = false,
    bool hideInlineCode = false,
    bool hideHeadingStyle = false,
    bool hideIndentation = false,
    bool hideListNumbers = false,
    bool hideListBullets = false,
    bool hideListChecks = false,
    bool hideCodeBlock = false,
    bool hideQuote = false,
    bool hideLink = false,
    bool hideHorizontalRule = false,
    bool hideDirection = false,
    bool hideUndoRedo = false,
    List<Widget> leading = const <Widget>[],
    List<Widget> trailing = const <Widget>[],
    bool hideAlignment = false,
    List<HeadingStyle> headingStyles = HeadingStyle.values,
    Map<HeadingStyle, String>? headingStylesText,
  }) {
    return FleatherToolbar(key: key, padding: padding, children: [
      ...leading,
      Visibility(
        visible: !hideBoldButton,
        child: ToggleStyleButton(
          attribute: ParchmentAttribute.bold,
          icon: Icons.format_bold,
          controller: controller,
        ),
      ),
      const SizedBox(width: 1),
      Visibility(
        visible: !hideItalicButton,
        child: ToggleStyleButton(
          attribute: ParchmentAttribute.italic,
          icon: Icons.format_italic,
          controller: controller,
        ),
      ),
      const SizedBox(width: 1),
      Visibility(
        visible: !hideUnderLineButton,
        child: ToggleStyleButton(
          attribute: ParchmentAttribute.underline,
          icon: Icons.format_underline,
          controller: controller,
        ),
      ),
      const SizedBox(width: 1),
      Visibility(
        visible: !hideStrikeThrough,
        child: ToggleStyleButton(
          attribute: ParchmentAttribute.strikethrough,
          icon: Icons.format_strikethrough,
          controller: controller,
        ),
      ),
      const SizedBox(width: 1),
      Visibility(
        visible: !hideInlineCode,
        child: ToggleStyleButton(
          attribute: ParchmentAttribute.inlineCode,
          icon: Icons.code,
          controller: controller,
        ),
      ),
      Visibility(
          visible: !hideBoldButton &&
              !hideItalicButton &&
              !hideUnderLineButton &&
              !hideStrikeThrough &&
              !hideInlineCode,
          child: VerticalDivider(
              indent: 16, endIndent: 16, color: Colors.grey.shade400)),

      /// ################################################################

      Visibility(
          visible: !hideDirection,
          child: ToggleStyleButton(
            attribute: ParchmentAttribute.rtl,
            icon: Icons.format_textdirection_r_to_l,
            controller: controller,
          )),
      Visibility(
          visible: !hideDirection,
          child: VerticalDivider(
              indent: 16, endIndent: 16, color: Colors.grey.shade400)),

      /// ################################################################

      Visibility(
        visible: !hideAlignment,
        child: ToggleStyleButton(
          attribute: ParchmentAttribute.left,
          icon: Icons.format_align_left,
          controller: controller,
        ),
      ),
      const SizedBox(width: 1),
      Visibility(
        visible: !hideAlignment,
        child: ToggleStyleButton(
          attribute: ParchmentAttribute.center,
          icon: Icons.format_align_center,
          controller: controller,
        ),
      ),
      const SizedBox(width: 1),
      Visibility(
        visible: !hideAlignment,
        child: ToggleStyleButton(
          attribute: ParchmentAttribute.right,
          icon: Icons.format_align_right,
          controller: controller,
        ),
      ),
      const SizedBox(width: 1),
      Visibility(
        visible: !hideAlignment,
        child: ToggleStyleButton(
          attribute: ParchmentAttribute.justify,
          icon: Icons.format_align_justify,
          controller: controller,
        ),
      ),
      Visibility(
          visible: !hideAlignment,
          child: VerticalDivider(
              indent: 16, endIndent: 16, color: Colors.grey.shade400)),

      /// ################################################################

      Visibility(
        visible: !hideIndentation,
        child: IndentationButton(
          increase: false,
          controller: controller,
        ),
      ),
      Visibility(
        visible: !hideIndentation,
        child: IndentationButton(
          controller: controller,
        ),
      ),
      Visibility(
          visible: !hideIndentation,
          child: VerticalDivider(
              indent: 16, endIndent: 16, color: Colors.grey.shade400)),

      /// ################################################################

      Visibility(
          visible: !hideHeadingStyle,
          child: SelectHeadingStyleButton(
            controller: controller,
            headingStyles: headingStyles,
            headingStylesText: headingStylesText,
          )),
      Visibility(
          visible: !hideHeadingStyle,
          child: VerticalDivider(
              indent: 16, endIndent: 16, color: Colors.grey.shade400)),

      /// ################################################################
      Visibility(
        visible: !hideListNumbers,
        child: ToggleStyleButton(
          attribute: ParchmentAttribute.block.numberList,
          controller: controller,
          icon: Icons.format_list_numbered,
        ),
      ),

      Visibility(
        visible: !hideListBullets,
        child: ToggleStyleButton(
          attribute: ParchmentAttribute.block.bulletList,
          controller: controller,
          icon: Icons.format_list_bulleted,
        ),
      ),
      Visibility(
        visible: !hideListChecks,
        child: ToggleStyleButton(
          attribute: ParchmentAttribute.block.checkList,
          controller: controller,
          icon: Icons.checklist,
        ),
      ),
      Visibility(
        visible: !hideCodeBlock,
        child: ToggleStyleButton(
          attribute: ParchmentAttribute.block.code,
          controller: controller,
          icon: Icons.code,
        ),
      ),
      Visibility(
          visible: !hideListNumbers &&
              !hideListBullets &&
              !hideListChecks &&
              !hideCodeBlock,
          child: VerticalDivider(
              indent: 16, endIndent: 16, color: Colors.grey.shade400)),

      /// ################################################################

      Visibility(
        visible: !hideQuote,
        child: ToggleStyleButton(
          attribute: ParchmentAttribute.block.quote,
          controller: controller,
          icon: Icons.format_quote,
        ),
      ),
      Visibility(
          visible: !hideQuote,
          child: VerticalDivider(
              indent: 16, endIndent: 16, color: Colors.grey.shade400)),

      /// ################################################################

      Visibility(
          visible: !hideLink, child: LinkStyleButton(controller: controller)),
      Visibility(
        visible: !hideHorizontalRule,
        child: InsertEmbedButton(
          controller: controller,
          icon: Icons.horizontal_rule,
        ),
      ),
      Visibility(
          visible: !hideHorizontalRule || !hideLink,
          child: VerticalDivider(
              indent: 16, endIndent: 16, color: Colors.grey.shade400)),

      /// ################################################################

      Visibility(
        visible: !hideUndoRedo,
        child: UndoRedoButton.undo(
          controller: controller,
        ),
      ),
      Visibility(
        visible: !hideUndoRedo,
        child: UndoRedoButton.redo(
          controller: controller,
        ),
      ),

      ...trailing,
    ]);
  }

  @override
  State<FleatherToolbar> createState() => _FleatherToolbarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _FleatherToolbarState extends State<FleatherToolbar> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 8),
      constraints: BoxConstraints.tightFor(height: widget.preferredSize.height),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: widget.children,
        ),
      ),
    );
  }
}

/// Default icon button used in Fleather editor toolbar.
///
/// Named with a "Z" prefix to distinguish from the Flutter's built-in version.
class FLIconButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget? icon;
  final double size;
  final Color? fillColor;
  final double hoverElevation;
  final double highlightElevation;

  const FLIconButton({
    Key? key,
    required this.onPressed,
    this.icon,
    this.size = 40,
    this.fillColor,
    this.hoverElevation = 1,
    this.highlightElevation = 1,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints.tightFor(width: size, height: size),
      child: RawMaterialButton(
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        padding: EdgeInsets.zero,
        fillColor: fillColor,
        elevation: 0,
        hoverElevation: hoverElevation,
        highlightElevation: hoverElevation,
        onPressed: onPressed,
        child: icon,
      ),
    );
  }
}

class FLDropdownButton<T> extends StatefulWidget {
  final double height;
  final Color? fillColor;
  final double hoverElevation;
  final double highlightElevation;
  final Widget child;
  final T initialValue;
  final List<PopupMenuEntry<T>> items;
  final ValueChanged<T> onSelected;

  const FLDropdownButton({
    Key? key,
    this.height = 40,
    this.fillColor,
    this.hoverElevation = 1,
    this.highlightElevation = 1,
    required this.child,
    required this.initialValue,
    required this.items,
    required this.onSelected,
  }) : super(key: key);

  @override
  State<FLDropdownButton<T>> createState() => _FLDropdownButtonState<T>();
}

class _FLDropdownButtonState<T> extends State<FLDropdownButton<T>> {
  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints.tightFor(height: widget.height),
      child: RawMaterialButton(
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        padding: EdgeInsets.zero,
        fillColor: widget.fillColor,
        elevation: 0,
        hoverElevation: widget.hoverElevation,
        highlightElevation: widget.hoverElevation,
        onPressed: _showMenu,
        child: _buildContent(context),
      ),
    );
  }

  void _showMenu() {
    final popupMenuTheme = PopupMenuTheme.of(context);
    final button = context.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomLeft(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    showMenu<T>(
      context: context,
      elevation: 4,
      // widget.elevation ?? popupMenuTheme.elevation,
      initialValue: widget.initialValue,
      items: widget.items,
      position: position,
      shape: popupMenuTheme.shape,
      // widget.shape ?? popupMenuTheme.shape,
      color: popupMenuTheme.color, // widget.color ?? popupMenuTheme.color,
      // captureInheritedThemes: widget.captureInheritedThemes,
    ).then((T? newValue) {
      if (!mounted) return null;
      if (newValue == null) {
        // if (widget.onCanceled != null) widget.onCanceled();
        return null;
      }
      widget.onSelected(newValue);
    });
  }

  Widget _buildContent(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints.tightFor(width: 110),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          children: [
            widget.child,
            Expanded(child: Container()),
            const Icon(Icons.arrow_drop_down, size: 14)
          ],
        ),
      ),
    );
  }
}

enum HeadingStyle {
  normalText,
  heading1,
  heading2,
  heading3;

  ParchmentAttribute toParchmentAttribute() {
    switch (this) {
      case HeadingStyle.normalText:
        return ParchmentAttribute.heading.unset;
      case HeadingStyle.heading1:
        return ParchmentAttribute.heading.level1;
      case HeadingStyle.heading2:
        return ParchmentAttribute.heading.level2;
      case HeadingStyle.heading3:
        return ParchmentAttribute.heading.level3;
    }
  }
}
