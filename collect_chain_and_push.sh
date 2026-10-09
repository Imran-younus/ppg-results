#!/bin/ksh
#=============================================================================
# collect_chain_and_push.sh
# Purpose : Wait for all PPG chain simulation jobs (single-stage PPGsim/PPGvdd
#           or 101-stage PPGdut), validate model provenance from the generated
#           netlists, verify results are complete, then write the result file.
#           Run this after any of the three simulation scripts completes, or
#           after a nohup background submit.
#
# Run: nohup ksh collect_chain_and_push.sh > collect_chain.log 2>&1 &
#
# REQUIRED PARAMETERS (env vars):
#   MODEL_NAME — label used when submitting the jobs, e.g. "v0.6SB2"
#                The active design_include.inc path in every generated netlist
#                must contain this string.
#
# OPTIONAL PARAMETERS:
#   MODEL_INC  — if set, the exact .inc path is verified against every netlist
#                (stronger check than MODEL_NAME string matching alone)
#   SIM_TYPE   — "single" (default) or "chain"
#                  single → looks in full_dut/run/  (PPGdut jobs) — 101-stage
#                  NOTE: the naming is legacy; both flows share the same dir
#                Single-stage VDD-sweep results live under run_vdd/ and are
#                collected directly by the sweep script; this script handles
#                the per-cell run/ directory used by both single-VDD and
#                101-stage flows.
#=============================================================================

SCRIPTDIR='/afs/apd.pok.ibm.com/u/imranyou/for_imran'

# Load shared library (provides verify_model, validate_model_params)
. "$SCRIPTDIR/ppg_sim_lib.sh"

#-----------------------------------------------------------------------------
# Validate required parameter
#-----------------------------------------------------------------------------
if [ -z "$MODEL_NAME" ]; then
    echo "ERROR: MODEL_NAME must be set to the model label used when submitting." >&2
    echo "  e.g.:  MODEL_NAME='v0.6SB2' ksh collect_chain_and_push.sh" >&2
    exit 1
fi

RUNBASE="$SCRIPTDIR/full_dut/run"
RESULT_FILE="$SCRIPTDIR/chain_results_${MODEL_NAME}.txt"
CELLS='7TSL_INVX2 7TSL_NAND2B 7TSL_NAND2T 7TSL_NAND3B 7TSL_NAND3T 7TSL_NOR2B 7TSL_NOR2T'
NETLIST='invfo3_mod.sp'

echo "$(date): Collecting results for model: $MODEL_NAME"
echo "  Results file: $RESULT_FILE"

#-----------------------------------------------------------------------------
# Wait for any outstanding PPG jobs (covers all three sim scripts)
#-----------------------------------------------------------------------------
echo "$(date): Checking for running jobs (PPGsim/PPGvdd/PPGdut)..."
running=$(bjobs 2>/dev/null | grep -c "PPGsim_\|PPGvdd_\|PPGdut_" || echo 0)
if [ "$running" -gt 0 ]; then
    echo "$(date): $running jobs still running — waiting..."
    while true; do
        running=$(bjobs 2>/dev/null | grep -c "PPGsim_\|PPGvdd_\|PPGdut_" || echo 0)
        [ "$running" -eq 0 ] && break
        echo -n "."
        sleep 30
    done
    echo ""
fi
echo "$(date): No outstanding PPG jobs found."

#-----------------------------------------------------------------------------
# Per-cell validation and result extraction
#-----------------------------------------------------------------------------
> "$RESULT_FILE"
ALL_OK=1

