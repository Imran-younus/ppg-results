#!/bin/ksh
#=============================================================================
# ppg_run.sh — Interactive PPG Simulation Launcher
#=============================================================================
#
# ── QUICK START ───────────────────────────────────────────────────────────────
#
#   Open a terminal in the simulation directory and run:
#
#       ksh ppg_run.sh
#
#   The script will ask you questions one at a time.
#   Press Enter to accept the default value shown in [brackets].
#
# ── WHAT THE SCRIPT DOES ──────────────────────────────────────────────────────
#
#   1. Asks you a series of questions (see PROMPTS section below).
#   2. Shows you a summary of what it is about to run.
#   3. Asks "Proceed? (yes/no)" — nothing is submitted until you say yes.
#   4. Submits HSPICE simulation jobs to the LSF cluster.
#   5. Waits for all jobs to finish.
#   6. Collects results into a text file.
#   7. Optionally commits and pushes results to GitHub.
#
# ── PROMPTS — what you will be asked ─────────────────────────────────────────
#
#   Step 1 — Simulation mode
#       single  →  Single-stage VDD sweep (the standard 24-cell, 5-metric run)
#       chain   →  101-stage full DUT ring oscillator (any layout SPF, any model)
#
#   Step 2 — Model parameters
#       Model name  : Short label you choose, e.g.  v0.6SB  or  v0.7RC1
#                     Known labels auto-resolve INC/LIB: v0.43, v0.53, v0.6SB, v0.6SB2
#                     This label appears in result filenames and on the website.
#       INC path    : Only prompted for UNKNOWN model labels.
#                     Known models (above) skip this prompt entirely.
#                     Must be the full path to design_include.inc.
#       LIB path    : Only prompted for UNKNOWN model labels.
#                     MUST be from the same sandbox folder as the INC file.
#       The script will warn you if INC and LIB appear to be from different
#       sandbox directories (which would produce incorrect mixed-model results).
#
#   Step 3 — Vt flavor
#       Choose from the numbered menu (e.g. 1 for slvt, 2 for ulvt).
#       You can also type the key directly (e.g. slvt).
#       Default is slvt.
#       Note: chain mode only supports slvt at this time.
#
#   Step 4 — VDD (supply voltage)
#       sweep       →  Full 14-point sweep from 0.5 V to 1.15 V  [default for single]
#       0.70        →  Single voltage point
#       0.6 0.7 0.8 →  Space-separated list of specific voltages
#       Chain mode default is 0.70 V; sweep and lists are also supported.
#
#   Step 5 — Temperature
#       Integer in degrees Celsius.  Default is 25.
#       Examples: 25  125  -40
#
#   Step 6 — Track height filter  (single-stage mode only; skipped in chain mode)
#       all  →  Run all track heights (6T, 7T, 8T)  [default]
#       6T   →  6-track cells only
#       7T   →  7-track cells only
#       8T   →  8-track cells only
#
#   Step 6 — Chain layout inputs  (chain mode only; skipped in single-stage mode)
#       Cell name   : Must match the .SUBCKT name in the layout SPF exactly.
#                     Default: NAND2_X1_5T_125H_RX15_F03_SLVT_B_M2
#       SPF path    : Ported layout SPF with ENA VSS VDD RO_OUT port order
#                     and 4 R_PORT_* bridges. Relative paths are resolved from
#                     the workspace root.
#                     Default: extraction/reext_F03/NAND2_X1_5T_125H_RX15_F03_SLVT_B_M2_ported.spf
#       Stages      : Number of ring oscillator stages. Default: 101
#
#   Step 7 — Cell type filter  (single-stage mode only)
#       all   →  All cell types  [default]
#       INV   →  Inverters only
#       NAND  →  NAND gates only  (NAND2B, NAND2T, NAND3B, NAND3T)
#       NOR   →  NOR gates only   (NOR2B, NOR2T)
#       AOI   →  AOI gates only   (AOI21, AOI22)
#       OAI   →  OAI gates only   (OAI21, OAI22)
#       Combining track + cell filters works: e.g. 7T + NAND → runs only
#       7TSL_NAND2B and 7TSL_NAND3B.
#
#   Step 8 — GitHub push
#       yes  →  After results are collected, commit and push to GitHub  [default]
#       no   →  Skip — results are saved locally only
#
# ── RESULT FILES ─────────────────────────────────────────────────────────────
#
#   All result files are written to the results/ directory (workspace root).
#
#   Single-stage full sweep → results/PPGRO_chain_menu14_<MODEL>_<VT>.txt
#   Single-stage partial    → results/PPGRO_chain_<MODEL>_<VT>_results.txt
#   101-stage chain         → results/results_dut_<MODEL>_<CELL>.txt
#                             (also printed to the terminal as a table on completion)
#
# ── HOW TO ADD NEW OPTIONS IN FUTURE ─────────────────────────────────────────
#
#   All configurable lists are defined right below this comment block,
#   in clearly labelled sections.  To add a new option:
#
#   New Vt flavor (e.g. ZVT):
#       Open ppg_run.sh, find the VT_OPTIONS block, add one line:
#           zvt    ZVT    (Zero-Vt)
#       That's it.  The menu, validation, and filename logic all pick it up
#       automatically.
#
#   New track height (e.g. 9T):
#       Find the TRACK_OPTIONS block, add one line:
#           9T   9-track cells only
#       Then add the 9T cells to PPG_STD_CELLS_24 in ppg_sim_lib.sh.
#
#   New cell type filter (e.g. MUX):
#       Find the CELLTYPE_OPTIONS block, add one line:
#           MUX    MUX gates only
#       Then add the MUX cells to PPG_STD_CELLS_24 in ppg_sim_lib.sh.
#
#   No changes to any other part of the script are needed.
#
# ── TROUBLESHOOTING ───────────────────────────────────────────────────────────
#
#   "File not found" on INC or LIB path  (only shown for unknown models)
#       → Check the path is correct and the filesystem is mounted.
#         Known models (v0.43/v0.53/v0.6SB/v0.6SB2) never show this — paths are built in.
#
#   "SPF not found" error in chain mode
#       → The SPF path you entered does not exist. Default is:
#         extraction/reext_F03/NAND2_X1_5T_125H_RX15_F03_SLVT_B_M2_ported.spf
#         Relative paths are resolved from the workspace root automatically.
#
#   "No active design_include.inc" error in chain mode
#       → The model block in full_dut/PPG_ROM_base.sp uses a different path prefix
#         than MODEL_INC. See NOTES.md Issue 38. All 4 known models are already fixed.
#
#   "Sandbox mismatch" warning
#       → INC and LIB are from different Spice-*-sandbox directories.
#         This will produce wrong results.  Use matching paths.
#
#   Jobs finish but results show "failed"  (single-stage mode)
#       → Check the .lis file in the cell run directory:
#         cat run_vdd_<MODEL>_slvt/0_7/<CELL>/invfo3_mod.sp.lis | grep -i fail
#         See NOTES.md for the full debugging checklist.
#
#   Chain results show "-" or "MISSING"
#       → The LSF job may have landed on a wrong node (no HSPICE). Check:
#         cat full_dut/run_dut_<MODEL>_<CELL>/<vdd_tag>/invfo3_mod.sp.lis | head -5
#         "Error : HSPICE is not supported on linux currently" = wrong node (NOTES.md Issue 19)
#
#   GitHub push fails
#       → Verify the token file exists:
#         cat /afs/apd.pok.ibm.com/u/imranyou/.github_token
#         It should contain a line:  GITHUB_TOKEN=ghp_...
#
#=============================================================================

