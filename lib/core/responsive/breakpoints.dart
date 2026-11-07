import 'package:flutter/widgets.dart';

class Breakpoints {
  const Breakpoints._();

  static const tablet = 720.0;

  static bool isTablet(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= tablet;
  }
}