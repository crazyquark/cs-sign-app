# Plain Sign

A personal iOS app for signing PDFs with a hand-drawn signature. No accounts, no
server, no subscriptions: everything stays on the device.

- Import PDFs (Files, iCloud Drive, Dropbox… via the file picker or "Open in")
- Scan paper documents with the camera
- Draw signatures (finger or Apple Pencil, black or blue ink), or import a photo/scan of one
  from Photos or Files with automatic paper-background removal
- Sync signatures between devices through a folder you pick in Files (e.g. iCloud Drive/Plain Sign);
  works with a free Apple ID because it needs no iCloud entitlement
- Place signatures, text, today's date and checkmarks; drag to move, pinch to resize, tap to select
- Save a flattened "(signed)" copy (stamps are burned into the page) and share it

Built with SwiftUI, PDFKit, PencilKit and VisionKit only. iOS 17+.

## Install (SideStore / AltStore)

Plain Sign isn't on the App Store. Install it with [SideStore](https://sidestore.io) or
[AltStore](https://altstore.io) using your own free Apple ID:

1. In SideStore/AltStore, go to **Sources** and add this source URL:
   ```
   https://raw.githubusercontent.com/crazyquark/plain-sign/main/source.json
   ```
2. Open **Plain Sign** from the source and tap **Install**. Updates appear there too.

Or download `PlainSign.ipa` from the [latest release](https://github.com/crazyquark/plain-sign/releases/latest)
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

## App Store / TestFlight (GitHub Actions)

`.github/workflows/app-store.yml` builds the app with Xcode on a GitHub macOS runner
(free for public repos). The Xcode project is generated from `project.yml` by
`scripts/xcode-prepare.sh`; it uses the same sources and `Info.plist` as xtool.

- **TestFlight:** runs on every `v*` tag (so `scripts/release.sh` triggers it) or by hand
  from the Actions tab. It archives the app, signs it with Xcode cloud signing and uploads
  it to App Store Connect. Build numbers get the run number appended (`3` → `3.57`).
- **Screenshots:** run the workflow by hand with *Take App Store screenshots* checked.
  It captures iPhone 6.9" and iPad 13" screenshots (the sizes App Store Connect requires)
  using the app's demo mode (`-PSScreenshot library|editor|signatures`) and attaches them
  as the `app-store-screenshots` artifact.

One-time setup:

1. App Store Connect → Users and Access → Integrations → **Team Keys**: create a key with
   the **Admin** role (App Manager is not enough: uploading uses cloud-managed
   distribution signing, which needs Admin). Download the `.p8` file (only possible once) and note the
   key ID and issuer ID.
2. App Store Connect → Apps → **+ New App**, bundle ID `io.github.crazyquark.plainsign`.
3. GitHub → Settings → Secrets and variables → Actions → add `ASC_KEY_ID`,
   `ASC_ISSUER_ID`, `ASC_KEY_P8` (the file's contents) and `APPLE_TEAM_ID`.

Until the secrets exist, the TestFlight job only checks that the app builds.

## Releasing

```bash
scripts/release.sh 1.0.1 "What's new in this version."
```

Builds the .ipa, bumps the version in `Info.plist`, creates the GitHub release and adds it
to `source.json`, which SideStore/AltStore users are subscribed to.

## License

MIT. See [LICENSE](LICENSE).