SCRIPTDIR=$(cd "$(dirname "$0")" && pwd)
GITHUB_TOKEN_FILE='/afs/apd.pok.ibm.com/u/imranyou/.github_token'
GITHUB_REMOTE='https://github.com/Imran-younus/ppg-results.git'

#=============================================================================
# ── CONFIGURABLE LISTS — extend these as new options become available ──
#=============================================================================

# All supported Vt flavors (add new ones here)
VT_OPTIONS="
slvt   SLVT   (Standard Low-Vt — default)
ulvt   ULVT   (Ultra Low-Vt)
lvt    LVT    (Low-Vt)
svt    SVT    (Standard-Vt)
hvt    HVT    (High-Vt)
elvt   ELVT   (Extremely Low-Vt)
zulvt  ZULVT  (Zero Ultra Low-Vt)
"

# All supported track heights (add new ones here)
TRACK_OPTIONS="
all  All track heights
6T   6-track cells only
7T   7-track cells only
8T   8-track cells only
"

# All supported cell type filters (add new ones here)
CELLTYPE_OPTIONS="
all    All cell types
INV    Inverters only
NAND   NAND gates only   (NAND2B, NAND2T, NAND3B, NAND3T)
NOR    NOR gates only    (NOR2B, NOR2T)
AOI    AOI gates only    (AOI21, AOI22)
OAI    OAI gates only    (OAI21, OAI22)
"

