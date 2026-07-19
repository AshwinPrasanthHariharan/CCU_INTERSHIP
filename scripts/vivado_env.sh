#!/bin/bash
# --- Xilinx/Vivado Session Environment ---

# 1. Environment Variables
export _JAVA_AWT_WM_NONREPARENTING=1
export LC_ALL=C
export XILINXD_LICENSE_FILE=27000@100.71.85.97

# 2. Safe Wrapper Functions
vivado() {
    QT_AUTO_SCREEN_SCALE_FACTOR=0 \
    QT_SCALE_FACTOR=1 \
    bash -c 'source ~/Applications/Xilinx/2026.1/Vivado/settings64.sh && vivado -journal /tmp/vivado.jou -log /tmp/vivado.log"$@"' -- "$@" \
}

vlm() {
    QT_AUTO_SCREEN_SCALE_FACTOR=0 \
    QT_SCALE_FACTOR=1 \
    bash -c 'source ~/Applications/Xilinx/2026.1/Vivado/settings64.sh && vlm "$@"' -- "$@" \
}
vivadof() {
    vivado &> /dev/null &
}

vlmf() {
    vlm &> /dev/null &
}


# 3. The Unhook / Cleanup Function
unhook_vivado() {
    # Remove the variables
    unset _JAVA_AWT_WM_NONREPARENTING
    unset LC_ALL
    unset XILINXD_LICENSE_FILE
    
    # Remove the Vivado functions
    unset -f vivado
    unset -f vlm
    
    echo " Vivado session completely unhooked! Shell restored to normal."
    
    # Destroy the unhook function itself so no trace is left
    unset -f unhook_vivado
}

clean_vivado() {
    emulate -L zsh
    setopt null_glob globstarshort

    local trash_globs=(
        "**/.Xil"
        "**/*.log"
        "**/.webtalk"
        "**/.cache"
        "**/.hw"
        "**/.ip_user_files"
        "**/.runs"
        "**/.sim"
        "**/.gen"
        "**/xsim.dir"
        "**/xsim.ini"
        "**/mem_init_files"
        "**/compile.sh"
        "**/elaborate.sh"
        "**/simulate.sh"
        "**/vivado.jou"
        "**/vivado.log"
        "**/vivado_pid*.str"
        "**/webtalk*.jou"
        "**/webtalk*.log"
        "**/usage_statistics_webtalk.xml"
        "**/usage_statistics_ext_xilinxd.xml"
        "**/*.wdb"
        "**/*.pb"
        "**/*.str"
        "**/*.Xil"
    )

    local removed=0

    for pattern in "${trash_globs[@]}"; do
        for item in ${~pattern}; do
            [[ -e "$item" ]] || continue
            rm -rf -- "$item"
            ((removed++))
            print -P "%F{yellow}Removed:%f $item"
        done
    done

    print -P "%F{green}✓ Removed $removed Vivado artifacts.%f"
}
# 4. Visual Confirmation
echo "⚡ Vivado session loaded!"
echo " Run 'vivado' or 'vlm' to start working."
echo " Run 'unhook_vivado' when you are done to clean your terminal."
