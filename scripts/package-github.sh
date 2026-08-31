#!/bin/bash
set -euo pipefail

# Community snapshot: no-Trash capability set, ad-hoc signed, not notarized.
project_root="$(cd "$(dirname "$0")/.." && pwd)"
package_work="$(mktemp -d "${TMPDIR:-/tmp}/Omit-GitHub-Package.XXXXXX")"
cd "$project_root"

xcodebuild -quiet -project Omit.xcodeproj -scheme Omit \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath "$package_work/DerivedData" \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS=OMIT_APP_STORE build

package_app="$package_work/DerivedData/Build/Products/Release/Omit.app"
codesign --force --sign - --entitlements Omit/Omit-AppStore.entitlements "$package_app"
codesign --verify --deep --strict "$package_app"
lipo "$package_app/Contents/MacOS/Omit" -verify_arch arm64 x86_64
mkdir -p dist
ditto -c -k --sequesterRsrc --keepParent "$package_app" "$package_work/Omit.zip"
cp "$package_work/Omit.zip" dist/Omit.zip
(cd dist && shasum -a 256 Omit.zip > SHA256SUMS)
printf 'Package: %s/dist/Omit.zip\nBuild retained at: %s\n' "$project_root" "$package_work"
