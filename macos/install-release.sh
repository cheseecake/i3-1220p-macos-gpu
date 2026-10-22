#!/bin/zsh
# No-build installer for the Iris Xe i3-1220P stack on macOS Tahoe 26.7.1 (build 25G241).
# Everything is prebuilt; this only copies + registers. Double-click in Finder (it auto-asks
# for your password), or run it manually:
#   sudo zsh install.command
set -e
# Auto-elevate: a Finder double-click re-runs this whole script under sudo.
if [[ $EUID -ne 0 ]]; then
  print -P "  %F{blue}i%f Iris Xe installer — needs root, asking for your password"
  exec sudo -E /bin/zsh -- "$0" "$@"
fi
HERE=${0:A:h}
cd -- "$HERE"
LE=$HERE/le; SLE=$HERE/sle; OUT=$HERE/out
[[ -d $LE/AppleIntelTGLGraphics.kext && -d $LE/HookCase.kext && -d $SLE/AppleIntelTGLGraphicsMTLDriver.bundle && -d $OUT/xe.bundle ]] \
  || { echo "missing bundles in $HERE (need le/ with HookCase.kext, sle/ and out/)"; exit 1; }
BUILD=$(sw_vers -buildVersion)
if [[ $BUILD != 25G241 ]]; then
  print -P "  %F{yellow}!%f macOS build is $BUILD, the stack is made for 25G241 (Tahoe 26.7.1)."
  [[ "$XE_FORCE" == 1 ]] || { echo "set XE_FORCE=1 to try anyway"; exit 1; }
fi
put() { rm -rf "$2"; mkdir -p "$(dirname "$2")"; ditto "$1" "$2"; chown -R root:wheel "$2"; echo "  $2"; }

echo "== kexts and bundles in /Library/Extensions"
put $LE/AppleIntelTGLGraphics.kext /Library/Extensions/AppleIntelTGLGraphics.kext
put $LE/AppleIntelTGLGraphicsFramebuffer.kext /Library/Extensions/AppleIntelTGLGraphicsFramebuffer.kext
K=/Library/Extensions/AppleIntelTGLGraphics.kext/Contents/Info.plist
plutil -replace IOKitPersonalities.Gen7.IOPCIPrimaryMatch -string 0x9a498086 $K
plutil -replace CFBundleVersion -string 16.0.2 $K
for b in AppleIntelTGLGraphicsMTLDriver AppleIntelTGLGraphicsGLDriver AppleIntelTGLGraphicsVADriver AppleIntelTGLGraphicsVAME AppleIntelGraphicsShared; do
  put $SLE/$b.bundle /Library/Extensions/$b.bundle
done
put $LE/HookCase.kext /Library/Extensions/HookCase.kext

echo "== Metal driver (MTL17) and shared bundle in /Library/GPUBundles"
put $OUT/AppleIntelTGLGraphicsMTLDriver.bundle /Library/GPUBundles/AppleIntelTGLGraphicsMTLDriver.bundle
put $SLE/AppleIntelGraphicsShared.bundle /Library/GPUBundles/AppleIntelGraphicsShared.bundle

echo "== shader compiler in /System/Library/Caches/xe.bundle"
put $OUT/xe.bundle /System/Library/Caches/xe.bundle

echo "== registering kexts in the Auxiliary Kernel Collection"
kexts=(-p /Library/Extensions/HookCase.kext -p /Library/Extensions/AppleIntelTGLGraphics.kext -p /Library/Extensions/AppleIntelTGLGraphicsFramebuffer.kext)
/usr/bin/kmutil load -z --load-style match-only $kexts

cat <<EOF

done. NootedGreen.kext (the Lilu plugin) is NOT installed here — copy it into your EFI:
  $HERE/NootedGreen.kext  ->  EFI/OC/Kexts/NootedGreen.kext
Enable it in config.plist (boot-args from docs/PORT-I3-1220P.md). Your OpenCore must
already spoof device-id 9A49 + ig-platform-id 0x9A490000.
Approve the extension in System Settings > Privacy & Security if asked, then reboot.
Check: system_profiler SPDisplaysDataType   (look for "Metal Support")
EOF