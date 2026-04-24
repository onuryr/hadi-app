import 'package:flutter_test/flutter_test.dart';
import 'package:hadi_app/screens/profile_screen.dart';

void main() {
  group('ProfileScreen', () {
    test('defaults to current user when userId is omitted', () {
      const screen = ProfileScreen();
      expect(screen.userId, isNull);
    });

    test('accepts a userId for viewing other users', () {
      const screen = ProfileScreen(userId: 'user-123');
      expect(screen.userId, 'user-123');
    });
  });
}
