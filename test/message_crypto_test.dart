import 'package:chat_app/features/chat/data/message_crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('two devices can encrypt and decrypt a message', () async {
    SharedPreferences.setMockInitialValues({});
    final alice = MessageCrypto(await SharedPreferences.getInstance());
    final alicePublic = await alice.localPublicKey();

    SharedPreferences.setMockInitialValues({});
    final bob = MessageCrypto(await SharedPreferences.getInstance());
    final bobPublic = await bob.localPublicKey();

    expect(alicePublic, isNot(bobPublic));

    final sealed = await alice.encrypt(
      plaintext: 'secret hello',
      peerPublicKey: bobPublic,
    );
    expect(MessageCrypto.isEncrypted(sealed), isTrue);
    expect(sealed, isNot(contains('secret hello')));

    final opened = await bob.decrypt(
      ciphertext: sealed,
      peerPublicKey: alicePublic,
    );
    expect(opened, 'secret hello');
  });
}