# Simulation modes
MODE_OPTIONS="
single   Single-stage VDD sweep (24 cells, 5 metrics each)
chain    101-stage full DUT ring oscillator (any layout SPF, any model)
"

#=============================================================================
# ── HELPERS ───────────────────────────────────────────────────────────
#=============================================================================

# Print a section header
hdr() { echo ""; echo "──────────────────────────────────────────"; echo "  $1"; echo "──────────────────────────────────────────"; }

# Prompt: ask(variable_name, question, default)
ask() {
    _ask_var=$1; _ask_q=$2; _ask_def=$3
    if [ -n "$_ask_def" ]; then
        printf "  %s [%s]: " "$_ask_q" "$_ask_def"
    else
        printf "  %s: " "$_ask_q"
    fi
    read _ask_ans
    [ -z "$_ask_ans" ] && _ask_ans="$_ask_def"
    eval "$_ask_var=\$_ask_ans"
}

# Print a numbered menu from a config block and return the chosen key
# Usage: pick_from_list VARNAME "label" "$OPTIONS_VAR"
# OPTIONS_VAR: each non-blank line is "key  description..."
pick_from_list() {
    _pfl_var=$1; _pfl_label=$2; _pfl_opts=$3
    echo ""
    echo "  $( echo "$_pfl_label" | tr '[:lower:]' '[:upper:]' ) options:"
    _pfl_n=0
    _pfl_keys=""
    echo "$_pfl_opts" | while read _pfl_line; do
        [ -z "$_pfl_line" ] && continue
        _pfl_n=$((_pfl_n+1))
        _pfl_key=$(echo "$_pfl_line" | awk '{print $1}')
        _pfl_desc=$(echo "$_pfl_line" | cut -d' ' -f2-)
        printf "    %d) %-8s %s\n" "$_pfl_n" "$_pfl_key" "$_pfl_desc"
    done
    printf "  Enter number or key: "
    read _pfl_choice

    # Resolve by number or direct key match
    _pfl_result=""
    _pfl_n=0
    echo "$_pfl_opts" | while read _pfl_line; do
        [ -z "$_pfl_line" ] && continue
        _pfl_n=$((_pfl_n+1))
        _pfl_key=$(echo "$_pfl_line" | awk '{print $1}')
        if [ "$_pfl_choice" = "$_pfl_n" ] || [ "$_pfl_choice" = "$_pfl_key" ]; then
            echo "$_pfl_key"
            return
        fi
    done | { read _pfl_result; eval "$_pfl_var=\$_pfl_result"; }
    # ksh subshell workaround: re-run resolution in current shell
    _pfl_n=0
    _pfl_result=""
    echo "$_pfl_opts" | while IFS= read -r _pfl_line; do
        [ -z "$_pfl_line" ] && continue
        _pfl_n=$((_pfl_n+1))
        _pfl_key=$(echo "$_pfl_line" | awk '{print $1}')
        if [ "$_pfl_choice" = "$_pfl_n" ] || [ "$(echo "$_pfl_choice" | tr '[:upper:]' '[:lower:]')" = "$(echo "$_pfl_key" | tr '[:upper:]' '[:lower:]')" ]; then
            _pfl_result="$_pfl_key"
        fi
    done
    eval "$_pfl_var=\$_pfl_result"
}

# Validate that a key exists in an options block
key_in_list() {
    _kil_key=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    _kil_opts=$2
    echo "$_kil_opts" | while IFS= read -r _kil_line; do
        [ -z "$_kil_line" ] && continue
        _kil_k=$(echo "$_kil_line" | awk '{print $1}' | tr '[:upper:]' '[:lower:]')
        [ "$_kil_k" = "$_kil_key" ] && echo "yes" && return
    done | grep -q "yes" && return 0 || return 1
}

