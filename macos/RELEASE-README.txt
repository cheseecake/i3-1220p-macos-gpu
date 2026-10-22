Iris Xe acceleration for the Intel Core i3-1220P (Alder Lake-P, 64 EU)
on macOS Tahoe 26.7.1 (build 25G241). Full Metal. No Xcode required.

Contents
  NootedGreen.kext   Lilu plugin (the i3-1220P port). Goes in YOUR EFI.
  le/                 Apple's 16.0.32 TGL kexts (com.xxxxx bundle IDs) + HookCase.kext.
  sle/               Apple's 16.0.32 TGL GL/VA/VAME/Shared/MTL bundles.
  out/                Prebuilt Metal stack: patched MTL17 bundle + xe.bundle (shader compiler).
  install.command     Copy-only installer (ditto + plutil + kmutil). No build. Double-click it.

Steps
  1. Double-click install.command  (it asks for your password and runs the install),
       or run  sudo zsh install.command
       First removes any previous install (unload + delete), then copies the 16.0.32
       driver + shader stack into /Library/Extensions, /Library/GPUBundles and
       /System/Library/Caches, and registers the kexts in the Auxiliary Kernel Collection.
       Re-running it is safe: it always replaces, never stacks.
  2. Copy NootedGreen.kext into your EFI's OC/Kexts/ and enable it in
       config.plist (boot-args from the repo's docs/PORT-I3-1220P.md).
       Your OpenCore must already spoof device-id 9A49 + ig-platform-id
       0x9A490000 (WhateverGreen / DeviceProperties).
  3. Reboot. If asked, approve the extension in
       System Settings > Privacy & Security.
  4. Check: system_profiler SPDisplaysDataType   (look for "Metal Support")

Upgrading an existing install
  Two things move: the kernel plugin and the user-space stack.
    - Replace EFI/OC/Kexts/NootedGreen.kext with the new one (this package's copy).
    - Run install.command again (double-click). It clears the old /Library + /Caches
      pieces first, so nothing stale survives.
  Then reboot. No need to uninstall manually first.

Requirements
  - macOS Tahoe 26.7.1, build 25G241 exactly (the patches target this IOAF2 build).
  - Intel x86_64 Mac.
  - Your own OpenCore EFI with the 9A49 spoof. This package ships no EFI.

Uninstall
  Delete /Library/Extensions/AppleIntelTGLGraphics*, /Library/GPUBundles/AppleIntelTGLGraphicsMTLDriver.bundle,
  /Library/GPUBundles/AppleIntelGraphicsShared.bundle, /System/Library/Caches/xe.bundle;
  disable NootedGreen in EFI; reboot.

Notes
  The Apple binaries in le/ and sle/ are GPUDriversIntel 16.0.32, taken unchanged from
  sgiammori/NootedGreen. The kext and the macos/ stack are licensed under the Thou Shalt
  Not Profit License 1.0 (see the repo LICENSE).