for cell in $CELLS; do
    netlist="$RUNBASE/$cell/$NETLIST"
    lis="$RUNBASE/$cell/$NETLIST.lis"

    #---------------------------------------------------------------------
    # 1. Netlist must exist — confirms the sim script was actually run
    #---------------------------------------------------------------------
    if [ ! -f "$netlist" ]; then
        echo "ERROR [$cell]: Generated netlist not found: $netlist" >&2
        echo "  Run the simulation script before collecting." >&2
        ALL_OK=0; continue
    fi

    #---------------------------------------------------------------------
    # 2. Exactly one active model .inc (design_include.inc) must be present
    #---------------------------------------------------------------------
    inc_count=$(grep -c "^\.inc.*design_include\.inc" "$netlist" 2>/dev/null || echo 0)
    if [ "$inc_count" -eq 0 ]; then
        echo "ERROR [$cell]: No active model .inc line in $netlist" >&2
        ALL_OK=0; continue
    fi
    if [ "$inc_count" -gt 1 ]; then
        echo "ERROR [$cell]: Multiple active model .inc lines in $netlist" >&2
        grep "^\.inc.*design_include\.inc" "$netlist" >&2
        ALL_OK=0; continue
    fi

    #---------------------------------------------------------------------
    # 3. Active .inc must contain MODEL_NAME
    #---------------------------------------------------------------------
    active_inc=$(grep "^\.inc.*design_include\.inc" "$netlist")
    if ! echo "$active_inc" | grep -q "$MODEL_NAME"; then
        echo "ERROR [$cell]: Netlist model does not match MODEL_NAME='$MODEL_NAME'" >&2
        echo "  Active .inc: $active_inc" >&2
        ALL_OK=0; continue
    fi

    #---------------------------------------------------------------------
    # 4. If MODEL_INC is set, verify the exact path
    #---------------------------------------------------------------------
    if [ -n "$MODEL_INC" ]; then
        if ! echo "$active_inc" | grep -qF "$MODEL_INC"; then
            echo "ERROR [$cell]: Netlist model path does not match MODEL_INC" >&2
            echo "  Expected: $MODEL_INC" >&2
            echo "  Found:    $active_inc" >&2
            ALL_OK=0; continue
        fi
    fi

    echo "OK [$cell]: model verified — $active_inc"

    #---------------------------------------------------------------------
    # 5. .lis file must exist
    #---------------------------------------------------------------------
    if [ ! -f "$lis" ]; then
        echo "ERROR [$cell]: Results file not found: $lis" >&2
        ALL_OK=0; continue
    fi

    #---------------------------------------------------------------------
    # 6. .lis must not contain HSPICE error markers
    #---------------------------------------------------------------------
    if grep -qi "^\*\*error\|^\* error\|Error:" "$lis" 2>/dev/null; then
        echo "ERROR [$cell]: HSPICE errors found in $lis" >&2
        grep -i "^\*\*error\|^\* error\|Error:" "$lis" | head -5 >&2
        ALL_OK=0; continue
    fi

    #---------------------------------------------------------------------
    # 7. Extract key metrics; fall back to .mt0 if .lis lacks them
    #---------------------------------------------------------------------
    sd=$(grep    "stage_delay="  "$lis" | awk -F= '{print $NF}' | tr -d ' ')
    ceff=$(grep  " ceff="        "$lis" | awk -F= '{print $NF}' | tr -d ' ')
    acreff=$(grep " acreff="     "$lis" | awk -F= '{print $NF}' | tr -d ' ')
    iddq=$(grep  " iddq_stage="  "$lis" | awk -F= '{print $NF}' | tr -d ' ')

    if [ -z "$sd" ]; then
        mt="$RUNBASE/$cell/invfo3_mod.mt0"
        if [ -f "$mt" ]; then
            sd=$(awk     '/stage_delay/{getline; print $1}' "$mt" 2>/dev/null)
            ceff=$(awk   '/ceff/{getline; print $5}'        "$mt" 2>/dev/null)
            acreff=$(awk '/acreff/{getline; print $6}'      "$mt" 2>/dev/null)
            iddq=$(awk   '/iddq_stage/{getline; print $4}'  "$mt" 2>/dev/null)
        fi
    fi

    if [ -z "$sd" ]; then
        echo "ERROR [$cell]: stage_delay not found — simulation may have failed" >&2
        ALL_OK=0; continue
    fi

    echo "$cell  stage_delay=$sd  ceff=$ceff  acreff=$acreff  iddq=$iddq"
    printf "%s\t%s\t%s\t%s\t%s\n" "$cell" "$sd" "$ceff" "$acreff" "$iddq" >> "$RESULT_FILE"
done

#-----------------------------------------------------------------------------
# Abort if any cell failed — never push partial or mismatched results
#-----------------------------------------------------------------------------
if [ "$ALL_OK" -ne 1 ]; then
    echo "" >&2
    echo "ABORT: One or more cells failed validation." >&2
    echo "       HTML was NOT updated. Fix the errors and re-run." >&2
    exit 1
fi

echo ""
echo "$(date): All cells passed. Model: $MODEL_NAME"
echo "$(date): Results written to: $RESULT_FILE"
cat "$RESULT_FILE"
