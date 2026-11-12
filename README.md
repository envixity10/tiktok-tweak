# TikSpice

TikSpice is a personal TikTok tweak: themes, playback, and feed chrome, with an in-app settings panel. It is meant for a decrypted IPA you sideload on your own device.

The settings UI is a searchable, inset-grouped sheet. Private TikTok class and selector names live in one table, `src/HookRegistry.m`. A row is hooked only when that class implements the selector itself and the return type matches, so a stale name is skipped instead of crashing.

## Open settings

- Tap the sparkle button (drag it; it snaps to the left or right edge).
- Long-press the sparkle for save, copy URL, hook status, or hide.
- Shake the phone.
- On a settings or profile screen whose class is listed in the registry, a sparkle is added to the navigation bar.

Hiding the sparkle requires Shake to stay on, so there is still a way back in. Preferences are stored with `NSUserDefaults` suite `com.tikspice.preferences` inside the app container.

## Features

| Feature | Mechanism | In this tree |
| --- | --- | --- |
| Settings sheet, search, haptics, presets | UIKit | Ready |
| Accent, surfaces, text, corner radius | Theme model | Ready |
| Presets: Spice, AMOLED, Midnight, Ocean, Sunset, Pastel, Clean, Custom | Built in | Ready |
| Import, export, and paste theme JSON | File and pasteboard | Ready |
| Color tab and nav bars | `UINavigationBar` / `UITabBar` appearance | Ready, off by default |
| Tint icons and switches | Window tint | Ready, off by default |
| Recolor list backgrounds | View walk, skips player layers | Experimental, off by default |
| Playback speed 0.5×–3× | `AVPlayer` `setRate:` / `play` | Ready |
| Loop current video | Seek to start when the item ends | Ready |
| Stay on the current video | Swallow one full-page animated scroll after the video ends, and zero-argument advance methods when they match | Scroll swallow is best-effort; private methods need your build |
| Confirm like, follow, share, comment | Button label and class-name checks | Heuristic |
| Disable double-tap like | Cancel double-taps on large views | Heuristic |
| Hide ads, LIVE, Shop, upload, Friends, Inbox, stories, music, counts, share | Short labels plus class-name fragments | Heuristic. Huge views are never hidden |
| Hide tab labels | Clear `UITabBarItem` titles, icons stay | Ready |
| Quiet feed / show feed chrome | Sets the hide toggles together | Ready |
| Save the playing video | `AVAssetExportSession`, then Photos | Ready. The file is whatever the player loaded, often the copy without a download watermark |
| Copy playback URL | `AVURLAsset` URL | Ready when the asset exposes one |
| Prefer playback URL for TikTok's own download getter | `downloadAddr` / `downloadURL` swapped for the play address when both exist and return the same class | Needs your build |
| Region code override | String getters such as `currentRegion` | Needs your build. Only replaces an `NSString` |
| Hook status and recent screen names | Runtime class list | Ready. Use this to update the registry |

Everything that changes TikTok's chrome is off until you turn it on. The floating button, shake, and haptics start on.

## Theme JSON

```json
{
  "format": "tikspice-theme",
  "version": 1,
  "name": "AMOLED",
  "accent": "#FF375F",
  "background": "#000000",
  "surface": "#000000",
  "surfaceElevated": "#0C0C0C",
  "textPrimary": "#F5F5F7",
  "textSecondary": "#8D8D93",
  "separator": "#1A1A1A",
  "destructive": "#FF453A",
  "cornerRadius": 18
}
```

Hex colors accept `#RGB`, `#RGBA`, `#RRGGBB`, and `#RRGGBBAA`. A file can contain a single color; missing keys keep the Spice preset. `format` may be omitted. If it is present it must be `tikspice-theme`.

## Project layout

| Path | Role |
| --- | --- |
| `Makefile`, `control`, `TikSpice.plist` | Theos package. Rootless (`/var/jb`), arm64, iOS 15+ |
| `src/SettingsUI.m` | Settings and hook-status UI |
| `src/Theme.m` | Presets and JSON |
| `src/HookRegistry.m` | Private class and selector table |
| `src/PrivateHooks.xm` | Installs registry rows that match this process |
| `src/Scanner.m` | Label and class-name hiding rules |
| `src/Playback.xm`, `src/PlaybackGate.m` | `AVPlayer` speed, loop, auto-advance window |
| `src/Interface.xm` | Confirmations, tab labels, shake, screen log |
| `src/Floater.m` | Sparkle button |
| `scripts/install-theos.sh` | Linux Theos + iOS 16.5 SDK |
| `scripts/inject-ipa.sh` | cyan injection |
| `.github/workflows/build.yml` | Push build, and IPA injection on dispatch |
| `packaging/PhotoUsage.plist` | Merged into the IPA so Photos can be written |

The substrate filter plist covers:

- `com.zhiliaoapp.musically`
- `com.ss.iphone.ugc.Ame`
- `com.ss.iphone.ugc.Aweme`
- `com.ss.iphone.ugc.Trill`

Sideload injection does not depend on that filter. cyan adds a load command, so the tweak loads in the patched IPA even if you override the bundle id. The filter matters for a jailbreak install of the `.deb`.

