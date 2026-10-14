#!/bin/ksh
#=============================================================================
# run_ppg_sim.sh — Model-Agnostic PPG Simulation Runner
#
# Simulates all 24 standard cells across full VDD sweep or single VDD/temp point.
#
# Usage (Environment Variables):
#   export MODEL_NAME="v0.6SB"
#   export MODEL_INC="/path/to/Spice-XXXXXX/design_include.inc"
#   export MODEL_LIB="/path/to/Spice-XXXXXX/fixed_corner.lib"
#   export VDD="sweep"          # or single VDD like "0.70", or list "0.6 0.7 0.8"
#   export TEMP="25"            # or custom temp like "125"
#   export VT="slvt"            # or "ulvt"
#   ksh run_ppg_sim.sh
#
# Usage (CLI Arguments):
#   ksh run_ppg_sim.sh -m <model_name> -i <model_inc> -l <model_lib> [-v <vdd>] [-t <temp>] [-f <vt>]
#
# Flags:
#   -m, --model-name   Model label (e.g. v0.6SB, v0.6SB2, v0.22)
#   -i, --model-inc    Path to design_include.inc
#   -l, --model-lib    Path to fixed_corner.lib
#   -v, --vdd          VDD value(s): "sweep" (default), single (e.g. 0.70), or list
#   -t, --temp         Temperature in °C (default: 25)
#   -f, --flavor       Vt flavor: "slvt" (default) or "ulvt"
#   -o, --output       Output results file path (optional)
#   -d, --dry-run      Generate netlists/wrappers without submitting LSF jobs
#   -c, --collect-only Collect results from existing .sp.lis files; skip setup/submit/wait
#
# Chain mode (full DUT 101-stage ring, any VDD): delegates to full_dut/run_ppg_dut.sh
#   ksh run_ppg_sim.sh --chain --cell <layout cell> [--lib <cds lib>] [--spf <layout.spf>] -m <model> [-v <vdd|list|sweep>] [-t <temp>] [--stages 101] [-o <results>] [-d]
#   --chain            Select chain mode (default mode is the single-stage 24-cell sweep)
#   --cell <name>      Layout cell name in the CTE/Cadence library (env PPG_CELL if omitted). Must equal the SPF .SUBCKT name.
#   --lib  <name>      Cadence library of that cell, as defined in extraction/cds.lib (env PPG_LIB, default test_C18mintaka_PPG_ROs)
#   --spf  <path>      Ported layout SPF ('ENA VSS VDD RO_OUT' + 4 R_PORT_* bridges). If omitted:
#                        1. reuse extraction/ext_<cell>/<cell>_ported.spf if it exists (force a new extraction: --re-extract)
#                        2. else run extraction/run_chain_extract.sh <cell> <lib>  (oasisout, si/CDL, ICV LVS, StarRC V0p42, port bridging)
#                      With -d the extraction is only PLANNED (read-only library check), never run.
#   --stages <n>       Ring stages (default 101)
#   In chain mode -v defaults to 0.70 (NOT a sweep). v0.43/v0.53/v0.6SB/v0.6SB2 resolve -i/-l automatically.
#   Test hooks: PPG_EXTRACT_SCRIPT / PPG_DUT_SCRIPT override the two delegated scripts (used for stub testing).
#=============================================================================

SCRIPTDIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPTDIR/ppg_sim_lib.sh"

