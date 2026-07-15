#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
generated_root=${WORDLOOP_IOS_CONTENT_OUTPUT:-"$repository_root/ios/Generated/WordLoopContent"}

cd "$repository_root"
npm run content:export
rm -rf "$generated_root"
mkdir -p "$(dirname -- "$generated_root")"
cp -R "$repository_root/content/dist" "$generated_root"
printf 'Bootstrapped WordLoop iOS content at %s\n' "$generated_root"
