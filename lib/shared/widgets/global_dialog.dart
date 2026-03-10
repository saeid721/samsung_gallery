
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'global_sized_box.dart';
import 'global_text.dart';
import 'theme_controller.dart';

class GlobalDialog extends StatefulWidget {
  final String title;
  final List<Widget> children;
  const GlobalDialog({
    super.key,
    required this.title,
    required this.children
  });

  @override
  State<GlobalDialog> createState() => _GlobalDialogState();
}

class _GlobalDialogState extends State<GlobalDialog> {

  final TextEditingController searchCon = TextEditingController();
  late ThemeController themeCtrl;

  @override
  void initState() {
    super.initState();
    themeCtrl = Get.find<ThemeController>();
  }

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
        builder: (ctx, buildSetState){
          return AlertDialog(
            backgroundColor: themeCtrl.lightDarkCardColor(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 15),
            content: SizedBox(
              width: Get.width,
              child: NotificationListener<OverscrollIndicatorNotification>(
                onNotification: (overScroll) {
                  overScroll.disallowIndicator();
                  return true;
                },
                child: SingleChildScrollView(
                    child: Column(
                      children: [

                        sizedBoxH(10),
                        SizedBox(
                          height: 20,
                          width: size(context).width,
                          child: Stack(
                            children: [
                              Center(
                                child: GlobalText(
                                  str: widget.title,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: themeCtrl.lightDarkTextColor(context),
                                ),
                              ),
                            ],
                          ),
                        ),

                        sizedBoxH(10),
                        Column(
                          children: widget.children,
                        )
                      ],
                    )
                ),
              ),
            ),
          );
        }
    );
  }
}