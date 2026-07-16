#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
generated_root=${WORDLOOP_IOS_CONTENT_OUTPUT:-"$repository_root/ios/Generated/WordLoopContent"}
package_resource_root=${WORDLOOP_IOS_CONTENT_RESOURCE_OUTPUT:-"$repository_root/ios/Packages/WordLoopContent/Sources/WordLoopContent/Resources/WordLoopContent"}

generated_stage=
package_stage=
generated_previous=
package_previous=
committed=0

cleanup() {
    status=$?
    trap - EXIT HUP INT TERM

    if [ "$committed" -ne 1 ]; then
        if [ -n "$generated_previous" ] && { [ -e "$generated_previous" ] || [ -L "$generated_previous" ]; }; then
            rm -rf "$generated_root"
            mv "$generated_previous" "$generated_root"
        elif [ -n "$generated_stage" ] && ! { [ -e "$generated_stage" ] || [ -L "$generated_stage" ]; }; then
            rm -rf "$generated_root"
        fi

        if [ -n "$package_previous" ] && { [ -e "$package_previous" ] || [ -L "$package_previous" ]; }; then
            rm -rf "$package_resource_root"
            mv "$package_previous" "$package_resource_root"
        elif [ -n "$package_stage" ] && ! { [ -e "$package_stage" ] || [ -L "$package_stage" ]; }; then
            rm -rf "$package_resource_root"
        fi
    fi

    [ -z "$generated_stage" ] || rm -rf "$generated_stage"
    [ -z "$package_stage" ] || rm -rf "$package_stage"
    [ -z "$generated_previous" ] || rm -rf "$generated_previous"
    [ -z "$package_previous" ] || rm -rf "$package_previous"
    exit "$status"
}

trap cleanup EXIT
trap 'exit 1' HUP INT TERM

materialize_file() {
    source_file=$1
    destination_file=$2

    mkdir -p "$(dirname -- "$destination_file")"
    if ! ln "$source_file" "$destination_file" 2>/dev/null; then
        cp "$source_file" "$destination_file"
    fi
}

materialize_tree() {
    source_tree=$1
    destination_tree=$2

    if find "$source_tree" -mindepth 1 ! -type d ! -type f -print | grep -q .; then
        printf 'Refusing to materialize a non-regular content tree: %s\n' "$source_tree" >&2
        return 1
    fi

    mkdir -p "$destination_tree"
    find "$source_tree" -mindepth 1 -type d -print | while IFS= read -r source_directory; do
        relative_path=${source_directory#"$source_tree"/}
        mkdir -p "$destination_tree/$relative_path"
    done
    find "$source_tree" -type f -print | while IFS= read -r source_file; do
        relative_path=${source_file#"$source_tree"/}
        materialize_file "$source_file" "$destination_tree/$relative_path"
    done
}

prepare_stage() {
    target=$1
    target_parent=$(dirname -- "$target")

    mkdir -p "$target_parent"
    mktemp -d "$target_parent/.WordLoopContent.stage.XXXXXX"
}

cd "$repository_root"
npm run content:export

generated_stage=$(prepare_stage "$generated_root")
package_stage=$(prepare_stage "$package_resource_root")

materialize_tree "$repository_root/content/dist" "$generated_stage"
materialize_file "$repository_root/content/dist/catalog.json" "$package_stage/catalog.json"
materialize_tree "$repository_root/content/dist/courses" "$package_stage/courses"

generated_previous="$(dirname -- "$generated_root")/.WordLoopContent.previous.$$"
package_previous="$(dirname -- "$package_resource_root")/.WordLoopContent.previous.$$"
rm -rf "$generated_previous" "$package_previous"

if [ -e "$generated_root" ] || [ -L "$generated_root" ]; then
    mv "$generated_root" "$generated_previous"
fi
mv "$generated_stage" "$generated_root"

if [ -e "$package_resource_root" ] || [ -L "$package_resource_root" ]; then
    mv "$package_resource_root" "$package_previous"
fi
mv "$package_stage" "$package_resource_root"

committed=1
rm -rf "$generated_previous" "$package_previous"
generated_previous=
package_previous=

printf 'Bootstrapped WordLoop iOS intermediate content at %s\n' "$generated_root"
printf 'Bootstrapped WordLoopContent package resources at %s\n' "$package_resource_root"
