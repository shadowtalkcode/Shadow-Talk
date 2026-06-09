import '../models/call_log.dart';
import '../models/chat.dart';
import '../models/enums.dart';
import '../models/message.dart';
import '../models/status_update.dart';
import '../models/user.dart';

/// Seed data for the offline/local chat demo, using the names/content from the
/// Shadow Talk XD design.
class MockData {
  MockData._();

  static const String img = 'assets/images';

  // ---- Users -------------------------------------------------------------
  static final me = User(
    uid: 'me',
    userName: 'Kugisaki Nobara',
    status: 'Available',
    phone: '+62 812 6666 6666',
    localPhoto: '$img/profile_pic.png',
  );

  static final team = User(
    uid: 'u_team',
    userName: 'Shadow Talk Team',
    status: 'Welcome User, know more about Shadow Talk',
    phone: '',
    localPhoto: '$img/splash_logo.png',
  );
  static final hugh = User(
    uid: 'u_hugh',
    userName: 'Hugh Saturation',
    status: 'Hello, I am an ui ux designer who has 2 years of experience and I am also an illustrator who has more than 2 years of experience.',
    phone: '+31 812 6666 6666',
    localPhoto: '$img/angelina.jpg',
  );
  static final gunther = User(
    uid: 'u_gunther',
    userName: 'Gunther Beard',
    status: 'Quisque blandit arcu quis turpis tincidunt facilisis',
    phone: '+31 812 1111 1111',
    localPhoto: '$img/taylor.jpg',
  );
  static final burgundy = User(
    uid: 'u_burgundy',
    userName: 'Burgundy Flemming',
    status: 'Sed ligula erat, dignissim sit at amet dictum id',
    phone: '+31 812 2222 2222',
    localPhoto: '$img/dua.jpg',
  );
  static final ingredia = User(
    uid: 'u_ingredia',
    userName: 'Ingredia Nutrisha',
    status: 'Curabitur elementum orci vitae turpis vulputate',
    phone: '+31 812 3333 3333',
    localPhoto: '$img/lady.png',
  );
  static final douglas = User(
    uid: 'u_douglas',
    userName: 'Douglas Lyphe',
    status: 'Donec ut lorem tristique dui sit faucibus tincidunt',
    phone: '+31 812 4444 4444',
    localPhoto: null,
  );
  static final group = User(
    uid: 'g_design',
    userName: 'Design Team',
    status: '5 members',
    phone: '',
    localPhoto: null,
    isGroup: true,
  );

  static List<User> get allContacts =>
      [hugh, gunther, burgundy, ingredia, douglas, group];

  // ---- Chats -------------------------------------------------------------
  static List<Chat> buildChats() {
    final now = DateTime.now();
    DateTime ago(int minutes) => now.subtract(Duration(minutes: minutes));

    return [
      Chat(
        chatId: 'c_team',
        user: team,
        unreadCount: 1,
        messages: [
          _m('t1', 'c_team', false, MessageKind.text,
              content: 'Welcome User, know more about Shadow Talk', t: ago(15)),
        ],
      ),
      Chat(
        chatId: 'c_hugh',
        user: hugh,
        unreadCount: 1,
        messages: [
          _m('h1', 'c_hugh', false, MessageKind.voice, t: ago(80), mediaDuration: '02:24'),
          _m('h2', 'c_hugh', true, MessageKind.text,
              content: "okay I went, and picked me up at 8 because if it's too late my skin hurts from the sun.",
              t: ago(74), status: MessageStatus.read),
          _m('h3', 'c_hugh', false, MessageKind.text,
              content: 'Okaaaay! see u later :D', t: ago(72)),
          _m('h4', 'c_hugh', true, MessageKind.text, content: '👋', t: ago(71)),
        ],
      ),
      Chat(
        chatId: 'c_gunther',
        user: gunther,
        unreadCount: 1,
        messages: [
          _m('g1', 'c_gunther', false, MessageKind.text,
              content: 'Quisque blandit arcu quis turpis tincidunt facilisis', t: ago(200)),
        ],
      ),
      Chat(
        chatId: 'c_burgundy',
        user: burgundy,
        unreadCount: 2,
        messages: [
          _m('b1', 'c_burgundy', false, MessageKind.text,
              content: 'Sed ligula erat, dignissim sit at amet dictum id', t: ago(320)),
        ],
      ),
      Chat(
        chatId: 'c_ingredia',
        user: ingredia,
        messages: [
          _m('i1', 'c_ingredia', false, MessageKind.text,
              content: 'Curabitur elementum orci vitae turpis vulputate', t: ago(600)),
        ],
      ),
      Chat(
        chatId: 'c_douglas',
        user: douglas,
        messages: [
          _m('d1', 'c_douglas', false, MessageKind.text,
              content: 'Donec ut lorem tristique dui sit faucibus tincidunt', t: ago(1500)),
        ],
      ),
      Chat(
        chatId: 'c_group',
        user: group,
        messages: [
          _m('gr1', 'c_group', false, MessageKind.text,
              content: 'Standup in 10 minutes everyone', t: ago(120)),
        ],
      ),
    ];
  }

