# Floating AI Assistant for macOS

A native macOS app that lives in your **menu bar**. Select text anywhere, press
**⌘⇧K**, and interact with an LLM using **your own OpenAI API key**. The
assistant popup appears right next to your cursor.

Built with Swift + SwiftUI + AppKit. Your API key is stored only on this Mac,
in the macOS Keychain, and is sent directly to OpenAI.

**🌐 Website & download:** https://chinmay0703.github.io/ai_widget_app/
&nbsp;·&nbsp; **⬇︎ Direct DMG:** [FloatingAI.dmg](https://github.com/chinmay0703/ai_widget_app/raw/main/FloatingAI.dmg)

---

## Features

- 🧠 **Menu-bar app** — a stable `NSStatusItem` (✦) with Open Assistant /
  Settings / History / Quit. No Dock icon, no fragile floating panel.
- ⌘⇧K **Global shortcut** — opens the assistant from any app (Carbon hotkey);
  the popup appears next to your cursor.
- ✂️ **Selection capture** — copies your current selection (synthetic ⌘C), reads
  it, and restores your previous clipboard.
- ⚡ **Quick actions** — Explain, Summarize, Rewrite, Fix Grammar, Translate,
  Improve Tone — plus any custom prompt.
- 🌊 **Streaming responses** over the OpenAI **Responses API** (`/v1/responses`).
- 📝 **Markdown rendering** of responses (headings, lists, code, quotes, bold/italic).
- 💬 **Continue chat** — follow-up turns in the same popup.
- 📋 **Copy / Replace / Insert** — put the response on the clipboard, or paste it
  back into the original app (synthetic ⌘V).
- 🔐 **Keychain-backed** API key, validated on entry.
- 🕘 **History** of past interactions, stored locally.
- ⚙️ **Settings** — model picker (or custom model id), system prompt,
  temperature, streaming, clipboard-restore, and hotkey toggles.

---

## Requirements

- macOS 13 (Ventura) or later
- **Swift toolchain** — the Xcode Command Line Tools are enough
  (`xcode-select --install`); full Xcode is **not** required.
- An OpenAI API key (`sk-…`).

---

## Build & Run

```bash
# Build a signed .app bundle into ./build and launch it
./run.sh

# Or build only (release), without launching
./build.sh release

# Or use SwiftPM directly for a plain executable (no bundle)
swift build
```

`build.sh` compiles with Swift Package Manager, hand-assembles
`build/FloatingAI.app`, and **ad-hoc code-signs** it. Ad-hoc signing gives the
app a stable identity so macOS can remember its Accessibility permission.

> First run shows an onboarding flow: enter & validate your API key, then grant
> Accessibility permission. After that the ✦ menu-bar icon appears on the right
> edge of your screen.

## Create the shareable DMG

To produce a distributable disk image (what you send to other people):

```bash
./package.sh
```

This:

- builds a **universal binary** (`arm64` + `x86_64`), so it runs on both Apple
  Silicon and Intel Macs (the Intel slice is built via Rosetta — no full Xcode
  needed),
- assembles and **ad-hoc signs** `FloatingAI.app`,
- writes **`FloatingAI.dmg`** to the repo root — a drag-to-Applications
  installer that bundles the app + `HOW-TO-OPEN.txt`.

A prebuilt **`FloatingAI.dmg`** is checked into this repo so you can grab it
without building.

**Installing the DMG (you or anyone you share it with):**

1. Open `FloatingAI.dmg` → drag **FloatingAI.app** onto **Applications**.
2. It isn't notarized by Apple, so the first launch is blocked — go to
   **System Settings → Privacy & Security → Open Anyway**, or run:
   `xattr -dr com.apple.quarantine /Applications/FloatingAI.app`
3. Enter your OpenAI key → grant Accessibility once → press **⌘⇧K**.

---

## Permissions

This app is intentionally **not sandboxed**. Reading another app's selection and
pasting responses back requires injecting ⌘C / ⌘V into the frontmost app, which
the App Sandbox forbids for third-party apps. Instead the app asks for
**Accessibility** permission:

**System Settings → Privacy & Security → Accessibility → enable Floating AI.**

If you rebuild and move the `.app`, macOS may ask you to re-grant this (the
ad-hoc signature is tied to the binary). Toggle it off/on in that pane.

---

## How it works

```
   Select text in any app
            │
   Press ⌘⇧K  (or menu bar ✦ → Open Assistant)
            │
   AppDelegate.trigger()
            │
   ClipboardService  ── synthetic ⌘C → read selection → restore clipboard
            │
   PopupController → ConversationViewModel   (popup opens next to cursor)
            │
   OpenAIService  ── POST /v1/responses (streaming SSE)
            │
   PopupView  ── Markdown render → Copy / Replace / Insert (synthetic ⌘V)
```

The ⌘⇧K hotkey fires without activating the app, so the synthetic ⌘C still
copies the *frontmost* app's selection. The app that was frontmost at trigger
time is remembered so Replace/Insert can paste back into it. All SwiftUI views
are hosted via `NSHostingController` (not raw `NSHostingView` content views),
which avoids an AppKit constraint-update crash on display/safe-area changes
(e.g. sleep/wake).

---

## Architecture

Floating AI is a single native macOS app, but it is organized as a set of
small, **single-responsibility service modules** rather than a monolith. Each
service owns exactly one system concern and exposes a narrow, testable API, so
any piece can be reasoned about, swapped, or mocked in isolation. Layers only
depend downward (UI → Services → Models); nothing reaches back up.

### Layered overview

```
┌──────────────────────────────────────────────────────────────────┐
│  App / Orchestration                                               │
│    Main → AppDelegate  (menu-bar item, ⌘⇧K hotkey, trigger flow)   │
│    AppState            (observable app-wide state; injected into UI)│
├──────────────────────────────────────────────────────────────────┤
│  UI  (SwiftUI hosted in AppKit windows/panels)                     │
│    PopupView · WelcomeView · SettingsView · HistoryView            │
│    AccessibilityView · MarkdownView                                │
│    ConversationViewModel  (per-popup session: streaming, actions)  │
├──────────────────────────────────────────────────────────────────┤
│  Services  (one module per external concern — the "microservices") │
│    OpenAIService · ClipboardService · AccessibilityService         │
│    KeychainService · HotKeyManager · HistoryStore                  │
├──────────────────────────────────────────────────────────────────┤
│  Models  (plain Codable value types, no behavior)                  │
│    ChatMessage · PromptTemplate · AppSettings · HistoryItem · …    │
└──────────────────────────────────────────────────────────────────┘
```

### Service modules

Each is independent and replaceable — the app wires them together but they have
no knowledge of each other.

| Service | Single responsibility | Backed by |
|---|---|---|
| `OpenAIService` | Build, send, and **stream** requests to the OpenAI Responses API (`/v1/responses`); validate the key | `URLSession` |
| `ClipboardService` | Synthetic ⌘C / ⌘V, snapshot & restore the user's pasteboard | CoreGraphics `CGEvent` |
| `AccessibilityService` | Check / prompt `AXIsProcessTrusted`, open the Settings pane | ApplicationServices |
| `KeychainService` | Store / read / delete the API key locally | Security framework |
| `HotKeyManager` | Register the ⌘⇧K system-wide hotkey | Carbon `RegisterEventHotKey` |
| `HistoryStore` | Persist interaction history as JSON in Application Support | Filesystem |

### Runtime flow

`AppDelegate.trigger()` is the single orchestration point. On ⌘⇧K (or menu-bar →
Open Assistant) it: captures the selection via `ClipboardService`, records the
frontmost app, and presents a `PopupController`. That popup owns a
`ConversationViewModel`, which calls `OpenAIService` and streams tokens into the
SwiftUI `PopupView`. Copy / Replace / Insert route back through
`ClipboardService` into the remembered app. See **How it works** above for the
diagram.

### Key design decisions

- **Not sandboxed + Accessibility** — injecting ⌘C/⌘V into other apps is
  forbidden inside the App Sandbox, so the app runs unsandboxed and gates on the
  user's Accessibility grant.
- **Fixed-size popup** — an earlier dynamically-sized popup caused a runaway
  AppKit *update-constraints* loop that crashed the app; the popup is now a fixed
  size with an internal scroll view. (A `--selftest N` mode stress-tests the
  windows; it validated 1200+ open/close cycles with zero crashes.)
- **`NSHostingController` hosting** — SwiftUI is hosted via controllers, not raw
  `NSHostingView` content views, to avoid constraint-update crashes on
  display / sleep-wake changes.
- **Bring-your-own key in the Keychain** — the key never leaves the Mac except
  in direct calls to OpenAI; nothing is proxied through a server.
- **SwiftPM + ad-hoc bundling** — builds with only the Command Line Tools (no
  full Xcode). Ad-hoc signing means each rebuild is a new identity, so macOS may
  ask you to re-grant Accessibility after a rebuild.

## Project structure

```
ai_widget_app/
├── Package.swift               SwiftPM executable target (macOS 13+)
├── build.sh                    Build + assemble + ad-hoc sign build/FloatingAI.app
├── run.sh                      build.sh, then relaunch the app
├── package.sh                  Universal (arm64+x86_64) build → FloatingAI.dmg
├── FloatingAI.dmg              Prebuilt, ready-to-share installer
├── Resources/
│   ├── Info.plist              LSUIElement (accessory) app, bundle id, version
│   └── FloatingAI.entitlements Sandbox off, apple-events on
└── Sources/FloatingAI/
    ├── App/
    │   ├── Main.swift               @main entry (+ hidden --selftest mode)
    │   ├── AppDelegate.swift        Menu-bar item, hotkey, trigger orchestration
    │   ├── AppState.swift           Observable app-wide state
    │   ├── WindowControllers.swift  Onboarding / Settings / Accessibility windows
    │   └── SelfTest.swift           Window stress-test harness (--selftest)
    ├── Popup/
    │   ├── PopupController.swift     Presents the popup near the cursor
    │   ├── PopupPanel.swift          NSPanel (key-capable, Esc to close)
    │   ├── PopupView.swift           The assistant UI (SwiftUI)
    │   └── ConversationViewModel.swift  Streaming, chat, Copy/Replace/Insert
    ├── Views/
    │   ├── WelcomeView.swift         First-run onboarding
    │   ├── SettingsView.swift        General / History / About tabs
    │   ├── HistoryView.swift         Past interactions
    │   ├── AccessibilityView.swift   "Enable Accessibility → Restart" flow
    │   └── MarkdownView.swift        Lightweight Markdown renderer
    ├── Services/                     OpenAI, Clipboard, Accessibility,
    │                                 Keychain, HotKey, History
    ├── Models/                       ChatMessage, PromptTemplate, HistoryItem,
    │                                 AppSettings, OpenAIModels, AppError
    └── Utils/                        Constants, Logger, Notifications
```

---

## Troubleshooting

- **Nothing is captured / Replace does nothing** — Accessibility permission is
  missing or was invalidated after a rebuild. Re-enable it in System Settings.
- **⌘⇧K does nothing** — another app may own that shortcut, or the hotkey is
  disabled in Settings. Toggle it in Settings → General, or use the menu bar ✦.
- **401 from OpenAI** — the key is wrong or lacks access to the selected model.
  Update it in Settings → General.
- **Menu-bar icon missing** — the app may not be running; relaunch it. It has no
  Dock icon by design.

---

## Roadmap (from the design doc)

Implemented: streaming, markdown, multiple models, keychain, history, quick
actions, continue-chat.

Not yet: OCR / screenshot capture, launch-at-login, a plugin architecture for
other providers, and a custom app icon (`Resources/AppIcon.icns` is picked up
automatically if you add one).
