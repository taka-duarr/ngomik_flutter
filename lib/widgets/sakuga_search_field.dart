import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import 'sakuga_fx.dart';

/// Search field in the Sakuga style: plain at rest (flat card, thick line,
/// hard offset shadow), and it reacts like an anime cut when used.
///
/// - Focus: the box pops on a spring and three magenta wedges fly off its
///   top-right corner.
/// - Every keystroke: the box gives a little and a puff of dust (now and
///   then a crystal chip) kicks up from where the caret is.
///
/// Behaviour mirrors `<sakuga-input>`; colours are adapted to the dark
/// palette (light line instead of ink, indigo shadow instead of lavender).
/// With reduced motion on, nothing is drawn and the box does not move.
class SakugaSearchField extends StatefulWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final bool showClear;
  final bool autofocus;
  final double height;

  const SakugaSearchField({
    super.key,
    this.controller,
    required this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.showClear = false,
    this.autofocus = false,
    this.height = 46,
  });

  @override
  State<SakugaSearchField> createState() => _SakugaSearchFieldState();
}

class _SakugaSearchFieldState extends State<SakugaSearchField>
    with SingleTickerProviderStateMixin {
  // Look
  static const double _line = 2.4;
  static const double _radius = 15;
  static const Color _card = AppColors.card;
  static const Color _ink = Color(0xFFE4E2F7);
  static const Color _hardShadow = SakugaFx.line;
  static const Offset _shadowOffset = Offset(4, 5);
  static const double _textLeft = _line + 14 + 19 + 10; // line, gap, icon, gap
  static const TextStyle _textStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  final FocusNode _focus = FocusNode();
  TextEditingController? _ownController;
  TextEditingController get _controller => widget.controller ?? (_ownController ??= TextEditingController());

  // Scale spring (same stiffness/damping as the original: 700 / 16).
  final ValueNotifier<double> _scale = ValueNotifier(1);
  double _x = 1, _v = 0;
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    _focus.addListener(_onFocus);
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocus)
      ..dispose();
    _ticker.dispose();
    _scale.dispose();
    _ownController?.dispose();
    super.dispose();
  }

  bool get _calm => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  void _kick(double to) {
    if (_calm) return;
    _x = to;
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.034);
    _last = elapsed;
    if (dt > 0) {
      final n = (dt / 0.008).ceil();
      final h = dt / n;
      for (var i = 0; i < n; i++) {
        _v += (-700 * (_x - 1) - 16 * _v) * h;
        _x += _v * h;
      }
    }
    final settled = (_x - 1).abs() < 0.0006 && _v.abs() < 0.01;
    if (settled) {
      _x = 1;
      _v = 0;
      _ticker.stop();
    }
    _scale.value = _x;
  }

  RenderBox? get _box {
    final box = context.findRenderObject();
    return box is RenderBox && box.hasSize && box.attached ? box : null;
  }

  void _onFocus() {
    if (!_focus.hasFocus) return;
    final box = _box;
    if (box == null) return;
    _kick(1.04);
    final corner = box.localToGlobal(Offset(box.size.width, 0));
    SakugaFx.instance.ticks(
      context,
      corner + const Offset(-6, -4),
      dir: -1.05,
      n: 3,
      r: 5,
      len: 17,
      fan: 0.36,
      life: 0.5,
    );
  }

  void _onChanged(String value) {
    _dust();
    widget.onChanged?.call(value);
  }

  /// A little dust where the caret is.
  void _dust() {
    final box = _box;
    if (box == null) {
      return;
    }
    _kick(0.985);

    final text = _controller.text;
    final caret = _controller.selection.baseOffset;
    final before = text.substring(0, caret < 0 ? text.length : caret.clamp(0, text.length));
    final tp = TextPainter(
      text: TextSpan(text: before, style: DefaultTextStyle.of(context).style.merge(_textStyle)),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final rightInset = widget.showClear ? 48.0 : 14.0;
    final maxX = box.size.width - _textLeft - rightInset;
    final x = _textLeft + tp.width.clamp(0.0, maxX < 0 ? 0.0 : maxX);
    tp.dispose();

    final origin = box.localToGlobal(Offset(x, box.size.height / 2 + 9));
    final fx = SakugaFx.instance;
    fx.puff(
      context,
      origin,
      size: SakugaFx.rnd(4, 6),
      n: 2,
      vy: -22,
      vx: SakugaFx.rnd(-10, 10),
      life: 0.4,
    );
    if (SakugaFx.rnd(1) < 0.35) {
      fx.shards(context, origin - const Offset(0, 4), n: 2, speed: 110, size: 3, life: 0.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final field = Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: _ink, width: _line),
        boxShadow: const [BoxShadow(color: _hardShadow, offset: _shadowOffset)],
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(Icons.search_rounded, size: 19, color: AppColors.primaryLight),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              autofocus: widget.autofocus,
              onChanged: _onChanged,
              onSubmitted: widget.onSubmitted,
              textInputAction: TextInputAction.search,
              cursorColor: AppColors.primaryLight,
              style: _textStyle,
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                hintText: widget.hintText,
                hintStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          if (widget.showClear)
            IconButton(
              tooltip: 'Hapus',
              icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
              onPressed: widget.onClear,
            )
          else
            const SizedBox(width: 14),
        ],
      ),
    );

    return ValueListenableBuilder<double>(
      valueListenable: _scale,
      child: field,
      // Always wrapped (even at 1) so the TextField keeps its element and focus.
      builder: (context, s, child) => Transform.scale(scale: s, child: child),
    );
  }
}