# Filter PPG_STD_CELLS_24 by track height and cell type
# Returns a space-separated list of matching label strings (printed to stdout)
build_cell_filter() {
    _bcf_track=$1   # e.g. "all", "6T", "7T", "8T"
    _bcf_type=$2    # e.g. "all", "INV", "NAND", "NOR", "AOI", "OAI"
    . "$SCRIPTDIR/ppg_sim_lib.sh"
    echo "$PPG_STD_CELLS_24" | while IFS= read -r _bcf_line; do
        [ -z "$_bcf_line" ] && continue
        _bcf_label=$(echo "$_bcf_line" | awk '{print $1}')
        [ -z "$_bcf_label" ] && continue

        # Track height filter: "7T" matches "7TSL_*"
        if [ "$(echo "$_bcf_track" | tr '[:upper:]' '[:lower:]')" != "all" ]; then
            echo "$_bcf_label" | grep -qi "^${_bcf_track}SL_" || continue
        fi

        # Cell type filter: "NAND" matches "*_NAND*"
        if [ "$(echo "$_bcf_type" | tr '[:upper:]' '[:lower:]')" != "all" ]; then
            echo "$_bcf_label" | grep -qi "_${_bcf_type}" || continue
        fi

        printf "%s " "$_bcf_label"
    done
}

# Push to GitHub
do_git_push() {
    if [ ! -f "$GITHUB_TOKEN_FILE" ]; then
        echo "  WARNING: Token file not found: $GITHUB_TOKEN_FILE — skipping push." >&2
        return 1
    fi
    _push_token=$(grep "^GITHUB_TOKEN=" "$GITHUB_TOKEN_FILE" | cut -d= -f2)
    if [ -z "$_push_token" ]; then
        echo "  WARNING: GITHUB_TOKEN not found in token file — skipping push." >&2
        return 1
    fi
    echo "  Pushing to GitHub..."
    git -C "$SCRIPTDIR" push "https://${_push_token}@${GITHUB_REMOTE#https://}" main 2>&1
}

#=============================================================================
# ── MAIN FLOW ─────────────────────────────────────────────────────────
#=============================================================================

clear
echo "=============================================="
echo "  PPG Simulation Launcher"
echo "  $(date)"
echo "=============================================="

# ── Step 1: Simulation mode ────────────────────────────────────────
hdr "Step 1: Simulation Mode"
echo "$MODE_OPTIONS" | while IFS= read -r _l; do [ -z "$_l" ] && continue
    _k=$(echo "$_l"|awk '{print $1}'); _d=$(echo "$_l"|cut -d' ' -f2-)
    printf "    %-10s %s\n" "$_k" "$_d"; done
printf "  Enter mode [single]: "
read SIM_MODE
SIM_MODE="${SIM_MODE:-single}"
SIM_MODE=$(echo "$SIM_MODE" | tr '[:upper:]' '[:lower:]')
if [ "$SIM_MODE" != "single" ] && [ "$SIM_MODE" != "chain" ]; then
    echo "ERROR: Invalid mode '$SIM_MODE'. Choose 'single' or 'chain'." >&2; exit 1
fi

# ── Step 2: Model parameters ───────────────────────────────────────
hdr "Step 2: Model Parameters"
echo "  Known models (paths auto-resolved): v0.43, v0.53, v0.6SB, v0.6SB2"
echo "  For other models, you will be prompted for INC and LIB paths."
ask MODEL_NAME "Model name" ""
[ -z "$MODEL_NAME" ] && echo "ERROR: Model name is required." >&2 && exit 1

