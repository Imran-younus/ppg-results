#!/bin/ksh
#=============================================================================
# ppg_sim_lib.sh — Shared library for PPG HSPICE simulation flow
#
# Provides reusable helpers for model validation, netlist patching,
# SPF port ordering, LSF execution, and result extraction.
#
# POSIX ksh compliant: uses prefixed globals (_vm_*, _pn_*, _ps_*, _cw_*, _wj_*).
#=============================================================================

# Cluster license server constant (avoids empty $LM_LICENSE_FILE issue)
_LM_LICENSE='27020@riclic.pok.ibm.com:27020@poklnxlic04.pok.ibm.com:27020@cdsserv1.pok.ibm.com:27020@cdsserv2.pok.ibm.com:27020@cdsserv3.pok.ibm.com'

# Standard defaults
DEFAULT_VOLTAGES='0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0 1.05 1.1 1.15'
DEFAULT_TEMP='25'
DEFAULT_SPFDIR='/gpfs/projects/t/titan/dtco/usr/sbajaj/SPF_files/tpdk0.6sb'
DEFAULT_HSPICE_BIN='/afs/apd.pok.ibm.com/ant/cad_tools/synopsys/Hspice/T-2022.06-SP2/hspice/hspice/T-2022.06-SP2/hspice/bin'
DEFAULT_LSF_SELECT='(osver==rh8) && (type == X86_64) && ! etx && ! nojobs'

# SPF port reordering rules (normalises all cells to VSS VDD A Z)
_SUBCKT_SED_1='s/\.SUBCKT \([0-9a-zA-Z*_]*\) Z VDD A VSS/.SUBCKT \1 VSS VDD A Z/g'
_SUBCKT_SED_2='s/\.SUBCKT \([0-9a-zA-Z*_]*\) VDD Z A VSS/.SUBCKT \1 VSS VDD A Z/g'
_SUBCKT_SED_3='s/\.SUBCKT \([0-9a-zA-Z*_]*\) A VDD Z VSS/.SUBCKT \1 VSS VDD A Z/g'
_VT_SED_N='s^.slvtnfet^ ulvtnfet^'
_VT_SED_P='s^.slvtpfet^ ulvtpfet^'

# 24 standard cell entries: "label  spf_filename  subckt_name"
PPG_STD_CELLS_24="
6TSL_INV    PPG1_INV_X2_6TSL.spf          PPG1_INV_X2_6TSL
6TSL_NAND2B PPG1_NAND2_X1_B_6TSL.spf      PPG1_NAND2_X1_B_6TSL
6TSL_NOR2B  PPG1_NOR2_X1_B_6TSL.spf       PPG1_NOR2_X1_B_6TSL
6TSL_NAND3B PPG1_NAND3_X1_B_6TSL.spf      PPG1_NAND3_X1_B_6TSL
6TSL_AOI21  PPG1_AOI21_X1_1S0_6TSL.spf    PPG1_AOI21_X1_1S0_6TSL
6TSL_AOI22  PPG1_AOI22_X1_S110_6TSL.spf   PPG1_AOI22_X1_S110_6TSL
6TSL_OAI21  PPG1_OAI21_X1_0S1_6TSL.spf    PPG1_OAI21_X1_0S1_6TSL
6TSL_OAI22  PPG1_OAI22_X1_0S11_6TSL.spf   PPG1_OAI22_X1_0S11_6TSL
7TSL_INV    PPG1_INV_X2_7TSL.spf          PPG1_INV_X2_7TSL
7TSL_NAND2B PPG1_NAND2_X1_B_7TSL.spf      PPG1_NAND2_X1_B_7TSL
7TSL_NOR2B  PPG1_NOR2_X1_B_7TSL.spf       PPG1_NOR2_X1_B_7TSL
7TSL_NAND3B PPG1_NAND3_X1_B_7TSL.spf      PPG1_NAND3_X1_B_7TSL
7TSL_AOI21  PPG1_AOI21_X1_1S0_7TSL.spf    PPG1_AOI21_X1_1S0_7TSL
7TSL_AOI22  PPG1_AOI22_X1_S110_7TSL.spf   PPG1_AOI22_X1_S110_7TSL
7TSL_OAI21  PPG1_OAI21_X1_0S1_7TSL.spf    PPG1_OAI21_X1_0S1_7TSL
7TSL_OAI22  PPG1_OAI22_X1_0S11_7TSL.spf   PPG1_OAI22_X1_0S11_7TSL
8TSL_INV    PPG1_INV_X2_8TSL.spf          PPG1_INV_X2_8TSL
8TSL_NAND2B PPG1_NAND2_X1_B_8TSL.spf      PPG1_NAND2_X1_B_8TSL
8TSL_NOR2B  PPG1_NOR2_X1_B_8TSL.spf       PPG1_NOR2_X1_B_8TSL
8TSL_NAND3B PPG1_NAND3_X1_B_8TSL.spf      PPG1_NAND3_X1_B_8TSL
8TSL_AOI21  PPG1_AOI21_X1_1S0_8TSL.spf    PPG1_AOI21_X1_1S0_8TSL
8TSL_AOI22  PPG1_AOI22_X1_S110_8TSL.spf   PPG1_AOI22_X1_S110_8TSL
8TSL_OAI21  PPG1_OAI21_X1_0S1_8TSL.spf    PPG1_OAI21_X1_0S1_8TSL
8TSL_OAI22  PPG1_OAI22_X1_0S11_8TSL.spf   PPG1_OAI22_X1_0S11_8TSL
"

