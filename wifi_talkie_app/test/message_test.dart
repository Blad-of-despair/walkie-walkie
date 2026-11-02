import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_talkie/models/message.dart';
import 'package:wifi_talkie/models/user.dart';

void main() {
  group('Signaling Message Tests', () {
    test('createRegister creates correct map', () {
      final msg = createRegister('Alice');
      expect(msg['type'], 'register');
      expect(msg['nickname'], 'Alice');
      expect(getMessageType(msg), 'register');
    });

    test('createTalkingStart creates correct map', () {
      final msg = createTalkingStart('user123');
      expect(msg['type'], 'talking-start');
      expect(msg['target'], 'user123');
    });

    test('createTalkingStop creates correct map', () {
      final msg = createTalkingStop();
      expect(msg['type'], 'talking-stop');
    });
  });

  group('User Model Tests', () {
    test('User.fromJson parses correctly', () {
      final json = {'id': 'abc', 'nickname': 'Bob'};
      final user = User.fromJson(json);
      expect(user.id, 'abc');
      expect(user.nickname, 'Bob');
      expect(user.isTalking, false);
    });
  });
}
