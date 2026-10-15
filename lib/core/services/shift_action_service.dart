import 'package:flutter/foundation.dart';

class ShiftActionService {
  ShiftActionService._();

  static final ValueNotifier<int> punchOutRequests = ValueNotifier<int>(0);
  static bool _pendingPunchOut = false;

  static void requestPunchOut() {
    _pendingPunchOut = true;
    punchOutRequests.value++;
  }

  static bool consumePendingPunchOut() {
    if (!_pendingPunchOut) return false;
    _pendingPunchOut = false;
    return true;
  }
}
