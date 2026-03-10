
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'colors_resources.dart';
import 'global_sized_box.dart';
import 'global_text.dart';
import 'theme_controller.dart';

class GlobalAppbarWidget extends StatelessWidget {
  final String title;
  final List<Widget>? action;
  const GlobalAppbarWidget({
    super.key,
    required this.title,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 30, bottom: 10),
      color: ColorRes.black.withAlpha(50),
      child: Row(
        children: [
          GestureDetector(
            onTap: (){
              Get.back();
            },
            child: Container(
              color: Colors.transparent,
              height: 40,
              width: 30,
              child: const Center(
                child: Icon(
                  Icons.arrow_back_ios_new_outlined,
                  color: ColorRes.white,
                  size: 20,
                ),
              ),
            ),
          ),
          sizedBoxW(5),
          Expanded(
            child: GlobalText(
              str: title,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),

          action?.isNotEmpty ?? false ? Row(
            children: action ?? [],
          ) : const SizedBox.shrink()
        ],
      ),
    );
  }
}

class GlobalAppBar extends StatelessWidget {
  const GlobalAppBar({
    super.key,
    required this.title,
    this.isBackIc = true,
    this.centerTitle,
    this.titleColor,
    this.fontSize,
    this.fontWeight,
    this.backColor,
    this.notiOnTap,
    this.actions,
  });

  final String title;
  final Color? titleColor;
  final double? fontSize;
  final FontWeight? fontWeight;
  final Color? backColor;
  final bool? isBackIc;
  final bool? centerTitle;
  final Function()? notiOnTap;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ThemeController>(builder: (themeCtrl) {
      return AppBar(
        backgroundColor: backColor ?? themeCtrl.lightDarkAppBarColor(context),
        automaticallyImplyLeading: false,
        leadingWidth: isBackIc == true ? 56 : 0,
        leading: isBackIc == true
            ? IconButton(
          splashRadius: 0.1,
          icon: const Icon(Icons.arrow_back, color: ColorRes.white, size: 22),
          onPressed: () {
            Get.back();
          },
        )
            : const SizedBox.shrink(),
        centerTitle: centerTitle,
        title: GlobalText(
          str: title,
          color: titleColor ?? ColorRes.white,
          fontSize: fontSize ?? 16,
          fontWeight: fontWeight ?? FontWeight.w500,
          textAlign: TextAlign.center,
          fontFamily: 'Rubik',
        ),
        actions: actions,

        // actions: [
        //   ...actions ?? [],
        //   GestureDetector(
        //     onTap: (){
        //       themeCtrl.toggleTheme();
        //       Get.snackbar(
        //         'Theme',
        //         '',
        //         snackPosition: SnackPosition.BOTTOM,
        //         duration: const Duration(seconds: 2),
        //       );
        //     },
        //     child: Icon(Icons.dark_mode),
        //   ),
        //
        //   sizedBoxW(10)
        // ],
      );
    });
  }
}
