#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
remote=${WORDLOOP_CONTENT_SSH:-ubuntu@43.172.79.177}
ssh_identity=${WORDLOOP_CONTENT_SSH_IDENTITY:-"$HOME/.ssh/tengxunyun.pem"}
remote_root=${WORDLOOP_CONTENT_REMOTE_ROOT:-/opt/boringmax/wordloop/content}
public_base=${WORDLOOP_CONTENT_PUBLIC_BASE:-https://boringmax.com/wordloop-content}
default_course=a01-asking-about-products-and-services-a2
stage="${remote_root}.upload.$$"

cleanup() {
    ssh -i "$ssh_identity" "$remote" "rm -rf '$stage'" >/dev/null 2>&1 || true
}
trap cleanup EXIT HUP INT TERM

wait_for_url() {
    url=$1
    attempt=1
    while [ "$attempt" -le 10 ]; do
        if curl -fsS "$url" >/dev/null; then return 0; fi
        attempt=$((attempt + 1))
        sleep 1
    done
    return 1
}

cd "$repository_root"
npm run content:export:app-store

ssh -i "$ssh_identity" "$remote" "mkdir -p '$remote_root/courses' '$stage'"
rsync -a --ignore-existing -e "ssh -i $ssh_identity" content/dist/courses/ "$remote:$remote_root/courses/"
scp -q -i "$ssh_identity" content/dist/catalog.json "$remote:$stage/catalog.json"
ssh -i "$ssh_identity" "$remote" "set -eu; mv '$stage/catalog.json' '$remote_root/catalog.json'; chown -R shipnow:shipnow '$remote_root'; rmdir '$stage'"

wait_for_url "$public_base/catalog.json"
wait_for_url "$public_base/courses/$default_course/1/course.json"
wait_for_url "$public_base/courses/$default_course/1/audio/a01-asking-about-products-and-services-a2-001.m4a"
curl -fsS -H 'Range: bytes=0-31' "$public_base/courses/$default_course/1/audio/a01-asking-about-products-and-services-a2-001.m4a" >/dev/null

trap - EXIT HUP INT TERM
printf 'Published App Store course catalog to %s\n' "$public_base"
