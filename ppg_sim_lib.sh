#!/bin/ksh
#=============================================================================
# ppg_sim_lib.sh — Shared library for all PPG simulation scripts
#
# Source this file at the top of any PPG simulation or collection script:
#   . "$SCRIPTDIR/ppg_sim_lib.sh"
#
# Exports:
#   validate_model_params   — verify MODEL_INC / MODEL_LIB / MODEL_NAME are set
#                             and that the files exist on disk; exit 1 if not
#   verify_model <netlist>  — confirm the generated netlist contains exactly one
#                             active design_include.inc line and it matches
#                             MODEL_INC exactly; exit 1 on any mismatch
#   patch_netlist <src> <dst> <spf_path> <subckt> [pvdd]
#                           — sed-patch a template into a ready-to-run netlist,
#                             injecting MODEL_INC/LIB, SPF path, subckt name,
#                             and optionally PVDD; then call verify_model
#   process_spf <src> <dst> — normalise SPF port order and substitute Vt flavour
#                             (slvt→ulvt). For SLVT runs, cp the SPF directly.
#   wait_for_jobs <prefix>  — poll bjobs until no jobs matching <prefix>_ remain
#   LIS_FILE <netlist>      — print the correct .lis path for a given netlist.
#                             hspice -dp writes results to invfo3_mod_dp.lis,
#                             NOT invfo3_mod.sp.lis. Always use this function.
#
# Required env vars (set by caller before sourcing or before calling functions):
#   MODEL_INC   — full path to design_include.inc
#   MODEL_LIB   — full path to fixed_corner.lib
#   MODEL_NAME  — short label, e.g. "v0.6SB", "v0.22", "v1.0"
#
# KNOWN ISSUES (see NOTES.md for full details):
#   - LM_LICENSE_FILE is empty in the login shell on this system. Always use
#     the hardcoded _LM_LICENSE constant defined below in run_hsp.sh wrappers.
#   - hspice -dp writes simulation output to *_dp.lis, not *.sp.lis.
#     Use the LIS_FILE helper to get the correct path.
#   - `local` is not available in /bin/ksh — use prefixed globals instead.
#   - For SLVT runs, copy SPF files directly; process_spf substitutes slvt→ulvt
#     which is only correct for ULVT runs.
#=============================================================================

# Hardcoded license string — LM_LICENSE_FILE is empty in this login environment.
# Verified working from full_dut/run/7TSL_INVX2/run_hsp.sh. (See NOTES.md §1)
_LM_LICENSE='27020@riclic.pok.ibm.com:27020@poklnxlic04.pok.ibm.com:27020@cdsserv1.pok.ibm.com:27020@cdsserv2.pok.ibm.com:27020@cdsserv3.pok.ibm.com'

#-----------------------------------------------------------------------------
# SPF port-order normalisation and Vt substitution patterns.
# Used by process_spf(); defined here so every script shares them.
#-----------------------------------------------------------------------------
_SUBCKT_SED_1='s/\.SUBCKT \([0-9a-zA-Z*_]*\) Z VDD A VSS/.SUBCKT \1 VSS VDD A Z/g'
_SUBCKT_SED_2='s/\.SUBCKT \([0-9a-zA-Z*_]*\) VDD Z A VSS/.SUBCKT \1 VSS VDD A Z/g'
_SUBCKT_SED_3='s/\.SUBCKT \([0-9a-zA-Z*_]*\) A VDD Z VSS/.SUBCKT \1 VSS VDD A Z/g'
_VT_SED_N='s^.slvtnfet^ ulvtnfet^'
_VT_SED_P='s^.slvtpfet^ ulvtpfet^'

