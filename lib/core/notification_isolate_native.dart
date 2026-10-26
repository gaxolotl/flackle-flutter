import 'dart:ui';

import 'package:flutter/widgets.dart';

/// Reads private notification input before the Flutter engine is fully up.
void ensureNotificationIsolateReady() {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
}