# Auto-resolve known PDK model paths
case "$MODEL_NAME" in
    v0.43|rpdk0.43|RPDK0.43)
        MODEL_NAME="v0.43"
        MODEL_INC='/afs/apd/ant/cte_tech/1p4/IIMmintaka/common/pdk/IIM/SpiceModel_V0.430/Hspice/design_include.inc'
        MODEL_LIB='/afs/apd/ant/cte_tech/1p4/IIMmintaka/common/pdk/IIM/SpiceModel_V0.430/Hspice/fixed_corner.lib'
        echo "  Auto-resolved v0.43 (RPDK0.43 SpiceModel_V0.430)"
        ;;
    v0.53|tpdk0.53|TPDK0.53)
        MODEL_NAME="v0.53"
        MODEL_INC='/afs/apd/ant/research/prod/2HP/V0.51/Spice/design_include.inc'
        MODEL_LIB='/afs/apd/ant/research/prod/2HP/V0.51/Spice/fixed_corner.lib'
        echo "  Auto-resolved v0.53 (TPDK0.53 Spice-V0.51-prod)"
        ;;
    v0.6SB|v0p6SB)
        MODEL_NAME="v0.6SB"
        MODEL_INC='/afs/apd/ant/research/test/2HP/v0.53/Spice-260724-sandbox/design_include.inc'
        MODEL_LIB='/afs/apd/ant/research/test/2HP/v0.53/Spice-260724-sandbox/fixed_corner.lib'
        echo "  Auto-resolved v0.6SB (Spice-260724-sandbox)"
        ;;
    v0.6SB2|v0p6SB2)
        MODEL_NAME="v0.6SB2"
        MODEL_INC='/afs/apd/ant/research/test/2HP/v0.53/Spice-260604-sandbox/design_include.inc'
        MODEL_LIB='/afs/apd/ant/research/test/2HP/v0.53/Spice-260604-sandbox/fixed_corner.lib'
        echo "  Auto-resolved v0.6SB2 (Spice-260604-sandbox)"
        ;;
    *)
        ask MODEL_INC "Path to design_include.inc" ""
        [ -z "$MODEL_INC" ] && echo "ERROR: MODEL_INC is required for unknown model." >&2 && exit 1
        [ ! -f "$MODEL_INC" ] && echo "ERROR: File not found: $MODEL_INC" >&2 && exit 1
        ask MODEL_LIB "Path to fixed_corner.lib" ""
        [ -z "$MODEL_LIB" ] && echo "ERROR: MODEL_LIB is required for unknown model." >&2 && exit 1
        [ ! -f "$MODEL_LIB" ] && echo "ERROR: File not found: $MODEL_LIB" >&2 && exit 1
        ;;
esac

# Warn if inc and lib are from different sandboxes
_inc_sandbox=$(echo "$MODEL_INC" | grep -o 'Spice-[0-9]*-sandbox' || echo "")
_lib_sandbox=$(echo "$MODEL_LIB" | grep -o 'Spice-[0-9]*-sandbox' || echo "")
if [ -n "$_inc_sandbox" ] && [ -n "$_lib_sandbox" ] && [ "$_inc_sandbox" != "$_lib_sandbox" ]; then
    echo ""
    echo "  WARNING: INC and LIB appear to be from different sandboxes!"
    echo "    INC sandbox: $_inc_sandbox"
    echo "    LIB sandbox: $_lib_sandbox"
    printf "  Continue anyway? (yes/no) [no]: "
    read _mismatch_ok
    [ "${_mismatch_ok:-no}" != "yes" ] && echo "Aborted." && exit 1
fi

# ── Step 3: Vt flavor ──────────────────────────────────────────────
hdr "Step 3: Vt Flavor"
echo "$VT_OPTIONS" | while IFS= read -r _l; do [ -z "$_l" ] && continue
    _k=$(echo "$_l"|awk '{print $1}'); _d=$(echo "$_l"|cut -d' ' -f2-)
    printf "    %-8s %s\n" "$_k" "$_d"; done
printf "  Enter Vt flavor [slvt]: "
read VT_CHOICE
VT_CHOICE=$(echo "${VT_CHOICE:-slvt}" | tr '[:upper:]' '[:lower:]')
if ! key_in_list "$VT_CHOICE" "$VT_OPTIONS"; then
    echo "ERROR: Unknown Vt flavor '$VT_CHOICE'." >&2; exit 1
fi

# Chain mode only supports SLVT currently
if [ "$SIM_MODE" = "chain" ] && [ "$VT_CHOICE" != "slvt" ]; then
    echo ""
    echo "  NOTE: 101-stage chain script currently only has SPF paths for SLVT."
    echo "        Vt will be set to 'slvt' for this run."
    VT_CHOICE="slvt"
fi