#-----------------------------------------------------------------------------
# validate_model_params
#   Verify MODEL_INC, MODEL_LIB, MODEL_NAME are all set and the files exist.
#   Prints a confirmation on success; exits 1 on any failure.
#-----------------------------------------------------------------------------
validate_model_params() {
    if [ -z "$MODEL_INC" ] || [ -z "$MODEL_LIB" ] || [ -z "$MODEL_NAME" ]; then
        echo "ERROR: MODEL_INC, MODEL_LIB, and MODEL_NAME must all be set." >&2
        echo "  MODEL_INC  = full path to design_include.inc" >&2
        echo "  MODEL_LIB  = full path to fixed_corner.lib" >&2
        echo "  MODEL_NAME = short label, e.g. v0.6SB  v0.22  v1.0" >&2
        echo "" >&2
        echo "  Example:" >&2
        echo "    MODEL_INC='/afs/.../Spice-XXXXXX/design_include.inc' \\" >&2
        echo "    MODEL_LIB='/afs/.../Spice-XXXXXX/fixed_corner.lib' \\" >&2
        echo "    MODEL_NAME='vX.Y' \\" >&2
        echo "    ksh <script_name>" >&2
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
    echo "Model parameters validated:"
    echo "  MODEL_NAME = $MODEL_NAME"
    echo "  MODEL_INC  = $MODEL_INC"
    echo "  MODEL_LIB  = $MODEL_LIB"
}

#-----------------------------------------------------------------------------
# verify_model <netlist>
#   Read back a generated netlist and confirm:
#     1. Exactly one active design_include.inc line is present
#     2. Exactly one active fixed_corner.lib line is present
#     3. The design_include.inc line matches MODEL_INC exactly
#   Exits 1 on any failure so no job is submitted with a wrong model.
#-----------------------------------------------------------------------------
verify_model() {
    _vm_netlist=$1
    _vm_inc_count=$(grep -c "^\.inc.*design_include\.inc" "$_vm_netlist" 2>/dev/null || echo 0)
    _vm_lib_count=$(grep -c "^\.lib.*fixed_corner\.lib"   "$_vm_netlist" 2>/dev/null || echo 0)

    if [ "$_vm_inc_count" -eq 0 ]; then
        echo "ERROR: No active model .inc (design_include.inc) in: $_vm_netlist" >&2
        echo "  Active .inc lines found:" >&2
        grep "^\.inc" "$_vm_netlist" >&2
        exit 1
    fi
    if [ "$_vm_inc_count" -gt 1 ]; then
        echo "ERROR: Multiple active model .inc lines in: $_vm_netlist" >&2
        grep "^\.inc.*design_include\.inc" "$_vm_netlist" >&2
        exit 1
    fi
    if [ "$_vm_lib_count" -eq 0 ]; then
        echo "ERROR: No active model .lib (fixed_corner.lib) in: $_vm_netlist" >&2
        echo "  Active .lib lines found:" >&2
        grep "^\.lib" "$_vm_netlist" >&2
        exit 1
    fi

    _vm_active_inc=$(grep "^\.inc.*design_include\.inc" "$_vm_netlist")
    if ! echo "$_vm_active_inc" | grep -qF "$MODEL_INC"; then
        echo "ERROR: Model mismatch in: $_vm_netlist" >&2
        echo "  Expected MODEL_INC : $MODEL_INC" >&2
        echo "  Active .inc in file: $_vm_active_inc" >&2
        exit 1
    fi
}

