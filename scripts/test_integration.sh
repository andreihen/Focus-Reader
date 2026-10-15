#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tools_dir=${FOCUS_TOOLS_DIR:-/workspace/.focus-reader-tools-2026.07.1}
# Every run gets clean isolated KOReader settings. Never touches real user books/settings.
run_dir=$(mktemp -d "${TMPDIR:-/tmp}/focusreader-test.XXXXXX")
trap 'rm -rf "$run_dir"' EXIT HUP INT TERM
mkdir -p "$root/tests/output"
python3 "$root/tests/make_fixture.py" "$run_dir" > /dev/null
cd "$tools_dir/lib/koreader"
KO_HOME="$run_dir" SDL_VIDEODRIVER=dummy ./luajit "$root/tests/integration.lua" "$root" "$run_dir" "${FOCUS_PLUGIN_PARENT:-$root}"
