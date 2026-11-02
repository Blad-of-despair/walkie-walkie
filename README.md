# WiFi Talkie

Push-to-talk (PTT) voice chat over your local Wi‑Fi network. No internet
required for the actual audio — devices exchange sound peer‑to‑peer via
WebRTC, using a small WebSocket signaling server that only handles setup
messages.

Think walkie‑talkie, but over WiFi: open a channel, pick a contact, hold a
button to talk, release to let them listen.

---

## How it works

```
  Device A                          Device B
  ┌─────────────┐  hold-to-talk  ┌─────────────┐
  │ WebRTC mic  │ ─────────────► │ WebRTC audio│
  │  capture     │  (direct P2P  │  playback   │
  └──────┬───────┘   audio)      └──────▲───────┘
         │                              │
         │  signaling only             │
         ▼                              │
      ┌──────────────────────────────────┴───┐
      │   Node.js signaling server (WSS/WSS)  │
      │   - user list / presence               │
      │   - call offer / answer / ICE          │
      │   - "someone is talking" broadcasts    │
      └──────────────────────────────────────┘
```

- **Signaling** (WebSocket): registers users, relays SDP offers/answers and
  ICE candidates, and broadcasts "talk start/stop" events.
- **Audio** (WebRTC): once signaling is done, the mic stream flows directly
  between the two devices — it does not pass through the server.

---

## Repository layout

```
wifi-talkie/
├── server.js                 # Node.js HTTPS + WebSocket signaling server
├── public/
│   └── index.html            # Web client (vanilla JS, no build step)
├── wifi_talkie_app/          # Flutter app (mobile/desktop client)
│   ├── pubspec.yaml
│   └── lib/
│       ├── main.dart
│       ├── models/           # message.dart, user.dart
│       ├── screens/         # home_screen.dart, main_screen.dart
│       ├── services/        # signaling_client, signaling_server, webrtc_service
│       └── widgets/         # ptt_button.dart, user_tile.dart
├── cert.pem / key.pem        # self-signed TLS cert (auto-generated on first run)
└── package.json
```

> `node_modules/` is not committed (see `.gitignore`).

---

## Prerequisites

- **Node.js** ≥ 16 (for the signaling server)
- **Flutter** SDK ≥ 3.0 (only if you want the Flutter client)
- **A web browser** — Chrome/Edge recommended for the web client (full WebRTC support)

Both clients need microphone access and to be on the **same Wi‑Fi network**.

---

## Quick start (web client)

The web client needs no build step — it's a single `public/index.html`.

1. **Install dependencies**

   ```bash
   npm install
   ```

   This pulls in `ws` (WebSocket) and `selfsigned` (TLS cert generation).

2. **Run the server**

   ```bash
   node server.js
   ```

   On first run a self‑signed certificate is generated and saved to
   `key.pem` / `cert.pem`. The server then starts:

   ```
   WiFi Talkie Server
   ------------------------------------
   Local:   https://localhost:3000
   Network: https://192.168.x.x:3000

   HTTP (local):  http://localhost:3001
   ```

   - **HTTPS** (port 3000) is the main entry — required for WebRTC on LAN.
   - **HTTP** (port 3001) is a convenience for `localhost` only; any LAN host
     is redirected to HTTPS.

3. **Open the app**

   - On the machine running the server: `https://localhost:3000`
   - On any other device on the network: `https://<server-ip>:3000`
     (use the **Network** URL printed above).

   > ⚠ First visit shows a security warning (self‑signed cert).
   > Click **Advanced → Proceed to site**.

4. **Use it**

   1. Enter a nickname → **Join Channel**
   2. Tap a user in the *Online* list
   3. **Hold** the big button to talk, **release** to stop
   4. The recipient sees a *TALKING* badge and hears you in real time

   Two devices = you just built a two‑person walkie‑talkie. It scales to as
   many online users as you like; only one talks at a time.

### Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT`   | `3000`  | HTTPS base port. HTTP runs on `PORT + 1`. |

---

## Flutter app

A native mobile/desktop client in the same project. It can **run its own
signaling server** (host mode) or **connect to a remote one** (client mode).

From `wifi_talkie_app/`:

```bash
flutter pub get
flutter run
```

Key pieces:

- `lib/screens/home_screen.dart` — choose *Host* or *Connect*, set nickname/port.
- `lib/screens/main_screen.dart` — user list + PTT.
- `lib/services/signaling_server.dart` — in‑app WebSocket signaling server.
- `lib/services/signaling_client.dart` — connect to a remote signaling host.
- `lib/services/webrtc_service.dart` — `flutter_webrtc` audio streaming.
- `lib/widgets/ptt_button.dart` / `user_tile.dart` — UI building blocks.

The Flutter app targets the same protocol, so a Flutter device and the web
client can talk to each other through the same signaling server.

---

## Signaling protocol

JSON messages over WebSocket. Client → server:

| `type`           | Fields                            | Purpose                     |
|------------------|-----------------------------------|-----------------------------|
| `register`       | `nickname`                        | join the channel            |
| `call-offer`     | `target`, `sdp`                   | send WebRTC offer           |
| `call-answer`    | `target`, `sdp`                   | send WebRTC answer          |
| `ice-candidate`  | `target`, `candidate`             | exchange ICE candidate      |
| `talking-start`  | `target`                          | I started talking (PTT up)  |
| `talking-stop`   | —                                 | I stopped talking (PTT down)|

Server → client:

| `type`         | Fields                              | Purpose                       |
|----------------|-------------------------------------|-------------------------------|
| `registered`   | `id`                                | your assigned client id      |
| `userlist`     | `users: [{id, nickname}]`          | who's online                 |
| `call-offer`   | `from`, `fromNickname`, `sdp`      | incoming offer               |
| `call-answer`  | `from`, `sdp`                      | incoming answer              |
| `ice-candidate`| `from`, `candidate`                | incoming ICE candidate       |
| `talking-start`| `from`, `fromNickname`, `target`, `targetNickname` | presence cue |
| `talking-stop` | `from`                              | presence cue                 |
| `error`        | `message`                           | e.g. target unavailable      |

---

## Troubleshooting

- **Browser blocks audio** — tap *Enable Audio* the first time (autoplay
  policy). Subsequent playback works without the prompt.
- **"No one else is online"** — the other device must be on the same Wi‑Fi
  and have joined the channel. Firewalls that block port 3000 will prevent
  connections.
- **Audio is choppy** — make sure both devices have a good signal; WebRTC
  audio depends on P2P link quality. ICE servers (Google STUN) are used for
  connectivity.
- **Cert warning every time** — expected with a self‑signed cert. You can
  issue a real cert (e.g. via a LAN CA) and point the server at it by editing
  the key/cert paths in `server.js`.

---

## Notes

- The audio itself never touches the server — only control messages do.
- The web client is intentionally a single dependency‑free HTML file so it's
  easy to audit and host anywhere.
- For development the self‑signed cert is fine; don't reuse these
  `key.pem`/`cert.pem` for anything security‑sensitive.
