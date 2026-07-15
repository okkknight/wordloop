#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
destination=${WORDLOOP_IOS_DESTINATION:-"platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5"}
package_build_root="$repository_root/ios/.build"
derived_data="$repository_root/ios/.derivedData"

printf '[1/3] Bootstrap generated course content\n'
"$repository_root/scripts/bootstrap_ios_content.sh" >/dev/null

printf '[2/3] Test local Swift packages\n'
for package in WordLoopCore WordLoopNetworking WordLoopContent WordLoopDesignSystem WordLoopAudio WordLoopProgress WordLoopRealtime WordLoopFeatures; do
  printf '  - %s\n' "$package"
  swift test \
    --package-path "$repository_root/ios/Packages/$package" \
    --scratch-path "$package_build_root/$package" >/dev/null
done

printf '[3/3] Build WordLoop for %s\n' "$destination"
xcodebuild \
  -project "$repository_root/ios/WordLoop.xcodeproj" \
  -scheme WordLoop \
  -configuration Debug \
  -destination "$destination" \
  -derivedDataPath "$derived_data" \
  CODE_SIGNING_ALLOWED=NO \
  COMPILER_INDEX_STORE_ENABLE=NO \
  build >/dev/null

printf 'WordLoop iOS verification passed.\n'
