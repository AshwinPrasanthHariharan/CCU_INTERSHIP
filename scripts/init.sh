#!/usr/bin/env sh

# OTFS FPGA Accelerator
# Pixi Environment Initialization

export PROJECT_ROOT="$PIXI_PROJECT_ROOT"

export PATH="$PROJECT_ROOT/scripts/bin:$PATH"

. "$PROJECT_ROOT/scripts/vivado_env.sh"
