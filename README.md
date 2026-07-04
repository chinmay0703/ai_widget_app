# Floating AI Assistant for macOS

A native macOS app that lives in your **menu bar**. Select text anywhere, press
**⌘⇧K**, and interact with an LLM using **your own OpenAI API key**. The
assistant popup appears right next to your cursor.

Built with Swift + SwiftUI + AppKit. Your API key is stored only on this Mac,
in the macOS Keychain, and is sent directly to OpenAI.

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

## Project structure

```
FloatingAI/
├── Package.swift              SwiftPM executable target
├── build.sh / run.sh          Assemble + ad-hoc sign the .app bundle
├── Resources/
│   ├── Info.plist             LSUIElement (accessory) app, bundle id, etc.
│   └── FloatingAI.entitlements  Sandbox off, apple-events on
└── Sources/FloatingAI/
    ├── App/                   Main entry, AppDelegate (menu bar + hotkey), AppState, window controllers
    ├── Popup/                 Popup panel/controller, ConversationViewModel, PopupView
    ├── Views/                 Welcome (onboarding), Settings, History, Markdown renderer
    ├── Services/              OpenAI, Clipboard, Accessibility, Keychain, HotKey, History
    ├── Models/                ChatMessage, PromptTemplate, HistoryItem, AppSettings, errors
    └── Utils/                 Constants, Logger, Notifications
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
