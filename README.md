# CS Sign

A personal iOS app for signing PDFs with a hand-drawn signature. No accounts, no
server, no subscriptions: everything stays on the device.

- Import PDFs (Files, iCloud Drive, Dropbox… via the file picker or "Open in")
- Scan paper documents with the camera
- Draw signatures (finger or Apple Pencil, black or blue ink), or import a photo/scan of one
  from Photos or Files with automatic paper-background removal
- Sync signatures between devices through a folder you pick in Files (e.g. iCloud Drive/CS Sign);
  works with a free Apple ID because it needs no iCloud entitlement
- Place signatures, text, today's date and checkmarks; drag to move, pinch to resize, tap to select
- Save a flattened "(signed)" copy (stamps are burned into the page) and share it

Built with SwiftUI, PDFKit, PencilKit and VisionKit only. iOS 17+.

## Install (SideStore / AltStore)

CS Sign isn't on the App Store. Install it with [SideStore](https://sidestore.io) or
[AltStore](https://altstore.io) using your own free Apple ID:

1. In SideStore/AltStore, go to **Sources** and add this source URL:
   ```
   https://raw.githubusercontent.com/crazyquark/cs-sign-app/main/source.json
   ```
2. Open **CS Sign** from the source and tap **Install**. Updates appear there too.

Or download `CSSign.ipa` from the [latest release](https://github.com/crazyquark/cs-sign-app/releases/latest)
and sideload it with any tool you like.

Free Apple IDs allow 3 sideloaded apps at a time, and apps must be refreshed every 7 days
(SideStore does this automatically).

## Building on Linux with xtool

[xtool](https://github.com/xtool-org/xtool) builds SwiftPM iOS apps without Xcode.

One-time setup:

1. Install the Swift toolchain from <https://swift.org/install/linux> (the version xtool's docs ask for).
2. Install xtool:
   ```bash
   curl -fL "https://github.com/xtool-org/xtool/releases/latest/download/xtool-$(uname -m).AppImage" -o xtool
   chmod +x xtool && sudo mv xtool /usr/local/bin/
   ```
3. Download `Xcode.xip` in a browser from <https://developer.apple.com/download/all/?q=Xcode>
   (free Apple ID), then build the iOS SDK from it. This step does not need an Apple login:
   ```bash
   xtool sdk install ~/Downloads/Xcode_XX.xip
   swift sdk list   # should list "darwin"
   ```
   The .xip is several GB and extraction needs more on top, so make room first. Delete the .xip afterwards.

Build an unsigned .ipa:

```bash
xtool dev build --ipa
```

Then sideload the resulting `.ipa` with iLoader, which signs it with your Apple ID.
With a free Apple ID the install expires after 7 days; re-sign it to keep using the app.

Alternatively, `xtool setup` + `xtool dev` builds, signs and installs over USB in one step.

## Building on a Mac

Open `Package.swift` in Xcode, or use xtool on macOS the same way as above.

## Releasing

```bash
scripts/release.sh 1.0.1 "What's new in this version."
```

Builds the .ipa, bumps the version in `Info.plist`, creates the GitHub release and adds it
to `source.json`, which SideStore/AltStore users are subscribed to.
