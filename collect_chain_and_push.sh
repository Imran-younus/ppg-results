#!/bin/ksh
#=============================================================================
# collect_chain_and_push.sh
# Purpose : Collect 101-stage RO simulation results from full_dut/run/,
#           validate model provenance across all cells, check for simulation
#           errors, generate chain_results_<model>.txt, and run automated
#           dataset consistency checks on the dashboard HTML files.
#=============================================================================

SCRIPTDIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPTDIR/ppg_sim_lib.sh"

if [ -z "$MODEL_NAME" ]; then
    echo "ERROR: MODEL_NAME must be set (e.g. MODEL_NAME='v0.6SB' ksh collect_chain_and_push.sh)" >&2
    exit 1
fi

RUNBASE="$SCRIPTDIR/full_dut/run"
RESULT_FILE="$SCRIPTDIR/chain_results_${MODEL_NAME}.txt"
CELLS="$PPG_CHAIN_CELLS_7"
NETLIST='invfo3_mod.sp'

echo "$(date): Collecting 101-stage RO results for model: $MODEL_NAME"
echo "  Results destination: $RESULT_FILE"

# ── Wait for running jobs ───────────────────────────────────────────
running=$(bjobs 2>/dev/null | grep -c "PPGsim_\|PPGvdd_\|PPGdut_\|PPG_" || echo 0)
if [ "$running" -gt 0 ]; then
    echo "$(date): $running jobs currently active — waiting..."
    while true; do
        running=$(bjobs 2>/dev/null | grep -c "PPGsim_\|PPGvdd_\|PPGdut_\|PPG_" || echo 0)
        [ "$running" -eq 0 ] && break
        printf "."
        sleep 15
    done
    echo ""
fi

# ── Validate and extract each cell ──────────────────────────────────
> "$RESULT_FILE"
ALL_OK=1

for cell in $CELLS; do
    netlist="$RUNBASE/$cell/$NETLIST"
    lis="$RUNBASE/$cell/$NETLIST.lis"

    # 1. Netlist exists
    if [ ! -f "$netlist" ]; then
        echo "ERROR [$cell]: Netlist not found: $netlist" >&2
        ALL_OK=0; continue
    fi

    # 2. Single active model .inc
    inc_count=$(grep -c "^\.inc.*design_include\.inc" "$netlist" 2>/dev/null || echo 0)
    if [ "$inc_count" -ne 1 ]; then
        echo "ERROR [$cell]: Expected 1 active model .inc line, found $inc_count in $netlist" >&2
        ALL_OK=0; continue
    fi

    # 3. Model name match
    active_inc=$(grep "^\.inc.*design_include\.inc" "$netlist")
    if ! echo "$active_inc" | grep -q "$MODEL_NAME"; then
        echo "ERROR [$cell]: Active .inc does not match MODEL_NAME='$MODEL_NAME'" >&2
        echo "  Active: $active_inc" >&2
        ALL_OK=0; continue
    fi

    # 4. Optional MODEL_INC exact path match
    if [ -n "$MODEL_INC" ] && ! echo "$active_inc" | grep -qF "$MODEL_INC"; then
        echo "ERROR [$cell]: Active .inc does not match exact MODEL_INC" >&2
        ALL_OK=0; continue
    fi

    # 5. .lis output exists
    if [ ! -f "$lis" ]; then
        echo "ERROR [$cell]: Simulation listing not found: $lis" >&2
        ALL_OK=0; continue
    fi

    # 6. Check for HSPICE error markers
    if grep -qi "^\*\*error\|^\* error\|Error:" "$lis" 2>/dev/null; then
        echo "ERROR [$cell]: HSPICE errors found in $lis" >&2
        grep -i "^\*\*error\|^\* error\|Error:" "$lis" | head -5 >&2
        ALL_OK=0; continue
    fi

    # 7. Extract metrics
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
        echo "ERROR [$cell]: stage_delay missing — simulation incomplete" >&2
        ALL_OK=0; continue
    fi

    echo "OK [$cell]: Delay=${sd}ps Ceff=${ceff}fF ACReff=${acreff}kΩ IDDQ=${iddq}nA"
    printf "%s\t%s\t%s\t%s\t%s\n" "$cell" "$sd" "$ceff" "$acreff" "$iddq" >> "$RESULT_FILE"
done

if [ "$ALL_OK" -ne 1 ]; then
    echo "ABORT: One or more cells failed validation. Output NOT finalised." >&2
    exit 1
fi

echo ""
echo "All cells passed validation. Results written to: $RESULT_FILE"
cat "$RESULT_FILE"

# ── 8. Run Automated Consistency Validator on HTML ──────────────────
if [ -f "$SCRIPTDIR/verify_dataset_consistency.js" ]; then
    echo ""
    echo "Running dataset consistency validator..."
    node "$SCRIPTDIR/verify_dataset_consistency.js" "$SCRIPTDIR/index.html" "$SCRIPTDIR/ppg_results.html" || {
        echo "ABORT: Consistency validation failed." >&2
        exit 1
    }
fi
