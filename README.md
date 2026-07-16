<div align="center">

<img src="assets/meta/icon.png" width="120" alt="白い熊の辞書 icon" />

# 白い熊の辞書

**An immersion language-learning suite: video player, audio-synced ebook reader, dictionary and Anki card factory in one app.**

A fork of [arianneorpilla/jidoujisho](https://github.com/arianneorpilla/jidoujisho) with **major additions**: five new languages, an audio-synced reader with SRT subtitles and Tasker control, a dual-language translation split view, per-book appearance settings, cross-device backup, and an e-ink-friendly UI.

Installs **side-by-side** with jidoujisho (app id `shiroikuma.jisho`).

**📥 Latest release: [`1.4.0+2`](https://github.com/ShiroiKuma0/shiroikumanojisho/releases/latest)** — [all releases & APK downloads »](https://github.com/ShiroiKuma0/shiroikumanojisho/releases)

</div>

---

## 🌍 Five more languages
German, Polish, Russian, Ukrainian and Czech added on top of upstream's Japanese and English — full dictionary lookup, reader and card-export support in each, with per-language TTU reader instances.

---

## 🎧 Audio-synced reading with external control
A reader audio toolbar plays an audiobook alongside the ebook, synced by SRT subtitles: seek by subtitle, replay, chapter navigation, condensed and auto-pause (shadowing) playback modes. Seven broadcast intents in the `shiroikuma.jisho.action.PLAYBACK_*` namespace let Tasker or any automation tool drive playback — next/previous/replay subtitle, play/pause, chapter navigation, mode cycling — without touching the screen. The toolbar's buttons are individually hideable so it fits narrow screens.

---

## 📖 Dual-language reader
Open a translation book in a split view next to the original and keep both in sight while reading. Per-book, per-pane appearance settings: writing mode (Japanese defaults to vertical), font size, font color, background, weight, margins and line spacing — every book remembers its own.

---

## 📺 Dual subtitles in the player
Show a secondary (translation) subtitle track on top of the primary one, with independent font, color, weight and vertical-position control for each. Keyboard playback control included.

---

## 🔁 Cross-device backup and restore
Everything — dictionaries, reading positions, books, preferences, browser bookmarks, mokuro catalogs — exports to a single portable ZIP bundle and imports on another device, surviving package re-signing. Audio paths remap automatically on the destination device.

---

## 🖥️ E-ink friendly
A yellow-on-black high-contrast theme, wrapping menus, and UI-fit work targeted at narrow e-ink devices (developed against a Boox Palma 2 Pro). EPUB import bypasses the in-webview file chooser that crashes Boox firmware.

---

## 📘 Dictionary upgrades
Every Japanese word in an entry is tappable for recursive lookup with clean back/close-all navigation; word-boundary detection on tap works in all supported languages; dictionaries can be edited, reordered and searched; font size adjusts live with an edge swipe (toggleable).

---

## Built on jidoujisho
A fork of [arianneorpilla/jidoujisho](https://github.com/arianneorpilla/jidoujisho) (app id `shiroikuma.jisho`, so it coexists with the official build). jidoujisho is a video player, reading aid, dictionary and card-creation toolkit built for language learners — this fork stands on that foundation and its excellent upstream ecosystem: ッツ Ebook Reader, Mokuro, Yomichan dictionaries, AnkiDroid export. The code remains under the [GNU General Public License 3.0](LICENSE).

## Building
```bash
git clone https://github.com/ShiroiKuma0/shiroikumanojisho.git
cd shiroikumanojisho
# Requires JDK 11 (Zulu) — Gradle 7.2 rejects JDK 17+.
export JAVA_HOME=/usr/lib/jvm/zulu11 && export PATH="$JAVA_HOME/bin:$PATH"
flutter build apk --split-per-abi --release
# APK: build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```