## Build locally

Linux (same path CI uses):

```bash
export THEOS="$HOME/theos"
./scripts/install-theos.sh
make package FINALPACKAGE=1
```

The package is `packages/com.tikspice.tweak_1.0.0_iphoneos-arm64.deb`. The dylib is staged at `var/jb/Library/MobileSubstrate/DynamicLibraries/TikSpice.dylib`.

On a Mac with Theos and an iOS SDK already installed, export `THEOS` and run the same `make` command. `scripts/install-theos.sh` is the Linux toolchain only.

`THEOS_PACKAGE_SCHEME` defaults to `rootless`. Override it in the environment if you need a different layout.

## GitHub Actions

`.github/workflows/build.yml` has two jobs.

**Build tweak** runs on every push and pull request. It installs Theos on `ubuntu-latest`, runs `make package`, and uploads the `.deb` and `TikSpice.dylib` as the `TikSpice-deb` artifact (kept 5 days).

**Inject into IPA** runs only for a manual dispatch. In the Actions tab, open **Build**, choose **Run workflow**, and set:

| Input | Required | Effect |
| --- | --- | --- |
| `ipa_url` | Yes | Direct URL of a decrypted IPA you own |
| `display_name` | No | Passed to cyan `-n` |
| `bundle_id` | No | Passed to cyan `-b` |

The inject job downloads that IPA, runs `scripts/inject-ipa.sh` (cyan / pyzule-rw), merges `packaging/PhotoUsage.plist`, fakesigns, thins to arm64, and uploads `TikSpice-patched.ipa` as the `TikSpice-patched-ipa` artifact (kept 3 days).

The workflow does not create a release and does not upload the IPA anywhere except that Actions artifact. `*.ipa` is gitignored. The push job fails if an IPA is committed.

The URL is visible to people who can open the Actions run. Use a private repo and a short-lived URL. The file has to already be decrypted: cyan rejects a FairPlay-encrypted main binary, and this workflow does not override that check.

After the artifact downloads, re-sign it with your own certificate (Sideloadly, AltStore, or Feather) before installing. TrollStore can install the fakesigned IPA directly. Re-signing replaces the fakesign.

## Update hooks for a new TikTok build

Class names cannot be checked in this repo because the app binary is not here. The hook status screen is the check on device.

1. Install a patched IPA, open a video, the profile, and settings.
2. Open TikSpice → Advanced → Hook status. Refresh.
3. **This process** shows how many registry classes exist. **Recent screens** lists view controller classes that appeared (UIKit classes are omitted). Tap a row to copy it.
4. Edit `src/HookRegistry.m`. Each row is a `TSHookSpec`:

| Field | Meaning |
| --- | --- |
| `ident` | Stable id, unique in the table |
| `group` | `ads`, `feed`, `video`, `region`, `live`, `shop`, `upload`, `story`, `music`, `settings`, `profile`, `interaction`, `player` |
| `className` | Exact Objective-C class |
| `selector` | Instance method with no extra arguments, or `NULL` for a probe |
| `swapSelector` | Play-address getter for `TSHookKindSwapPlay` |
| `prefKey` | Preference string from `src/TSKeys.m`, or `NULL` |
| `purpose` | Shown in Hook status |
| `returnType` | `'B'` bool, `'v'` void, `'@'` object, or `0` for a probe |
| `kind` | See below |
| `unverified` | `1` until you have confirmed it on a build |

Kinds:

- `TSHookKindProbe` — report whether the class exists. The scanner also hides views whose class equals a `live`, `shop`, `upload`, `story`, or `music` entry when that toggle is on.
- `TSHookKindBoolNO` — while the preference is on, return `NO`.
- `TSHookKindVoidSkip` — while the preference is on, skip the method. Zero arguments only. An animated variant such as `scrollToNextVideoAnimated:` needs its own trampoline once you know the signature.
- `TSHookKindRegion` — if the original return value is an `NSString` and a region code is set, return the code.
- `TSHookKindSwapPlay` — return the swap selector's object when it is the same class as the original.

The loader uses `class_copyMethodList`, so an inherited method is not replaced. A bool encoded as `B` or `c` is accepted. Anything else is left alone and shown as a mismatch in Hook status.

Label hiding that does not need a private method goes in the `kRules` table at the top of `src/Scanner.m`. Text matches are limited to short labels. Views larger than most of the screen are not hidden.

Turn on **Log view controllers** if you want each screen class in the device log as well.

## Install the package

Jailbreak (rootless, ElleKit or an equivalent substrate): install the `.deb`.

Sideload: use the patched IPA from the dispatch workflow, or inject the `.deb` yourself:

```bash
./scripts/inject-ipa.sh \
  --input YourApp.ipa \
  --tweak packages/com.tikspice.tweak_1.0.0_iphoneos-arm64.deb \
  --output TikSpice-patched.ipa \
  --plist packaging/PhotoUsage.plist
```

cyan has to be on `PATH` (`pipx install --force https://github.com/asdfzxcvbn/pyzule-rw/archive/main.zip`). Optional `--name` and `--bundle-id` match the workflow inputs.
