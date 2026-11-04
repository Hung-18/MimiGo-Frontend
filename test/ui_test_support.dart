import 'package:flutter_test/flutter_test.dart';
import 'package:mimigo_frontend/user_messages.dart';

/// Verify the retained diagnostic code without requiring it in primary copy.
Finder findErrorCode(String code) =>
    find.byWidgetPredicate((w) => w is UserError && w.failure?.code == code);