# ── Step 4: VDD ────────────────────────────────────────────────────
hdr "Step 4: Supply Voltage (VDD)"
if [ "$SIM_MODE" = "single" ]; then
    echo "  Options:"
    echo "    sweep      Full 14-point sweep (0.5V – 1.15V)  [default]"
    echo "    0.70       Any single voltage (e.g. 0.70)"
    echo "    0.6 0.7    Space-separated list of voltages"
    ask VDD_CHOICE "VDD" "sweep"
else
    echo "  Chain mode simulates one VDD at a time."
    ask VDD_CHOICE "VDD" "0.70"
fi

# ── Step 5: Temperature ────────────────────────────────────────────
hdr "Step 5: Temperature"
ask TEMP_CHOICE "Temperature in °C" "25"
echo "$TEMP_CHOICE" | grep -qE '^-?[0-9]+$' || { echo "ERROR: Temperature must be an integer." >&2; exit 1; }

# ── Step 6: Track height filter (single) / Chain layout inputs (chain) ─
if [ "$SIM_MODE" = "single" ]; then
    hdr "Step 6: Track Height Filter"
    echo "$TRACK_OPTIONS" | while IFS= read -r _l; do [ -z "$_l" ] && continue
        _k=$(echo "$_l"|awk '{print $1}'); _d=$(echo "$_l"|cut -d' ' -f2-)
        printf "    %-6s %s\n" "$_k" "$_d"; done
    printf "  Enter track height [all]: "
    read TRACK_CHOICE
    TRACK_CHOICE="${TRACK_CHOICE:-all}"
