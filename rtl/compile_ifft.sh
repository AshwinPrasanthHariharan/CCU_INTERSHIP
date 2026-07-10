#!/bin/bash
# Compile IFFT chain testbench with iverilog

cd "$(dirname "$0")"

iverilog -g2009 \
    -o simv_ifft \
    tb/tb_ifft_chain.sv \
    src/ifft.sv \
    src/isfft_pingpong.sv \
    src/grid_loader.sv \
    src/qam_mapper.sv \
    src/constellation.sv

echo "IFFT simulation compiled: simv_ifft"