# 7 standard cells for 101-stage ring oscillator chain
PPG_CHAIN_CELLS_7='7TSL_INVX2 7TSL_NAND2B 7TSL_NAND2T 7TSL_NAND3B 7TSL_NAND3T 7TSL_NOR2B 7TSL_NOR2T'

#-----------------------------------------------------------------------------
# validate_model_params: Checks MODEL_INC, MODEL_LIB, and MODEL_NAME
#-----------------------------------------------------------------------------
validate_model_params() {
    if [ -z "$MODEL_INC" ] || [ -z "$MODEL_LIB" ] || [ -z "$MODEL_NAME" ]; then
        echo "ERROR: MODEL_INC, MODEL_LIB, and MODEL_NAME must all be set." >&2
        echo "  MODEL_INC  = full path to design_include.inc" >&2
        echo "  MODEL_LIB  = full path to fixed_corner.lib" >&2
        echo "  MODEL_NAME = short label (e.g. v0.6SB, v0.6SB2, v0.22)" >&2
        exit 1
    fi
    if [ ! -f "$MODEL_INC" ]; then
        echo "ERROR: MODEL_INC file not found: $MODEL_INC" >&2
        exit 1
    fi
    if [ ! -f "$MODEL_LIB" ]; then
        echo "ERROR: MODEL_LIB file not found: $MODEL_LIB" >&2
        exit 1
    fi
    echo "Model validated: $MODEL_NAME"
    echo "  INC: $MODEL_INC"
    echo "  LIB: $MODEL_LIB"
}

#-----------------------------------------------------------------------------
# verify_model <netlist>: Validates active .inc and .lib paths in netlist
#-----------------------------------------------------------------------------
verify_model() {
    _vm_netlist=$1
    _vm_inc_count=$(grep -c "^\.inc.*design_include\.inc" "$_vm_netlist" 2>/dev/null || echo 0)
    _vm_lib_count=$(grep -c "^\.lib.*fixed_corner\.lib"   "$_vm_netlist" 2>/dev/null || echo 0)

    if [ "$_vm_inc_count" -eq 0 ]; then
        echo "ERROR: No active design_include.inc in: $_vm_netlist" >&2
        exit 1
    fi
    if [ "$_vm_inc_count" -gt 1 ]; then
        echo "ERROR: Multiple active design_include.inc lines in: $_vm_netlist" >&2
        exit 1
    fi
    if [ "$_vm_lib_count" -eq 0 ]; then
        echo "ERROR: No active fixed_corner.lib in: $_vm_netlist" >&2
        exit 1
    fi

    _vm_active_inc=$(grep "^\.inc.*design_include\.inc" "$_vm_netlist")
    if ! echo "$_vm_active_inc" | grep -qF "$MODEL_INC"; then
        echo "ERROR: Model mismatch in $_vm_netlist" >&2
        echo "  Expected: $MODEL_INC" >&2
        echo "  Active:   $_vm_active_inc" >&2
        exit 1
    fi
}

