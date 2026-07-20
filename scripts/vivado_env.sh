#!/usr/bin/env bash

# Xilinx Vivado Development Environment

# ------------------------------------------------------------------------------
# Environment Variables
# ------------------------------------------------------------------------------

export _JAVA_AWT_WM_NONREPARENTING=1
export LC_ALL=C
export XILINXD_LICENSE_FILE=27000@100.71.85.97

VIVADO_ROOT="$HOME/Applications/Xilinx/2026.1/Vivado"
VIVADO_SETTINGS="$VIVADO_ROOT/settings64.sh"

# ------------------------------------------------------------------------------
# Verify Installation
# ------------------------------------------------------------------------------

if [[ ! -f "$VIVADO_SETTINGS" ]]; then
    echo "Warning: Vivado installation not found:"
    echo "  $VIVADO_SETTINGS"
    return 0
fi

# ------------------------------------------------------------------------------
# Vivado Wrapper
# ------------------------------------------------------------------------------

vivado() {
    source "$VIVADO_SETTINGS"

    QT_AUTO_SCREEN_SCALE_FACTOR=0 \
    QT_SCALE_FACTOR=1 \
    command vivado \
        -journal /tmp/vivado.jou \
        -log /tmp/vivado.log \
        "$@"
}

# ------------------------------------------------------------------------------
# Vivado License Manager
# ------------------------------------------------------------------------------

vlm() {
    source "$VIVADO_SETTINGS"
    command vlm "$@"
}

# ------------------------------------------------------------------------------
# Background Launchers
# ------------------------------------------------------------------------------

vivadof() {
    vivado "$@" >/dev/null 2>&1 &
}

vlmf() {
    vlm "$@" >/dev/null 2>&1 &
}

# ------------------------------------------------------------------------------
# Vivado Cleanup
# ------------------------------------------------------------------------------

clean_vivado() {
    local removed=0

    while IFS= read -r -d '' item; do
        rm -rf "$item"
        ((removed++))
        printf 'Removed: %s\n' "$item"
    done < <(
        find . \
            \( \
                -name ".Xil" -o \
                -name ".webtalk" -o \
                -name ".cache" -o \
                -name ".hw" -o \
                -name ".ip_user_files" -o \
                -name ".runs" -o \
                -name ".sim" -o \
                -name ".gen" -o \
                -name "xsim.dir" -o \
                -name "mem_init_files" -o \
                -name "*.log" -o \
                -name "*.jou" -o \
                -name "*.wdb" -o \
                -name "*.pb" -o \
                -name "*.str" -o \
                -name "xsim.ini" -o \
                -name "compile.sh" -o \
                -name "elaborate.sh" -o \
                -name "simulate.sh" \
            \) \
            -print0
    )

    printf 'Removed %d Vivado artifact(s).\n' "$removed"
}

# ------------------------------------------------------------------------------
# Status
# ------------------------------------------------------------------------------

echo "Vivado environment loaded."
echo "Available commands:"
echo "  vivado"
echo "  vivadof"
echo "  vlm"
echo "  vlmf"
echo "  clean_vivado"
