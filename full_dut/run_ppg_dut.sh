#!/bin/ksh
#=============================================================================
# full_dut/run_ppg_dut.sh
# Purpose : Model-agnostic and layout-agnostic runner for full DUT ring
#           oscillator simulations in HSPICE.
#
# Supports arbitrary layout SPFs, arbitrary PDK models, parameterised stages,
# single voltage points, custom voltage lists, or full 14-point VDD sweeps.
#
# Usage:
#   ksh full_dut/run_ppg_dut.sh [options]
#
# Options:
#   -c, --cell    <name>       Cell / subcircuit name (e.g. NAND2_X1_5T_125H_RX15_F03_SLVT_B_M2)
#   -s, --spf     <path>       Path to layout extracted SPF file
#   -m, --model   <name>       Model label (v0.43, v0.53, v0.6SB, v0.6SB2, etc.)
#   -i, --inc     <path>       Path to design_include.inc (auto-set for known models)
#   -l, --lib     <path>       Path to fixed_corner.lib (auto-set for known models)
#   -v, --vdd     <val|sweep>  Voltage(s) to simulate (default: 0.70, or 'sweep')
#   -t, --temp    <degC>       Temperature in °C (default: 25)
#   -n, --stages  <count>      Number of ring stages (default: 101)
#   -b, --base    <path>       Base netlist (default: full_dut/PPG_ROM_base.sp)
#   -o, --output  <path>       Output results text file
#       --local                Run HSPICE locally instead of LSF
#   -d, --dry-run              Generate and verify patched netlists without submitting
#   -h, --help                 Display this help message
#=============================================================================

SCRIPTDIR='/afs/apd.pok.ibm.com/u/imranyou/for_imran'
FULLDUTDIR="$SCRIPTDIR/full_dut"
. "$SCRIPTDIR/ppg_sim_lib.sh"

