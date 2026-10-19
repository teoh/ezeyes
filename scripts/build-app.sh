#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
cd "$project_dir"

mkdir -p "$project_dir/.build/cache/clang" "$project_dir/.build/cache/swiftpm"
CLANG_MODULE_CACHE_PATH="$project_dir/.build/cache/clang" \
    swift build -c release \
    --disable-sandbox \
    --cache-path "$project_dir/.build/cache/swiftpm" \
    --manifest-cache local \
    -Xcc -fmodules-cache-path="$project_dir/.build/cache/clang"

app_dir="$project_dir/dist/EzEyes.app"
mkdir -p "$app_dir/Contents/MacOS"
cp "$project_dir/.build/release/EzEyes" "$app_dir/Contents/MacOS/EzEyes"
cp "$project_dir/Resources/Info.plist" "$app_dir/Contents/Info.plist"
codesign --force --sign - "$app_dir"

print "Built $app_dir"
