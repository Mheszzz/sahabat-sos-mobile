import 'package:flutter/foundation.dart';

class GlobalEventBus {
  static final ValueNotifier<bool> refreshMap = ValueNotifier<bool>(false);
}