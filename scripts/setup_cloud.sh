#!/bin/sh
set -eu
# Development-only desktop runtime. Nothing here is installed on the Kindle.
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tools_dir=${FOCUS_TOOLS_DIR:-/workspace/.focus-reader-tools-2026.07.1}
release=v2026.07.1
archive="$tools_dir/koreader-linux-x86_64-$release.tar.xz"
expected=299aadb28147a25e9432ced1214ea444a4184393b5ae97cf42402c8a61b1a1b0
if [ "$(uname -m)" != x86_64 ]; then
    echo 'This cloud setup script requires Linux x86_64. Plugin Lua sources are architecture independent.' >&2
    exit 1
fi
mkdir -p "$tools_dir"
if [ ! -f "$archive" ]; then
    curl --fail --location --retry 2 --proto '=https' --tlsv1.2 \
        "https://github.com/koreader/koreader/releases/download/$release/koreader-linux-x86_64-$release.tar.xz" \
        --output "$archive.part"
    printf '%s  %s\n' "$expected" "$archive.part" | sha256sum -c -
    mv "$archive.part" "$archive"
fi
printf '%s  %s\n' "$expected" "$archive" | sha256sum -c -
if [ ! -x "$tools_dir/lib/koreader/luajit" ]; then
    tar -xJf "$archive" -C "$tools_dir"
fi
"$tools_dir/lib/koreader/luajit" -v
python3 "$root/tests/make_fixture.py" "$root/tests/output"
echo 'Development dependencies ready. Run make test and make package from the checkout.'
