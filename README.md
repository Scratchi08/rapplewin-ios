# RAppleWin for iOS (project start)

Goal: an installable `.ipa` of an Apple II emulator with RetroAchievements, based on
RAppleWin 1.30.20.0 (AppleWin, GPL v2+).

## Why not port the uploaded .exe?
`RAppleWin.zip` only contains a 32-bit Windows binary (`RAppleWin.exe`, Win32/DirectX,
plus the closed-source RA integration DLL loader). Binaries can't be ported to iOS; the
work needs **source**. AppleWin's source is open (GPL) and its core already builds
outside Windows, so this project reuses that rather than the Win32 UI.

## Architecture
```
SwiftUI app (Sources/App)  ──►  LibretroHost.mm (Sources/Bridge)  ──►  AppleWin libretro core (static .a)
  touch keyboard, disk picker      video→UIImage, audio→AVAudioEngine      CPU/video/disk/Mockingboard
                                   input, CADisplayLink @ core FPS
                          (later)  rcheevos rc_client reads retro_get_memory_data()
```

## Roadmap
1. **Build the core for iOS** (`scripts/build_core.sh`): the hardest step. Cross-build or stub
   boost/libyaml/minizip/libpcap; pin to the 1.30.20.0 tag. No JIT is needed (AppleWin is an
   interpreter), so it works under normal iOS signing.
2. **Boot MASTER.DSK** through `LibretroHost` (video + audio + keyboard).
3. **Input**: on-screen Apple II keyboard, Ctrl/Esc/arrows, virtual joystick/paddles, MFi controllers.
4. **Disk management**: .dsk/.do/.po/.woz/.nib, drive 1/2, hard-disk images, save states (`retro_serialize`).
5. **RetroAchievements**: replace the Windows `RA_Integration.dll` with
   [rcheevos](https://github.com/RetroAchievements/rcheevos) `rc_client` (login, game hash,
   achievement runtime over emulated RAM, unlock toast + `unlock.wav` in `Resources/`).
6. **Polish**: iPad layout, CRT filters (Metal), settings (machine type, Mockingboard).
7. **Distribution**: see below.

## Building (needs macOS + Xcode 15+)
```
brew install xcodegen cmake
scripts/build_core.sh      # produces Core/build/<sdk>/libapplewin_libretro.a
scripts/make_ipa.sh        # unsigned RAppleWin.ipa for AltStore/Sideloadly
```

## Status
- [x] Project layout, XcodeGen spec, Swift UI shell, libretro host bridge
- [ ] Nothing here has been compiled or run yet (authored on Linux, no Xcode/network).
      `libretro_min.h` should be swapped for the official `libretro.h`.
- [ ] Core build for iOS, achievements, joystick input

## Licensing
AppleWin is GPL v2+, so this derivative must be GPL too (`LICENSE-GPL.txt`, source must be offered).
GPL is generally considered incompatible with App Store terms, so plan on sideloading
(AltStore, Sideloadly, TrollStore) or the EU alternative marketplaces. RetroAchievements
branding/API use also needs their permission/guidelines.