else
    hdr "Step 6: Chain Layout Inputs"
    _default_cell="NAND2_X1_5T_125H_RX15_F03_SLVT_B_M2"
    _default_spf="extraction/reext_F03/NAND2_X1_5T_125H_RX15_F03_SLVT_B_M2_ported.spf"
    ask CHAIN_CELL "Layout cell name (.SUBCKT name in SPF)" "$_default_cell"
    ask CHAIN_SPF  "Path to ported layout SPF"              "$_default_spf"
    # Resolve relative SPF path from workspace root
    case "$CHAIN_SPF" in
        /*) ;;
        *)  CHAIN_SPF="$SCRIPTDIR/$CHAIN_SPF" ;;
    esac
    [ ! -f "$CHAIN_SPF" ] && echo "ERROR: SPF not found: $CHAIN_SPF" >&2 && exit 1
    ask CHAIN_STAGES "Number of ring stages" "101"
    echo "$CHAIN_STAGES" | grep -qE '^[0-9]+$' || { echo "ERROR: Stages must be a positive integer." >&2; exit 1; }
fi

# ── Step 7: Cell type filter (single-stage only) ───────────────────
if [ "$SIM_MODE" = "single" ]; then
    hdr "Step 7: Cell Type Filter"
    echo "$CELLTYPE_OPTIONS" | while IFS= read -r _l; do [ -z "$_l" ] && continue
        _k=$(echo "$_l"|awk '{print $1}'); _d=$(echo "$_l"|cut -d' ' -f2-)
        printf "    %-8s %s\n" "$_k" "$_d"; done
    printf "  Enter cell type [all]: "
    read CELLTYPE_CHOICE
    CELLTYPE_CHOICE="${CELLTYPE_CHOICE:-all}"
fi

# ── Step 8: Post-run GitHub push ───────────────────────────────────
hdr "Step 8: GitHub Push"
printf "  Push results to GitHub after completion? (yes/no) [yes]: "
read PUSH_CHOICE
PUSH_CHOICE="${PUSH_CHOICE:-yes}"

# ── Confirmation summary ───────────────────────────────────────────
echo ""
echo "=============================================="
echo "  Simulation Summary"
echo "=============================================="
echo "  Mode        : $SIM_MODE"
echo "  Model       : $MODEL_NAME"
echo "  INC         : $MODEL_INC"
echo "  LIB         : $MODEL_LIB"
echo "  Vt flavor   : $VT_CHOICE"
echo "  VDD         : $VDD_CHOICE"
echo "  Temperature : ${TEMP_CHOICE} °C"
if [ "$SIM_MODE" = "single" ]; then
echo "  Track filter: $TRACK_CHOICE"
echo "  Cell filter : $CELLTYPE_CHOICE"
else
echo "  Chain cell  : $CHAIN_CELL"
echo "  Chain SPF   : $CHAIN_SPF"
echo "  Stages      : $CHAIN_STAGES"
fi
echo "  GitHub push : $PUSH_CHOICE"
echo "=============================================="
printf "  Proceed? (yes/no) [yes]: "
read CONFIRM
CONFIRM="${CONFIRM:-yes}"
[ "$CONFIRM" != "yes" ] && echo "Aborted." && exit 0

echo ""
echo "Starting simulation — $(date)"

#=============================================================================
# ── RUN: SINGLE-STAGE MODE ────────────────────────────────────────────
#=============================================================================
if [ "$SIM_MODE" = "single" ]; then

    # Build cell filter string and export as CELL_FILTER env var
    # run_ppg_sim.sh checks CELL_FILTER if set and skips non-matching cells
    CELL_FILTER=$(build_cell_filter "$TRACK_CHOICE" "$CELLTYPE_CHOICE")
    CELL_FILTER=$(echo "$CELL_FILTER" | xargs)  # trim whitespace

    if [ -z "$CELL_FILTER" ]; then
        echo "ERROR: No cells match track='$TRACK_CHOICE' type='$CELLTYPE_CHOICE'." >&2
        exit 1
    fi

    echo "  Cells to simulate: $CELL_FILTER"
    echo ""

    MODEL_NAME="$MODEL_NAME" \
    MODEL_INC="$MODEL_INC" \
    MODEL_LIB="$MODEL_LIB" \
    VDD="$VDD_CHOICE" \
    TEMP="$TEMP_CHOICE" \
    VT="$VT_CHOICE" \
    CELL_FILTER="$CELL_FILTER" \
    ksh "$SCRIPTDIR/run_ppg_sim.sh"

    _exit=$?
    if [ "$_exit" -ne 0 ]; then
        echo "ERROR: run_ppg_sim.sh exited with code $_exit." >&2
        exit "$_exit"
    fi

    # Git add results file and push
    if [ "$PUSH_CHOICE" = "yes" ]; then
        _results_file="$SCRIPTDIR/results/PPGRO_chain_menu14_${MODEL_NAME}_${VT_CHOICE}.txt"
        [ "$VDD_CHOICE" != "sweep" ] && _results_file="$SCRIPTDIR/results/PPGRO_chain_${MODEL_NAME}_${VT_CHOICE}_results.txt"
        git -C "$SCRIPTDIR" add "$_results_file" index.html 2>/dev/null
        git -C "$SCRIPTDIR" diff --cached --quiet || \
            git -C "$SCRIPTDIR" commit -m "Single-stage sim results: $MODEL_NAME $VT_CHOICE VDD=$VDD_CHOICE T=${TEMP_CHOICE}C"
        do_git_push
    fi

#=============================================================================
# ── RUN: 101-STAGE CHAIN MODE ─────────────────────────────────────────
#=============================================================================
else

    _chain_results="$SCRIPTDIR/results/results_dut_${MODEL_NAME}_${CHAIN_CELL}.txt"

    ksh "$SCRIPTDIR/full_dut/run_ppg_dut.sh" \
        -c "$CHAIN_CELL" \
        -s "$CHAIN_SPF" \
        -m "$MODEL_NAME" \
        -i "$MODEL_INC" \
        -l "$MODEL_LIB" \
        -v "$VDD_CHOICE" \
        -t "$TEMP_CHOICE" \
        -n "$CHAIN_STAGES" \
        -o "$_chain_results"

    _exit=$?
    if [ "$_exit" -ne 0 ]; then
        echo "ERROR: run_ppg_dut.sh exited with code $_exit." >&2
        exit "$_exit"
    fi

    echo ""
    echo "Results saved to: $_chain_results"

    # Git add chain results and push
    if [ "$PUSH_CHOICE" = "yes" ]; then
        git -C "$SCRIPTDIR" add "$_chain_results" 2>/dev/null
        git -C "$SCRIPTDIR" diff --cached --quiet || \
            git -C "$SCRIPTDIR" commit -m "Chain sim results: $MODEL_NAME $CHAIN_CELL SLVT VDD=${VDD_CHOICE}V T=${TEMP_CHOICE}C"
        do_git_push
    fi

fi

echo ""
echo "=============================================="
echo "  Done — $(date)"
echo "=============================================="
