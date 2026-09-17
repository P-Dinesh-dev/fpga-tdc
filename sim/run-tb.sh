#!/bin/sh
# Run our own testbenches. For the upstream ones see run-reference-tb.sh.
set -e
cd "$(dirname "$0")/.."

if ! command -v ghdl >/dev/null 2>&1; then
    for d in "$LOCALAPPDATA/Microsoft/WinGet/Links" \
             "$LOCALAPPDATA/Microsoft/WinGet/Packages"/ghdl.ghdl*/bin; do
        [ -x "$d/ghdl.exe" ] && { PATH="$d:$PATH"; break; }
    done
fi
command -v ghdl >/dev/null 2>&1 || { echo "ghdl not found. winget install ghdl.ghdl.ucrt64.mcode"; exit 1; }

mkdir -p sim/build
ghdl -i --workdir=sim/build rtl/*.vhd tb/*.vhd

for t in tb_encoder tb_coarse; do
    ghdl -m --workdir=sim/build $t >/dev/null
    if ghdl -r --workdir=sim/build $t 2>&1 | grep -q "Test passed"; then
        echo "PASS  $t"
    else
        echo "FAIL  $t"
        ghdl -r --workdir=sim/build $t 2>&1 | tail -5
    fi
done