#-----------------------------------------------------------------------------
# patch_netlist <src_template> <dst_netlist> <spf_path> <subckt> [pvdd]
#   Produce a ready-to-run netlist from a template by:
#     - Commenting out every active .inc/.lib pair (lines not starting with *)
#     - Uncommenting the .inc line containing MODEL_INC and its paired .lib line
#     - Substituting .Titan_spf / .netlist_spf token -> <spf_path>
#     - Substituting .Titan_RO  / .SUBCKT_PPG  token -> <subckt>
#     - Setting .param PVDD=<pvdd> when pvdd arg is supplied
#   Then calls verify_model to confirm the result before returning.
#
#   The block/unblock approach is required because the template contains many
#   commented model pairs.  Swapping only the path inside an active line can
#   activate the wrong .lib if the target pair lives in a different sandbox.
#-----------------------------------------------------------------------------
patch_netlist() {
    _pn_src=$1 _pn_dst=$2 _pn_spf=$3 _pn_subckt=$4 _pn_pvdd=$5

    # Build the sed script in a temp file to avoid quoting/eval issues in ksh
    _pn_sedscript=$(mktemp /tmp/ppg_patch_XXXXXX.sed)

    # Step 1: Comment out every currently-active model .inc and .lib line
    #   Use address/substitution form to prepend * — avoids backreference quoting issues
    printf '/^\.inc '"'"'.*design_include\.inc/s/^\./\*./\n' >> "$_pn_sedscript"
    printf '/^\.lib .*fixed_corner\.lib/s/^\./\*./\n'        >> "$_pn_sedscript"

    # Step 2: Uncomment the .inc line whose path contains MODEL_INC
    printf 's|^\*\.inc '"'"'%s'"'"'|.inc '"'"'%s'"'"'|\n' "$MODEL_INC" "$MODEL_INC" >> "$_pn_sedscript"

    # Step 3: Uncomment the .lib line whose path contains MODEL_LIB
    printf 's|^\*\.lib %s|.lib %s|\n' "$MODEL_LIB" "$MODEL_LIB" >> "$_pn_sedscript"

    # Inject SPF path (covers both token variants)
    if [ -n "$_pn_spf" ]; then
        printf 's^.Titan_spf^ %s^\n'    "$_pn_spf"    >> "$_pn_sedscript"
        printf 's^.netlist_spf^ %s^\n'  "$_pn_spf"    >> "$_pn_sedscript"
    fi

    # Inject subcircuit name (covers both token variants)
    if [ -n "$_pn_subckt" ]; then
        printf 's^.Titan_RO^ %s^\n'    "$_pn_subckt"  >> "$_pn_sedscript"
        printf 's^.SUBCKT_PPG^ %s^\n'  "$_pn_subckt"  >> "$_pn_sedscript"
    fi

    # Inject PVDD if supplied
    if [ -n "$_pn_pvdd" ]; then
        printf 's|\.param PVDD=[0-9][0-9.]*|.param PVDD=%s|\n' "$_pn_pvdd" >> "$_pn_sedscript"
    fi

    sed -f "$_pn_sedscript" < "$_pn_src" > "$_pn_dst"
    rm -f "$_pn_sedscript"

    verify_model "$_pn_dst"
}

#-----------------------------------------------------------------------------
# process_spf <src_spf> <dst_spf>
#   Normalise SUBCKT port order to VSS VDD A Z and substitute slvt->ulvt.
#   Use for ULVT runs only.
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
# process_spf_slvt <src_spf> <dst_spf>
#   Normalise SUBCKT port order to VSS VDD A Z without substituting slvt->ulvt.
#   Use for SLVT runs — reorders terminals but preserves slvt device names.
#   See NOTES.md §5 and §8.
#-----------------------------------------------------------------------------
process_spf_slvt() {
    _ps_src=$1 _ps_dst=$2
    sed -e "$_SUBCKT_SED_1" \
        -e "$_SUBCKT_SED_2" \
        -e "$_SUBCKT_SED_3" \
        < "$_ps_src" > "$_ps_dst"
}

#-----------------------------------------------------------------------------
# LIS_FILE <netlist_path>
#   Print the path of the file containing hspice .measure results.
#   On this cluster hspice -dp always prints "DP feature limitation, DP ignored"
#   and falls back to single-process mode.  Results are therefore written to
#   invfo3_mod.sp.lis (the standard .lis), NOT invfo3_mod_dp.lis.
#   See NOTES.md §2 for the full explanation.
#-----------------------------------------------------------------------------
LIS_FILE() {
    # Return the standard .sp.lis path (DP is always ignored on this cluster)
    echo "$1.lis"
}

#-----------------------------------------------------------------------------
# wait_for_jobs <prefix>
#   Poll bjobs every 10 seconds until no running/pending jobs whose name
#   starts with <prefix>_ remain.  Prints a dot for each poll cycle.
#-----------------------------------------------------------------------------
wait_for_jobs() {
    _wj_prefix=$1
    echo ""
    echo "Waiting for ${_wj_prefix}_* LSF jobs to finish..."
    sleep 15
    while [ "$(bjobs 2>/dev/null | grep -c "${_wj_prefix}_")" -gt 0 ]; do
        printf "."
        sleep 10
    done
    echo ""
    echo "All ${_wj_prefix}_* jobs finished."
}
