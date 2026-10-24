import 'package:flutter/services.dart';

class GateScreenSecurity {
  GateScreenSecurity() : owner = 'pin-${_next++}';
  static int _next = 0;
  final String owner;
  static const channel = MethodChannel('mimigo/security');
  Future<void> protect() => channel.invokeMethod<void>('secureScreen', {
    'owner': owner,
    'enabled': true,
  });
  Future<void> release() => channel.invokeMethod<void>('secureScreen', {
    'owner': owner,
    'enabled': false,
  });
}