#-----------------------------------------------------------------------------
# patch_netlist <src> <dst> <spf_path> <subckt> [pvdd] [temp]
# Injects model pair, SPF path, subcircuit, PVDD, and temperature.
#-----------------------------------------------------------------------------
patch_netlist() {
    _pn_src=$1 _pn_dst=$2 _pn_spf=$3 _pn_subckt=$4 _pn_pvdd=$5 _pn_temp=$6

    _pn_sedscript=$(mktemp /tmp/ppg_patch_XXXXXX.sed)

    # 1. Comment out active model pair
    printf '/^\.inc '"'"'.*design_include\.inc/s/^\./\*./\n' >> "$_pn_sedscript"
    printf '/^\.lib .*fixed_corner\.lib/s/^\./\*./\n'        >> "$_pn_sedscript"

    # 2. Uncomment target model pair
    printf 's|^\*\.inc '"'"'%s'"'"'|.inc '"'"'%s'"'"'|\n' "$MODEL_INC" "$MODEL_INC" >> "$_pn_sedscript"
    printf 's|^\*\.lib %s|.lib %s|\n' "$MODEL_LIB" "$MODEL_LIB" >> "$_pn_sedscript"

    # 3. Substitute SPF path and subcircuit tokens
    if [ -n "$_pn_spf" ]; then
        printf 's^.Titan_spf^ %s^\n'   "$_pn_spf" >> "$_pn_sedscript"
        printf 's^.netlist_spf^ %s^\n' "$_pn_spf" >> "$_pn_sedscript"
    fi
    if [ -n "$_pn_subckt" ]; then
        printf 's^.Titan_RO^ %s^\n'    "$_pn_subckt" >> "$_pn_sedscript"
        printf 's^.SUBCKT_PPG^ %s^\n'  "$_pn_subckt" >> "$_pn_sedscript"
    fi

    # 4. Inject PVDD voltage
    if [ -n "$_pn_pvdd" ]; then
        printf 's|\.param PVDD=[0-9][0-9.]*|.param PVDD=%s|\n' "$_pn_pvdd" >> "$_pn_sedscript"
    fi

    # 5. Inject temperature
    if [ -n "$_pn_temp" ]; then
        printf 's|^\.temp[ =]*[-0-9.]*|.temp =%s|\n' "$_pn_temp" >> "$_pn_sedscript"
    fi

    sed -f "$_pn_sedscript" < "$_pn_src" > "$_pn_dst"
    rm -f "$_pn_sedscript"

    verify_model "$_pn_dst"
}

#-----------------------------------------------------------------------------
# process_spf <src> <dst>: Normalises port order and changes slvt -> ulvt
#-----------------------------------------------------------------------------
process_spf() {
    _ps_src=$1 _ps_dst=$2
    sed -e "$_SUBCKT_SED_1" \
        -e "$_SUBCKT_SED_2" \
        -e "$_SUBCKT_SED_3" \
        -e "$_VT_SED_N"     \
        -e "$_VT_SED_P"     \
        < "$_ps_src" > "$_ps_dst"
}

#-----------------------------------------------------------------------------
# process_spf_slvt <src> <dst>: Normalises port order preserving SLVT flavor
#-----------------------------------------------------------------------------
process_spf_slvt() {
    _ps_src=$1 _ps_dst=$2
    sed -e "$_SUBCKT_SED_1" \
        -e "$_SUBCKT_SED_2" \
        -e "$_SUBCKT_SED_3" \
        < "$_ps_src" > "$_ps_dst"
}

#-----------------------------------------------------------------------------
# create_hsp_wrapper <dst_wrapper> <netlist_path> [hspice_bin] [hsp_script]
# Creates executable run_hsp.sh with hardcoded license and tool path.
#-----------------------------------------------------------------------------
create_hsp_wrapper() {
    _cw_wrapper=$1 _cw_netlist=$2
    _cw_bin=${3:-$DEFAULT_HSPICE_BIN}
    _cw_script=${4:-/afs/apd.pok.ibm.com/u/imranyou/for_imran/hsp_2022_new}

    cat > "$_cw_wrapper" << WRAPPER_EOF
#!/bin/ksh
export PATH=${_cw_bin}:\$PATH
export LM_LICENSE_FILE=${_LM_LICENSE}
${_cw_script} ${_cw_netlist}
WRAPPER_EOF
    chmod +x "$_cw_wrapper"
}

#-----------------------------------------------------------------------------
# LIS_FILE <netlist_path>: Returns path to HSPICE measurement output
#-----------------------------------------------------------------------------
LIS_FILE() {
    echo "$1.lis"
}

#-----------------------------------------------------------------------------
# wait_for_jobs <prefix>: Polls LSF queue until all jobs finish
#-----------------------------------------------------------------------------
wait_for_jobs() {
    _wj_prefix=$1
    echo ""
    echo "Waiting for ${_wj_prefix}_* LSF jobs to complete..."
    sleep 10
    while [ "$(bjobs 2>/dev/null | grep -c "${_wj_prefix}_")" -gt 0 ]; do
        printf "."
        sleep 10
    done
    echo ""
    echo "All ${_wj_prefix}_* jobs completed."
}
