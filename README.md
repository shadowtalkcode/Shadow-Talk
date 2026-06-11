# Shadow Talk — Flutter (iOS)

A Flutter port of the **Shadow Talk** Android messenger, targeting iOS. This
build reproduces the original app's **design** and implements the **chat
experience** end-to-end. Currency (BTC) transfer and real audio/video calling
are intentionally **not** implemented — those screens are present for design
completeness only.

## What's implemented

**Onboarding**
- Splash → Login selection → Profile setup ("Enter username") → Initializing → Main.

**Chat (fully functional, on local mock data)**
- Chat list with avatars, last-message preview, timestamps, unread badges,
  mute indicator and typing state.
- Conversation screen with the original bubble design (purple sent / dark
  received, cut-corner radii), date separators, and an animated typing bubble.
- Send **text**, plus **image / file / audio / voice / location / contact**
  messages via the attachment sheet.
- Message **status lifecycle** (pending → sent → delivered → read) with the
  simulated peer typing and auto-replying.
- **Reply / quote**, **copy**, **delete for me**, **delete for everyone**.
- Chat actions: **mute**, **clear chat**, **delete chat**.
- **Search** across chats and message text.
- New chat from the contact picker; contact / group details screen.

**Other tabs (design only)**
- **Calls** — call-history list (no real calling).
- **BTC** — wallet design with an explicit "not available in this build" notice.
- **Settings** — profile header + settings rows, profile screen, status screen.

## Architecture

- **No backend.** The original uses Firebase + Realm + Agora; this port runs on
  in-memory mock data so the chat works without any server.
- **State:** a singleton `ChatRepository extends ChangeNotifier`
  (`lib/data/chat_repository.dart`); the UI rebuilds via `ListenableBuilder`
  (no third-party state-management dependency).
- **Models** (`lib/models/`) mirror the Android Realm models — `Message`
  (with `MessageKind` / `MessageStatus`), `Chat`, `User`, `CallLog`,
  `StatusUpdate`.
- **Theme** (`lib/theme/`) ports `colors.xml` 1:1 and uses the original
  Open Sans / Inter fonts.

```
lib/
  main.dart
  theme/            app_colors.dart, app_theme.dart
  models/           enums, user, message, chat, call_log, status_update
  data/             mock_data.dart, chat_repository.dart
  utils/            time_format.dart
  widgets/          avatar, chat_list_item, message_bubble, chat_input_bar,
                    attachment_sheet, date_separator, typing_indicator
  screens/
    splash_screen.dart
    onboarding/     login_selection, enter_username, setup_user
    main_screen.dart
    chats/          chats_tab, chat_screen, new_chat_screen, contact_details_screen
    calls/          calls_tab
    status/         status_tab
    btc/            btc_tab
    settings/       settings_tab, profile_screen
```

## Running

```bash
flutter pub get
# The repo path contains a space, which breaks CocoaPods' default ASCII locale:
cd ios && LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 pod install && cd ..
flutter run -d <ios-simulator-id>
```
