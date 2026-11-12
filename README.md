# TikSpice

TikSpice is a personal TikTok tweak: themes, playback, and feed chrome, with an in-app settings panel. It is meant for a decrypted IPA you sideload on your own device.

The settings UI is a searchable, inset-grouped sheet. Private TikTok class and selector names live in one table, `src/HookRegistry.m`. A row is hooked only when that class implements the selector itself and the return type matches, so a stale name is skipped instead of crashing.

## Open settings

TikTok → profile menu → **Settings and privacy**. TikSpice is a real row in that list, last in the **Account** card when that section exists, so it scrolls with the page and uses the same rounded card. Tapping it opens the panel.

That row is attached when the screen’s class is in the `settingsHome` group in `src/HookRegistry.m`, or when the navigation title is “Settings and privacy” (including the common localized forms). The match is the exact class, not a subclass, so it does not land on every settings subpage.

If none of those classes exist in the running app, the same row is added to the profile hamburger menu instead (classes in `profileMenu`, or a class whose name contains both `Profile` and `Menu`). A menu that is not a table gets a row pinned to the bottom of the sheet.

Recovery, if neither place shows the row: touch the screen with **three fingers and hold**. Preferences are stored with `NSUserDefaults` suite `com.tikspice.preferences` inside the app container.

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

Everything that changes TikTok's chrome is off until you turn it on. Haptics start on.

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
| `src/Interface.xm` | Confirmations, tab labels, screen log |
| `src/Entry.m` | Settings row, profile-menu fallback, three-finger recovery |
| `scripts/install-theos.sh` | Linux Theos + iOS 16.5 SDK |
| `scripts/inject-ipa.sh` | cyan injection |
| `.github/workflows/build.yml` | Push build, and IPA injection on dispatch |
| `packaging/PhotoUsage.plist` | Merged into the IPA so Photos can be written |

The package filter plist covers:

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

The package is `packages/com.tikspice.tweak_1.0.2_iphoneos-arm64.deb`. The dylib staged inside it only links system libraries (`/usr/lib` and `/System/Library`). `scripts/check-dylib-deps.py` fails the build if CydiaSubstrate, ElleKit, `/var/jb`, or an `@rpath` dependency appears.

On a Mac with Theos and an iOS SDK already installed, export `THEOS` and run the same `make` command. `scripts/install-theos.sh` is the Linux toolchain only.

`THEOS_PACKAGE_SCHEME` defaults to `rootless`. Override it in the environment if you need a different layout.

## GitHub Actions

`.github/workflows/build.yml` has two jobs.

**Build tweak** runs on every push and pull request. It installs Theos on `ubuntu-latest`, runs `make package`, checks that `TikSpice.dylib` links only system libraries, and uploads two artifacts kept for 5 days: `TikSpice-deb` (the package) and `TikSpice-dylib` (the file LiveContainer loads).

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
| `group` | `ads`, `feed`, `video`, `region`, `live`, `shop`, `upload`, `story`, `music`, `settingsHome`, `profileMenu`, `profile`, `interaction`, `player` |
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

## LiveContainer

LiveContainer injects `.dylib` files. It does not load a `.deb`. The 1.0.0 dylib also linked `/var/jb/usr/lib/libsubstrate.dylib`. dyld refuses that path inside LiveContainer, so the file never ran and no entry point appeared. LiveContainer’s own ElleKit does not satisfy an absolute `/var/jb` install name.

1.0.1 hooks Objective-C methods with the runtime (`method_setImplementation` via Logos’ internal generator). The shipped dylib does not link CydiaSubstrate, ElleKit, or anything under `/var/jb`.

Load it like this:

1. On GitHub, open the latest successful **Build** run (or run the workflow yourself).
2. Download the **TikSpice-dylib** artifact. Leave the `.deb` artifact for a jailbreak install.
3. Unzip the artifact. In LiveContainer, open **Tweaks** and import `TikSpice.dylib` into the folder you select for TikTok (an app-specific subfolder, or the root Tweaks folder).
4. Select that folder for TikTok. Leave TweakLoader enabled (`Don't Load TweakLoader` off). LiveContainer signs the dylib when the app launches.
5. Open TikTok, then Profile → menu → **Settings and privacy**. TikSpice is the first row.
6. If your build’s settings class is not in `settingsHome`, open the profile hamburger menu. The row is added there instead.
7. If neither shows it, touch and hold with three fingers. Hook status lists the screen class to add under `settingsHome` or `profileMenu`.

## Install the package

Jailbreak (rootless): install the `.deb`. It does not depend on CydiaSubstrate; the same runtime hooks are inside the dylib.

Sideload outside LiveContainer: use the patched IPA from the dispatch workflow, or inject the `.deb` yourself. The patched IPA is uploaded only as an Actions artifact.

```bash
./scripts/inject-ipa.sh \
  --input YourApp.ipa \
  --tweak packages/com.tikspice.tweak_1.0.2_iphoneos-arm64.deb \
  --output TikSpice-patched.ipa \
  --plist packaging/PhotoUsage.plist
```

cyan has to be on `PATH` (`pipx install --force https://github.com/asdfzxcvbn/pyzule-rw/archive/main.zip`). Optional `--name` and `--bundle-id` match the workflow inputs.
