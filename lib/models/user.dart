/// A contact / chat participant. Ported from Android `User` (Realm) model,
/// keeping the fields relevant to chat UI.
class User {
  final String uid;
  String userName;
  String status; // "about" text
  String phone;
  String? localPhoto; // asset/file path used as avatar in this port
  String? photoUrl; // uploaded profile photo (network URL), if any
  bool isGroup;
  bool isBlocked;
  bool isStoredInContacts;

  User({
    required this.uid,
    required this.userName,
    this.status = 'Hey there! I am using Shadow Talk.',
    this.phone = '',
    this.localPhoto,
    this.photoUrl,
    this.isGroup = false,
    this.isBlocked = false,
    this.isStoredInContacts = true,
  });
}