# ── Parse CLI arguments (overrides env vars) ────────────────────────
DRY_RUN=0
COLLECT_ONLY=0
CHAIN=0
CHAIN_CELL="${PPG_CELL:-}"
CHAIN_LIB="${PPG_LIB:-test_C18mintaka_PPG_ROs}"
CHAIN_SPF=""
CHAIN_STAGES=""
RE_EXTRACT=0
while [ $# -gt 0 ]; do
    case "$1" in
        --chain)         CHAIN=1;         shift 1 ;;
        --cell)          CHAIN_CELL="$2"; shift 2 ;;
        --lib)           CHAIN_LIB="$2";  shift 2 ;;
        --re-extract)    RE_EXTRACT=1;    shift 1 ;;
        --spf)           CHAIN_SPF="$2";  shift 2 ;;
        --stages)        CHAIN_STAGES="$2"; shift 2 ;;
        -m|--model-name) MODEL_NAME="$2"; shift 2 ;;
        -i|--model-inc)  MODEL_INC="$2";  shift 2 ;;
        -l|--model-lib)  MODEL_LIB="$2";  shift 2 ;;
        -v|--vdd)        VDD="$2";        shift 2 ;;
        -t|--temp)       TEMP="$2";       shift 2 ;;
        -f|--flavor)     VT="$2";         shift 2 ;;
        -o|--output)     OUTPUT="$2";     shift 2 ;;
        -d|--dry-run)    DRY_RUN=1;       shift 1 ;;
        -c|--collect-only) COLLECT_ONLY=1; shift 1 ;;
        -h|--help)
            echo "Usage: ksh run_ppg_sim.sh [options]"
            echo "Options:"
            echo "  -m, --model-name <name>   Model name (e.g. v0.6SB)"
            echo "  -i, --model-inc  <path>   Path to design_include.inc"
            echo "  -l, --model-lib  <path>   Path to fixed_corner.lib"
            echo "  -v, --vdd        <volts>  'sweep' (default) or single/list"
            echo "  -t, --temp       <degC>   Temperature (default: 25)"
            echo "  -f, --flavor     <flavor> 'slvt' (default) or 'ulvt'"
            echo "  -o, --output     <path>   Output results file"
            echo "  -d, --dry-run             Prepare files without LSF submit"
            echo "  -c, --collect-only        Collect from existing .sp.lis; skip setup/submit/wait"
            echo "Chain mode (full DUT ring, delegates to full_dut/run_ppg_dut.sh):"
            echo "  --chain --cell <layout cell> [--lib <cds lib>] [--spf <layout.spf>] [--re-extract] [--stages 101] [-m -i -l -v -t -o -d]"
            echo "  (no --spf: reuse extraction/ext_<cell>/<cell>_ported.spf or run extraction/run_chain_extract.sh)"
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# ── Chain mode: full DUT 101-stage ring at any VDD (NOTES.md Runbook B) ──
if [ "$CHAIN" -eq 1 ]; then
    EXTRACT_SCRIPT="${PPG_EXTRACT_SCRIPT:-$SCRIPTDIR/extraction/run_chain_extract.sh}"
    DUT_SCRIPT="${PPG_DUT_SCRIPT:-$SCRIPTDIR/full_dut/run_ppg_dut.sh}"
    if [ -z "$CHAIN_CELL" ]; then
        echo "ERROR: --chain requires --cell <layout cell> (or export PPG_CELL)" >&2
        exit 1
    fi
    if [ -z "$CHAIN_SPF" ]; then
        # No SPF given: reuse a previous extraction or extract from the CTE library
        CHAIN_SPF="$SCRIPTDIR/extraction/ext_${CHAIN_CELL}/${CHAIN_CELL}_ported.spf"
        if [ -s "$CHAIN_SPF" ] && [ "$RE_EXTRACT" -eq 0 ]; then
            echo "Reusing existing ported SPF: $CHAIN_SPF (use --re-extract to rebuild)"
        else
            # Read-only library check: cell must exist with BOTH layout and schematic views
            _lib_dir=$(grep "^DEFINE $CHAIN_LIB " "$SCRIPTDIR/extraction/cds.lib" 2>/dev/null | awk '{print $3}')
            if [ -z "$_lib_dir" ] || [ ! -d "$_lib_dir" ]; then
                echo "ERROR: library '$CHAIN_LIB' is not defined in $SCRIPTDIR/extraction/cds.lib (or its directory is missing)." >&2
                exit 1
            fi
            if [ ! -f "$_lib_dir/$CHAIN_CELL/layout/layout.oa" ] || [ ! -f "$_lib_dir/$CHAIN_CELL/schematic/sch.oa" ]; then
                echo "ERROR: cell '$CHAIN_CELL' needs both layout/layout.oa and schematic/sch.oa in $_lib_dir." >&2
                echo "       Cells with both views (5T family):" >&2
                for _c in "$_lib_dir"/*_5T_*; do
                    [ -f "$_c/layout/layout.oa" ] && [ -f "$_c/schematic/sch.oa" ] && echo "         $(basename "$_c")" >&2
                done
                exit 1
            fi
            echo "Cell '$CHAIN_CELL' found in library '$CHAIN_LIB' ($_lib_dir): layout + schematic views present."
            if [ "$DRY_RUN" -eq 1 ]; then
                echo "DRY RUN - no SPF supplied/found, extraction NOT run. Plan:"
                echo "  1. bash $EXTRACT_SCRIPT $CHAIN_CELL $CHAIN_LIB"
                echo "       schCheck sub-cells -> si/CDL -> oasisout -> ICV LVS (gate: no unmatched devices/nets)"
                echo "       -> StarRC RPDK0.43 V0p42 (TCAD gate) -> add ports + 4 R_PORT_* from LVS net table"
                echo "       -> $CHAIN_SPF"
                echo "  2. ksh $DUT_SCRIPT -c $CHAIN_CELL -s $CHAIN_SPF -m ${MODEL_NAME:-<model>} -v ${VDD:-0.70} ..."
                exit 0
            fi
            echo "No ported SPF for '$CHAIN_CELL' - running extraction (takes several minutes; output below)."
            _ext_log="$SCRIPTDIR/extraction/ext_${CHAIN_CELL}.log"
            # pipeline status is tee's; success is judged by the PORTED_SPF= line + file below
            bash "$EXTRACT_SCRIPT" "$CHAIN_CELL" "$CHAIN_LIB" 2>&1 | tee "$_ext_log"
            _ported=$(grep '^PORTED_SPF=' "$_ext_log" | tail -1 | cut -d= -f2-)
            if [ -z "$_ported" ] || [ ! -s "$_ported" ]; then
                echo "ERROR: extraction did not produce a ported SPF - see $_ext_log (last error above). Not simulating." >&2
                exit 1
            fi
            CHAIN_SPF="$_ported"
        fi
    fi
    case "$CHAIN_SPF" in /*) ;; *) CHAIN_SPF="$SCRIPTDIR/$CHAIN_SPF" ;; esac
    if [ ! -f "$CHAIN_SPF" ]; then
        echo "ERROR: layout SPF not found: $CHAIN_SPF" >&2
        exit 1
    fi
    # Port guard (Issue 33): .SUBCKT must end in 'ENA VSS VDD RO_OUT' and have 4 R_PORT_* bridges
    if ! grep -m1 -i '^\.SUBCKT' "$CHAIN_SPF" | grep -q "^\.SUBCKT $CHAIN_CELL ENA VSS VDD RO_OUT[ ]*"'$'; then
        echo "ERROR: $CHAIN_SPF first .SUBCKT is not '.SUBCKT $CHAIN_CELL ENA VSS VDD RO_OUT':" >&2
        echo "       $(grep -m1 -i '^\.SUBCKT' "$CHAIN_SPF")" >&2
        echo "       Add ports + R_PORT_* bridges per NOTES.md Issue 33 / Runbook B." >&2
        exit 1
    fi
    if [ "$(grep -c '^R_PORT_' "$CHAIN_SPF")" -ne 4 ]; then
        echo "ERROR: $CHAIN_SPF must contain exactly 4 R_PORT_* bridges (found $(grep -c '^R_PORT_' "$CHAIN_SPF"))." >&2
        exit 1
    fi
    _tcad=$(grep -m1 'TCAD_GRD_FILE' "$CHAIN_SPF" | awk '{print $NF}')
    echo "SPF TCAD: $_tcad"
    # Issue 29: parasitics must match the model. Explicit SPF_TCAD_EXPECT wins; else known default for RPDK0.43.
    _tcad_exp="$SPF_TCAD_EXPECT"
    if [ -z "$_tcad_exp" ]; then
        case "${MODEL_NAME:-v0.43}" in v0.43|rpdk0.43|RPDK0.43) _tcad_exp="V0p42" ;; esac
    fi
    if [ -n "$_tcad_exp" ]; then
        case "$_tcad" in
            *"$_tcad_exp"*) ;;
            *) echo "ERROR: SPF TCAD header does not contain '$_tcad_exp' (model ${MODEL_NAME:-v0.43}); wrong parasitics for this model (Issue 29)." >&2
               exit 1 ;;
        esac
    fi
    set -- -c "$CHAIN_CELL" -s "$CHAIN_SPF"
    [ -n "$MODEL_NAME" ]    && set -- "$@" -m "$MODEL_NAME"
    [ -n "$MODEL_INC" ]     && set -- "$@" -i "$MODEL_INC"
    [ -n "$MODEL_LIB" ]     && set -- "$@" -l "$MODEL_LIB"
    [ -n "$VDD" ]           && set -- "$@" -v "$VDD"
    [ -n "$TEMP" ]          && set -- "$@" -t "$TEMP"
    [ -n "$CHAIN_STAGES" ]  && set -- "$@" -n "$CHAIN_STAGES"
    [ -n "$OUTPUT" ]        && set -- "$@" -o "$OUTPUT"
    [ "$DRY_RUN" -eq 1 ]    && set -- "$@" -d
    exec ksh "$DUT_SCRIPT" "$@"
fi

# ── Defaults & Configuration ────────────────────────────────────────
# collect-only mode: MODEL_INC/LIB not needed — skip validation
if [ "$COLLECT_ONLY" -eq 0 ]; then
    validate_model_params
fi

VT="${VT:-slvt}"
TEMP="${TEMP:-$DEFAULT_TEMP}"
if [ -z "$SPFDIR" ]; then
    SPFDIR="$DEFAULT_SPFDIR"
    echo "WARNING: SPFDIR not set - using DEFAULT_SPFDIR (tpdk0.6sb = V0.61 parasitics)." >&2
    echo "         For TPDK0.53 / RPDK0.43 you MUST export SPFDIR (see SKILL.md model table)." >&2
fi
BASESP="$SCRIPTDIR/invfo3_base.sp"
NETLIST='invfo3_mod.sp'
SPF_OUT='PPGchain.spf'
LSF_JOBPREFIX="PPG_${MODEL_NAME}_${VT}"

# Resolve VDD list
if [ -z "$VDD" ] || [ "$VDD" = "sweep" ]; then
    VOLTAGES="$DEFAULT_VOLTAGES"
    RESULTS_DEFAULT="$SCRIPTDIR/PPGRO_chain_menu14_${MODEL_NAME}_${VT}.txt"
else
    VOLTAGES="$VDD"
    RESULTS_DEFAULT="$SCRIPTDIR/PPGRO_chain_${MODEL_NAME}_${VT}_results.txt"
fi
RESULTS="${OUTPUT:-$RESULTS_DEFAULT}"
RUNDIR="$SCRIPTDIR/run_vdd_${MODEL_NAME}_${VT}"

echo "======================================================"
echo "PPG Simulation Flow"
echo "  Model       : $MODEL_NAME"
echo "  Flavor (Vt) : $VT"
echo "  Temperature : ${TEMP} °C"
echo "  Voltages    : $VOLTAGES"
echo "  Run dir     : $RUNDIR"
echo "  Results out : $RESULTS"
echo "  SPF dir     : $SPFDIR"
echo "  SPF TCAD    : $(grep -m1 'TCAD_GRD_FILE' "$SPFDIR/PPG1_INV_X2_7TSL.spf" 2>/dev/null | awk '{print $NF}')"
echo "======================================================"

# Pre-flight (Issue 21): optional TCAD check. export SPF_TCAD_EXPECT='V0p53' etc.
if [ "$COLLECT_ONLY" -eq 0 ] && [ -n "$SPF_TCAD_EXPECT" ]; then
    if ! grep -m1 'TCAD_GRD_FILE' "$SPFDIR/PPG1_INV_X2_7TSL.spf" 2>/dev/null | grep -q "$SPF_TCAD_EXPECT"; then
        echo "ERROR: SPF TCAD header in $SPFDIR does not contain '$SPF_TCAD_EXPECT'." >&2
        exit 1
    fi
fi

mkdir -p "$RUNDIR"

# ── Submit Simulations (skipped in collect-only mode) ───────────────
if [ "$COLLECT_ONLY" -eq 1 ]; then
    echo "(collect-only: skipping netlist setup and job submission)"
fi

for vdd in $VOLTAGES; do
    [ "$COLLECT_ONLY" -eq 1 ] && break   # skip entire setup/submit loop
    vdd_tag=$(echo "$vdd" | sed 's/\./_/g')
    vdd_dir="$RUNDIR/$vdd_tag"
    mkdir -p "$vdd_dir"

    # 1. Create per-voltage/temp template from BASESP
    TEMPLATE="$vdd_dir/invfo3_sweep.sp"
    patch_netlist "$BASESP" "$TEMPLATE" "" "" "$vdd" "$TEMP"

    # 2. Iterate through cells (all 24, or subset if CELL_FILTER is set)
    echo "$PPG_STD_CELLS_24" | while read label spf_name subckt; do
        [ -z "$label" ] && continue
        # Skip if caller provided a filter list and this cell is not in it
        if [ -n "$CELL_FILTER" ]; then
            echo " $CELL_FILTER " | grep -q " $label " || continue
        fi
        cell_rundir="$vdd_dir/$label"
        mkdir -p "$cell_rundir"
        spf_source="$SPFDIR/$spf_name"

        # 3. Process SPF according to Vt flavor
        if [ "$VT" = "ulvt" ]; then
            process_spf "$spf_source" "$cell_rundir/$SPF_OUT"
        else
            process_spf_slvt "$spf_source" "$cell_rundir/$SPF_OUT"
        fi

        # 3a. Output file must exist (AFS quota exhaustion makes mkdir/redirect fail silently - Issue 28)
        if [ ! -s "$cell_rundir/$SPF_OUT" ]; then
            echo "ERROR: could not write $cell_rundir/$SPF_OUT (disk quota? run: fs lq .)" >&2
            exit 1
        fi
        # 3b. Port-order guard (Issue 5/26): processed SPF must be 'VSS VDD A Z'
        if ! grep -m1 -i '^\.SUBCKT' "$cell_rundir/$SPF_OUT" | grep -q 'VSS VDD A Z[ ]*$'; then
            echo "ERROR: unknown SPF port order for $label: $(grep -m1 -i '^\.SUBCKT' "$cell_rundir/$SPF_OUT")" >&2
            echo "       Add a _SUBCKT_SED_n rule in ppg_sim_lib.sh (see SKILL.md Issue 26)." >&2
            exit 1
        fi

        # 4. Patch per-cell netlist and verify model
        patch_netlist "$TEMPLATE" "$cell_rundir/$NETLIST" "$cell_rundir/$SPF_OUT" "$subckt"

        # 5. Create executable LSF run wrapper
        create_hsp_wrapper "$cell_rundir/run_hsp.sh" "$cell_rundir/$NETLIST"

        # 6. Submit LSF job (unless dry-run)
        if [ "$DRY_RUN" -eq 0 ]; then
            bsub -J "${LSF_JOBPREFIX}_${vdd_tag}_${label}" \
                 -M 128 -n 8 -W 4:00 \
                 -R "select[ $DEFAULT_LSF_SELECT ]" \
                 -cwd "$cell_rundir" \
                 "ksh $cell_rundir/run_hsp.sh" > /dev/null 2>&1
        fi
    done
done

if [ "$DRY_RUN" -eq 1 ]; then
    echo "Dry-run complete. Netlists, SPFs, and wrappers generated in: $RUNDIR"
    exit 0
fi

# ── Wait for Completion (skipped in collect-only mode) ──────────────
if [ "$COLLECT_ONLY" -eq 0 ]; then
    wait_for_jobs "$LSF_JOBPREFIX"
fi

# ── Collect Results ─────────────────────────────────────────────────
printf "" > "$RESULTS"
echo "Collecting results -> $RESULTS"
rm -f "$RESULTS.missing"

echo "$PPG_STD_CELLS_24" | while read label spf_name subckt; do
    [ -z "$label" ] && continue
    {
        # stage_delay row
        printf "%s" "$label"
        for vdd in $VOLTAGES; do
            vdd_tag=$(echo "$vdd" | sed 's/\./_/g')
            lis=$(LIS_FILE "$RUNDIR/$vdd_tag/$label/$NETLIST")
            val=$(grep "stage_delay=" "$lis" 2>/dev/null | awk '{print $NF}')
            case "$val" in
                [0-9]*) ;;
                *) echo "MISSING stage_delay: $label @ $vdd V" >> "$RESULTS.missing" ;;
            esac
            printf "\t%s" "${val:--}"
        done
        printf "\n"

        # Other metric rows
        for metric in iddq iddarail_qcorr acceffrail_qcorr acreffrail_qcorr; do
            printf "%s_%s" "$label" "$metric"
            for vdd in $VOLTAGES; do
                vdd_tag=$(echo "$vdd" | sed 's/\./_/g')
                lis=$(LIS_FILE "$RUNDIR/$vdd_tag/$label/$NETLIST")
                val=$(grep "${metric}=" "$lis" 2>/dev/null | awk '{print $NF}')
                printf "\t%s" "${val:--}"
            done
            printf "\n"
        done
    } >> "$RESULTS"
done

echo ""
if [ -s "$RESULTS.missing" ]; then
    _n=$(wc -l < "$RESULTS.missing")
    echo "FAILED: $_n stage_delay value(s) missing/failed. See $RESULTS.missing" >&2
    echo "Retry only those cells: CELL_FILTER='<labels>' (delete their .lis first). DO NOT publish." >&2
    exit 1
fi
rm -f "$RESULTS.missing"
echo "Simulation flow completed successfully (all stage_delay values present)."
echo "Results saved to: $RESULTS"
