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
#=============================================================================

SCRIPTDIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPTDIR/ppg_sim_lib.sh"

# ── Parse CLI arguments (overrides env vars) ────────────────────────
DRY_RUN=0
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
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# ── Defaults & Configuration ────────────────────────────────────────
validate_model_params

VT="${VT:-slvt}"
TEMP="${TEMP:-$DEFAULT_TEMP}"
SPFDIR="${SPFDIR:-$DEFAULT_SPFDIR}"
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
echo "======================================================"

mkdir -p "$RUNDIR"

# ── Submit Simulations ──────────────────────────────────────────────
for vdd in $VOLTAGES; do
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

# ── Wait for Completion ─────────────────────────────────────────────
wait_for_jobs "$LSF_JOBPREFIX"

# ── Collect Results ─────────────────────────────────────────────────
printf "" > "$RESULTS"
echo "Collecting results -> $RESULTS"

echo "$PPG_STD_CELLS_24" | while read label spf_name subckt; do
    [ -z "$label" ] && continue
    {
        # stage_delay row
        printf "%s" "$label"
        for vdd in $VOLTAGES; do
            vdd_tag=$(echo "$vdd" | sed 's/\./_/g')
            lis=$(LIS_FILE "$RUNDIR/$vdd_tag/$label/$NETLIST")
            val=$(grep "stage_delay=" "$lis" 2>/dev/null | awk '{print $NF}')
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
echo "Simulation flow completed successfully."
echo "Results saved to: $RESULTS"