# Default values
# Default cell = canonical 5T F03 layout. Override with -c <name>.
CELL_NAME="${CELL_NAME:-NAND2_X1_5T_125H_RX15_F03_SLVT_B_M2}"
# Default SPF = re-extracted ported SPF (ENA VSS VDD RO_OUT + 4 R_PORT_* bridges, V0p42 TCAD).
# The old layout/NAND2_*_.spf is the pre-re-extraction baseline; do not use it for new runs.
SPF_PATH="${SPF_PATH:-$SCRIPTDIR/extraction/reext_F03/NAND2_X1_5T_125H_RX15_F03_SLVT_B_M2_ported.spf}"
case "$SPF_PATH" in
    /*) ;;
    *)  SPF_PATH="$SCRIPTDIR/$SPF_PATH" ;;
esac
# Default model = v0.43. Auto-resolve also handles: v0.53, v0.6SB, v0.6SB2.
MODEL_NAME="${MODEL_NAME:-v0.43}"
MODEL_INC="${MODEL_INC:-}"
MODEL_LIB="${MODEL_LIB:-}"
VDD_INPUT="${VDD:-0.70}"
TEMP="${TEMP:-25}"
STAGES="${STAGES:-101}"
BASESP="${BASESP:-$FULLDUTDIR/PPG_ROM_base.sp}"
OUTPUT="${OUTPUT:-}"
USE_LSF=1
DRY_RUN=0

# Parse CLI arguments
while [ $# -gt 0 ]; do
    case "$1" in
        -c|--cell)    CELL_NAME="$2"; shift 2 ;;
        -s|--spf)     SPF_PATH="$2"; case "$SPF_PATH" in /*) ;; *) SPF_PATH="$SCRIPTDIR/$SPF_PATH" ;; esac; shift 2 ;;
        -m|--model)   MODEL_NAME="$2"; shift 2 ;;
        -i|--inc)     MODEL_INC="$2"; shift 2 ;;
        -l|--lib)     MODEL_LIB="$2"; shift 2 ;;
        -v|--vdd)     VDD_INPUT="$2"; shift 2 ;;
        -t|--temp)    TEMP="$2"; shift 2 ;;
        -n|--stages)  STAGES="$2"; shift 2 ;;
        -b|--base)    BASESP="$2"; shift 2 ;;
        -o|--output)  OUTPUT="$2"; shift 2 ;;
        --local)      USE_LSF=0; shift ;;
        -d|--dry-run) DRY_RUN=1; shift ;;
        -h|--help)
            grep -E "^#   " "$0" | sed 's/^#   //'
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Auto-resolve known PDK models if paths not provided
if [ -z "$MODEL_INC" ] || [ -z "$MODEL_LIB" ]; then
    case "$MODEL_NAME" in
        v0.43|rpdk0.43|RPDK0.43)
            MODEL_NAME="v0.43"
            MODEL_INC='/afs/apd/ant/cte_tech/1p4/IIMmintaka/common/pdk/IIM/SpiceModel_V0.430/Hspice/design_include.inc'
            MODEL_LIB='/afs/apd/ant/cte_tech/1p4/IIMmintaka/common/pdk/IIM/SpiceModel_V0.430/Hspice/fixed_corner.lib'
            ;;
        v0.53|tpdk0.53|TPDK0.53)
            MODEL_NAME="v0.53"
            MODEL_INC='/afs/apd/ant/research/prod/2HP/V0.51/Spice/design_include.inc'
            MODEL_LIB='/afs/apd/ant/research/prod/2HP/V0.51/Spice/fixed_corner.lib'
            ;;
        v0.6SB|v0p6SB)
            MODEL_NAME="v0.6SB"
            MODEL_INC='/afs/apd/ant/research/test/2HP/v0.53/Spice-260724-sandbox/design_include.inc'
            MODEL_LIB='/afs/apd/ant/research/test/2HP/v0.53/Spice-260724-sandbox/fixed_corner.lib'
            ;;
        v0.6SB2|v0p6SB2)
            MODEL_NAME="v0.6SB2"
            MODEL_INC='/afs/apd/ant/research/test/2HP/v0.53/Spice-260604-sandbox/design_include.inc'
            MODEL_LIB='/afs/apd/ant/research/test/2HP/v0.53/Spice-260604-sandbox/fixed_corner.lib'
            ;;
    esac
fi

export MODEL_NAME MODEL_INC MODEL_LIB
validate_model_params

if [ ! -f "$BASESP" ]; then
    echo "ERROR: Base netlist not found: $BASESP" >&2
    exit 1
fi

if [ ! -f "$SPF_PATH" ]; then
    echo "ERROR: SPF not found: $SPF_PATH" >&2
    exit 1
fi

# Resolve voltages
if [ "$VDD_INPUT" = "sweep" ]; then
    VOLTAGES="$DEFAULT_VOLTAGES"
else
    VOLTAGES="$VDD_INPUT"
fi

RUNBASE="$FULLDUTDIR/run_dut_${MODEL_NAME}_${CELL_NAME}"
# Results go to results/ dir by default; override with -o <path>
RESULTS="${OUTPUT:-$SCRIPTDIR/results/results_dut_${MODEL_NAME}_${CELL_NAME}.txt}"
NETLIST='invfo3_mod.sp'
LSF_JOBPREFIX="DUT_${MODEL_NAME}"

mkdir -p "$RUNBASE"
mkdir -p "$SCRIPTDIR/results"

echo "=============================================================================="
echo " PPG Full DUT Ring Oscillator Simulation Flow"
echo " Cell Name  : $CELL_NAME"
echo " Layout SPF : $SPF_PATH"
echo " Model Label: $MODEL_NAME"
echo " Model INC  : $MODEL_INC"
echo " Model LIB  : $MODEL_LIB"
echo " Stages     : $STAGES"
echo " Voltages   : $VOLTAGES"
echo " Temp       : ${TEMP} C"
echo " Base SP    : $BASESP"
echo " Run Dir    : $RUNBASE"
echo " Execution  : $([ "$DRY_RUN" -eq 1 ] && echo 'Dry Run (no sim)' || ([ "$USE_LSF" -eq 1 ] && echo 'LSF cluster' || echo 'Local'))"
echo "=============================================================================="

# Patch netlists for all requested voltages
for v in $VOLTAGES; do
    v_tag=$(echo "$v" | tr '.' '_')
    rundir="$RUNBASE/$v_tag"
    mkdir -p "$rundir"

    rm -f "$rundir/$NETLIST.lis" "$rundir/invfo3_mod_dp.lis"

    patch_netlist "$BASESP" "$rundir/$NETLIST" "$SPF_PATH" "$CELL_NAME" "$v" "$TEMP" "$STAGES"
    verify_model "$rundir/$NETLIST"
    create_hsp_wrapper "$rundir/run_hsp.sh" "$rundir/$NETLIST"

    if [ "$DRY_RUN" -eq 1 ]; then
        echo "Dry run verified: $rundir/$NETLIST (PVDD=$v, TEMP=$TEMP, STAGES=$STAGES)"
        continue
    fi

    if [ "$USE_LSF" -eq 1 ]; then
        echo "Submitting LSF job: VDD=${v}V -> $rundir"
        bsub -J "${LSF_JOBPREFIX}_${v_tag}" \
             -M 128 -n 8 -W 4:00 \
             -R "select[ $DEFAULT_LSF_SELECT ]" \
             -cwd "$rundir" \
             "ksh $rundir/run_hsp.sh" > /dev/null 2>&1
    else
        echo "Running HSPICE locally: VDD=${v}V..."
        (cd "$rundir" && ksh "$rundir/run_hsp.sh")
    fi
done

if [ "$DRY_RUN" -eq 1 ]; then
    echo ""
    echo "Dry run completed successfully. All netlists generated and verified."
    exit 0
fi

if [ "$USE_LSF" -eq 1 ]; then
    echo ""
    echo "Waiting for LSF jobs to complete..."
    wait_for_jobs "$LSF_JOBPREFIX"
fi

# Collect and format results
echo ""
echo "=============================================================================="
echo " Full DUT Results: $CELL_NAME ($MODEL_NAME, ${STAGES}-stages, ${TEMP}C)"
echo "=============================================================================="
printf "%-8s %-16s %-16s %-14s %-16s %-14s %-14s\n" \
       "VDD(V)" "stage_delay(ps)" "stage_freq(GHz)" "idda(uA)" "iddq_stg(nA)" "ceff(fF)" "acreff(kOhm)" | tee "$RESULTS"
printf "%-8s %-16s %-16s %-14s %-16s %-14s %-14s\n" \
       "--------" "----------------" "----------------" "--------------" "----------------" "--------------" "--------------" | tee -a "$RESULTS"

for v in $VOLTAGES; do
    v_tag=$(echo "$v" | tr '.' '_')
    lisfile="$RUNBASE/$v_tag/$NETLIST.lis"

    if [ ! -f "$lisfile" ]; then
        printf "%-8s %-16s\n" "$v" "MISSING (.lis not found)" | tee -a "$RESULTS"
        continue
    fi

    dly=$(grep "stage_delay=" "$lisfile" 2>/dev/null | awk '{print $NF}')
    frq=$(grep "stage_freq="  "$lisfile" 2>/dev/null | awk '{print $NF}')
    ida=$(grep "^ *idda="     "$lisfile" 2>/dev/null | awk '{print $NF}')
    idq=$(grep "iddq_stage="  "$lisfile" 2>/dev/null | awk '{print $NF}')
    cef=$(grep "^ *ceff="     "$lisfile" 2>/dev/null | awk '{print $NF}')
    acr=$(grep "^ *acreff="   "$lisfile" 2>/dev/null | awk '{print $NF}')

    dly="${dly:--}"
    frq="${frq:--}"
    ida="${ida:--}"
    idq="${idq:--}"
    cef="${cef:--}"
    acr="${acr:--}"

    printf "%-8s %-16s %-16s %-14s %-16s %-14s %-14s\n" \
           "$v" "$dly" "$frq" "$ida" "$idq" "$cef" "$acr" | tee -a "$RESULTS"
done

echo "=============================================================================="
echo "Results saved to: $RESULTS"