  static Message _m(
    String id,
    String chatId,
    bool isSent,
    MessageKind kind, {
    String content = '',
    required DateTime t,
    MessageStatus status = MessageStatus.read,
    String? mediaDuration,
    String? fileSize,
    String? fileName,
    double? lat,
    double? lng,
    String? locationName,
  }) {
    return Message(
      messageId: id,
      chatId: chatId,
      isSent: isSent,
      kind: kind,
      content: content,
      timestamp: t,
      status: status,
      transferState: kind == MessageKind.text ? TransferState.none : TransferState.success,
      mediaDuration: mediaDuration,
      fileSize: fileSize,
      fileName: fileName,
      lat: lat,
      lng: lng,
      locationName: locationName,
    );
  }

  // ---- Calls -------------------------------------------------------------
  static List<CallLog> buildCalls() {
    final now = DateTime.now();
    return [
      CallLog(id: 'cl1', user: hugh, type: CallType.outgoing, isVideo: false, time: now.subtract(const Duration(minutes: 35))),
      CallLog(id: 'cl2', user: burgundy, type: CallType.incoming, isVideo: true, time: now.subtract(const Duration(hours: 3))),
      CallLog(id: 'cl3', user: douglas, type: CallType.missed, isVideo: false, time: now.subtract(const Duration(hours: 6))),
      CallLog(id: 'cl4', user: gunther, type: CallType.incoming, isVideo: false, time: now.subtract(const Duration(days: 1))),
      CallLog(id: 'cl5', user: ingredia, type: CallType.outgoing, isVideo: true, time: now.subtract(const Duration(days: 2))),
    ];
  }

  // ---- Tales / status ----------------------------------------------------
  static List<StatusUpdate> buildStatuses() {
    final now = DateTime.now();
    return [
      StatusUpdate(id: 's1', user: _tale('Wisteria', '$img/image2.png'), time: now.subtract(const Duration(minutes: 12)), imageAsset: '$img/image2.png'),
      StatusUpdate(id: 's2', user: _tale('Fleece', '$img/image3.png'), time: now.subtract(const Duration(minutes: 40)), imageAsset: '$img/image3.png'),
      StatusUpdate(id: 's3', user: _tale('Hilary', '$img/lady.png'), time: now.subtract(const Duration(hours: 1)), imageAsset: '$img/lady.png'),
      StatusUpdate(id: 's4', user: _tale('Parsley', '$img/taylor.jpg'), time: now.subtract(const Duration(hours: 2)), seen: true, imageAsset: '$img/taylor.jpg'),
      StatusUpdate(id: 's5', user: _tale('Brian', '$img/dua.jpg'), time: now.subtract(const Duration(hours: 4)), seen: true, imageAsset: '$img/dua.jpg'),
    ];
  }

  static User _tale(String name, String photo) =>
      User(uid: 'tale_$name', userName: name, localPhoto: photo);

  /// Canned replies the simulated peer sends back.
  static const List<String> autoReplies = [
    'Got it 👍',
    "Haha that's great!",
    'Sounds good to me',
    'Let me check and get back to you',
    'Sure thing!',
    'Really? Tell me more 😮',
    'Okaaaay! see u later :D',
    'On it 🚀',
  ];
}
