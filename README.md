# CS Sign

A personal iOS app for signing PDFs with a hand-drawn signature. No accounts, no
server, no subscriptions: everything stays on the device.

- Import PDFs (Files, iCloud Drive, Dropbox… via the file picker or "Open in")
- Scan paper documents with the camera
- Draw and save signatures (finger or Apple Pencil, black or blue ink)
- Sync signatures between devices through a folder you pick in Files (e.g. iCloud Drive/CS Sign);
  works with a free Apple ID because it needs no iCloud entitlement
- Place signatures, text, today's date and checkmarks; drag to move, pinch to resize, tap to select
- Save a flattened "(signed)" copy (stamps are burned into the page) and share it

Built with SwiftUI, PDFKit, PencilKit and VisionKit only. iOS 17+.

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
