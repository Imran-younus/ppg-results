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
#=============================================================================

SCRIPTDIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPTDIR/ppg_sim_lib.sh"

# ── Parse CLI arguments (overrides env vars) ────────────────────────
DRY_RUN=0
COLLECT_ONLY=0
while [ $# -gt 0 ]; do
    case "$1" in
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
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

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
