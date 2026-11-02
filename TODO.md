# WiFi Talkie — Improvement Plan

## Priority 1 — Bugs & Broken Behavior

- [ ] **1. Fix dead `_connecting` spinner (Flutter)**
  `home_screen.dart` — `_connecting` is never set to `true`, so the button
  never disables and the spinner never shows. Wire it up properly.

- [ ] **2. Fix "target left" crash on web**
  If the selected user disconnects, the web client keeps `selectedUser`
  pointing at a stale id. Clear selection on `userlist` when the target is
  gone.

## Priority 2 — UX Consistency

- [ ] **3. Unify receiving-state UX (web + Flutter)**
  Web PTT button says "Release to stop receiving" but does nothing on
  release. Flutter shows green mode but labels are unclear. Pick one model:
  *receiving = passive listen, no action needed* — update labels on both
  clients to match.

- [ ] **4. Improve audio unlock reliability (web)**
  Re-check AudioContext state before each playback attempt, not just on
  first tap. Handle iOS Safari edge cases where the context re-suspends
  after backgrounding.

## Priority 3 — Usability

- [ ] **5. Add keyboard PTT for desktop (web)**
  Let desktop users hold a key (e.g. Space) to talk instead of requiring
  mouse hold.

- [ ] **6. Better error messages**
  Show *why* a connection fails (wrong IP, port blocked, server not running)
  instead of generic "Target user unavailable" / "Connection failed."

- [ ] **7. Add connection feedback on Flutter home screen**
  Show server IP and port after hosting starts. In join mode, show a clear
  error if the server can't be reached.

## Priority 4 — Polish

- [ ] **8. Haptic/sound feedback on receiver side (Flutter)**
  Sender vibrates on PTT start; receiver should get a subtle vibration or
  tone so they know to listen.

- [ ] **9. QR code for easy LAN joining (web)**
  After server starts, show a QR code on the web UI (or terminal) encoding
  the `https://<ip>:<port>` URL so phone users can scan instead of typing.

- [ ] **10. Add basic tests**
  Unit tests for signaling message parsing (both Node and Flutter), and a
  widget test for the PTT button state machine.

---

*Check off items as we go. Working top-to-bottom.*
