#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
remote=${WORDLOOP_CONTENT_SSH:-root@89.208.242.44}
remote_root=${WORDLOOP_CONTENT_REMOTE_ROOT:-/opt/boringmax/wordloop/content-staging}
public_base=${WORDLOOP_CONTENT_PUBLIC_BASE:-https://boringmax.com/wordloop-content-staging}
stage="${remote_root}.upload.$$"

cleanup() {
    ssh "$remote" "rm -rf '$stage'" >/dev/null 2>&1 || true
}
trap cleanup EXIT HUP INT TERM

cd "$repository_root"
npm run content:export

# Course directories are versioned and immutable. Existing files are never replaced.
ssh "$remote" "mkdir -p '$remote_root/courses' '$stage'"
rsync -a --ignore-existing content/dist/courses/ "$remote:$remote_root/courses/"

# The catalog is the only mutable pointer and is atomically replaced after all content exists.
scp -q content/dist/catalog.json "$remote:$stage/catalog.json"
ssh "$remote" "set -eu; chown -R shipnow:shipnow '$remote_root'; mv '$stage/catalog.json' '$remote_root/catalog.json'; rmdir '$stage'"

curl -fsS "$public_base/catalog.json" >/dev/null
curl -fsS "$public_base/courses/modern-family-s01e01/1/course.json" >/dev/null
curl -fsS -H 'Range: bytes=0-31' "$public_base/courses/modern-family-s01e01/1/audio/s01e01-0003.m4a" >/dev/null

trap - EXIT HUP INT TERM
printf 'Published iOS course catalog to %s\n' "$public_base"
