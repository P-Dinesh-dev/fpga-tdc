#!/bin/sh
# Run the m-labs/tdc-core testbenches, which are the Gate 1 reading material.
# Clones the upstream repo on first run and applies our patch for the controller
# testbench, which does not compile as shipped. See SPEC.md, 2026-09-17.
set -e
cd "$(dirname "$0")/.."

# A shell started before ghdl was installed has a stale PATH, so look where
# winget actually put it.
if ! command -v ghdl >/dev/null 2>&1; then
    for d in "$LOCALAPPDATA/Microsoft/WinGet/Links" \
             "$LOCALAPPDATA/Microsoft/WinGet/Packages"/ghdl.ghdl*/bin; do
        [ -x "$d/ghdl.exe" ] && { PATH="$d:$PATH"; break; }
    done
fi
command -v ghdl >/dev/null 2>&1 || { echo "ghdl not found. winget install ghdl.ghdl.ucrt64.mcode"; exit 1; }

[ -d reference/tdc-core ] || git clone --depth 1 https://github.com/m-labs/tdc-core reference/tdc-core
git -C reference/tdc-core diff --quiet && git -C reference/tdc-core apply ../../patches/*.patch

for t in lbc divider freqc controller; do
    if ( cd "reference/tdc-core/tb/$t" && sh simulate.sh 2>&1 | grep -q "Test passed" ); then
        echo "PASS  $t"
    else
        echo "FAIL  $t"
    fi
done
