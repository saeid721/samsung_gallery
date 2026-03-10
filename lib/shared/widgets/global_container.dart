import 'package:flutter/material.dart';

class GlobalContainer extends StatelessWidget {
  final double borderRadiusCircular;
  final BorderRadiusGeometry? borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Widget? child;
  final Color color;
  final double? width;
  final double? height;

  const GlobalContainer({
    super.key,
    this.borderRadiusCircular = 0.0,
    this.padding = const EdgeInsets.all(0),
    this.margin = const EdgeInsets.all(0),
    this.child,
    this.width,
    this.height,
    this.color = Colors.white,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius ?? BorderRadius.circular(borderRadiusCircular),
      ),
      child: child,
    );
  }
}
