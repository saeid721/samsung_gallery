
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';

import 'colors_resources.dart';
import 'theme_controller.dart';

class GlobalText extends StatelessWidget {
  final String str;
  final FontWeight? fontWeight;
  final double? fontSize;
  final Color? color;
  final FontStyle? fontStyle;
  final double? letterSpacing;
  final TextDecoration? decoration;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool? softWrap;
  final double? height;
  final String? fontFamily;

  const GlobalText({
    super.key,
    required this.str,
    this.fontWeight,
    this.fontSize,
    this.fontStyle,
    this.color,
    this.letterSpacing,
    this.decoration,
    this.maxLines,
    this.textAlign,
    this.overflow,
    this.softWrap,
    this.height,
    this.fontFamily,
  });

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final h = height ?? .08;
    final fw = fontSize ?? 14;
    final double fontHeight = h * fw;

    return Text(
      str,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      softWrap: softWrap,
      // style: GoogleFonts.roboto(
      //   color: color ?? themeController.lightDarkTextColor(context),
      //   fontSize: fontSize,
      //   fontWeight: fontWeight,
      //   letterSpacing: letterSpacing,
      //   decoration: decoration,
      //   height: height == null ? null : fontHeight,
      //   fontStyle: fontStyle,
      // ),
    );
  }
}

class ExpandableDescription extends StatefulWidget {
  final String description;
  final int maxLines;
  const ExpandableDescription({
    super.key,
    required this.description,
    this.maxLines = 3,
  });

  @override
  State<ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<ExpandableDescription> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlobalText(
          str: widget.description,
          maxLines: isExpanded ? null : widget.maxLines,
          overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
          fontSize: 11,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () {
              setState(() {
                isExpanded = !isExpanded;  // Toggle between expanded and collapsed
              });
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 5),
              child: GlobalText(
                str: isExpanded ? "See Less" : "See More",
                color: ColorRes.appRedColor,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

