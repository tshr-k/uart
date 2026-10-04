#!/usr/bin/env bash
set -euo pipefail

source "$HOME/tools/oss-cad-suite/environment"

MODULE="$1"

RTL="rtl/${MODULE}.sv"
PROPS="formal/${MODULE}_props.sv"
VERILOG="verilog/${MODULE}.v"

[ -f "$RTL" ] || { echo "Missing $RTL"; exit 1; }
[ -f "$PROPS" ] || { echo "Missing $PROPS"; exit 1; }

mkdir -p verilog

# synthesize rich-SystemVerilog RTL to the simple Verilog that EBMC requires
yosys -q -p "
    read_slang $RTL rtl/pkg/utils_pkg.sv
    hierarchy -check -top $MODULE
    proc
    opt
    fsm
    opt
    memory
    opt
    flatten
    write_verilog -noattr $VERILOG
" > /dev/null

# apply exactly one initial reset pulse then assume reset is never asserted again
ebmc "$PROPS" "$VERILOG" --bound 10 --reset "$MODULE"_props.a_rst==1