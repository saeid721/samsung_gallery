
import 'package:flutter/material.dart';
import 'dart:math' as math show sin, pi;
import 'package:get/get.dart';
import 'theme_controller.dart';
import 'custom_spinner.dart';
import 'global_text.dart';

class ProgressHUD extends StatelessWidget {

  final Widget child;
  final String titileText;
  final bool inAsyncCall;
  final double opacity;
  final Color color;
  final Animation<Color>? valueColor;

  const ProgressHUD({
    super.key,
    required this.child,
    required this.inAsyncCall,
    this.opacity = 0.5,
    this.color = Colors.black,
    this.valueColor,
    this.titileText="Please Wait.....",
  });

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();

    List<Widget> widgetList = [];
    widgetList.add(child);
    if (inAsyncCall) {
      final modal = Stack(
        children: [
          Opacity(
            opacity: opacity,
            child: ModalBarrier(dismissible: false, color: color),
          ),
          Material(
            color: Colors.black26,
            child: Center(
              child: Container(
                  height: 125,
                  width: 120,
                  decoration: BoxDecoration(
                    color: themeController.lightDarkCardColor(context),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CustomSpinner(
                        color: themeController.lightDarkAppIconColor(context),
                        size: 50.0,
                      ),
                      GlobalText(
                        str: "Loading",
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: themeController.lightDarkTextColor(context),
                        textAlign: TextAlign.center,
                      )
                    ],
                  )
              ),
            ),
          )
        ],
      );
      widgetList.add(modal);
    }
    return Stack(
      children: widgetList,
    );
  }
}

class SpinKitFadingCircle extends StatefulWidget {
  const SpinKitFadingCircle({
    super.key,
    this.color,
    this.size = 50.0,
    this.itemBuilder,
    this.duration = const Duration(milliseconds: 1200),
    this.controller,
  })  : assert(
  !(itemBuilder is IndexedWidgetBuilder && color is Color) && !(itemBuilder == null && color == null),
  'You should specify either a itemBuilder or a color',
  );

  final Color? color;
  final double size;
  final IndexedWidgetBuilder? itemBuilder;
  final Duration duration;
  final AnimationController? controller;

  @override
  State<SpinKitFadingCircle> createState() => _SpinKitFadingCircleState();
}

class _SpinKitFadingCircleState extends State<SpinKitFadingCircle> with SingleTickerProviderStateMixin {
  static const _itemCount = 12;

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = (widget.controller ?? AnimationController(vsync: this, duration: widget.duration))..repeat();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox.fromSize(
        size: Size.square(widget.size),
        child: Stack(
          children: List.generate(_itemCount, (i) {
            final position = widget.size * .5;
            return Positioned.fill(
              left: position,
              top: position,
              child: Transform(
                transform: Matrix4.rotationZ(30.0 * i * 0.0174533),
                child: Align(
                  alignment: Alignment.center,
                  child: FadeTransition(
                    opacity: DelayTween(
                      begin: 0.0,
                      end: 1.0,
                      delay: i / _itemCount,
                    ).animate(_controller),
                    child: SizedBox.fromSize(
                      size: Size.square(widget.size * 0.15),
                      child: _itemBuilder(i),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _itemBuilder(int index) => widget.itemBuilder != null
      ? widget.itemBuilder!(context, index)
      : DecoratedBox(
    decoration: BoxDecoration(
      color: widget.color,
      shape: BoxShape.circle,
    ),
  );
}


class DelayTween extends Tween<double> {
  DelayTween({
    super.begin,
    super.end,
    required this.delay,
  });

  final delay;

  @override
  double lerp(double t) {
    return super.lerp((math.sin((t - delay) * 2 * math.pi) + 1) / 2);
  }

  @override
  double evaluate(Animation<double> animation) => lerp(animation.value);
}