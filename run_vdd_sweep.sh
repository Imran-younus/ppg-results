#!/bin/ksh
#=============================================================================
# run_vdd_sweep.sh
# Purpose : Convenience wrapper — run a 14-point VDD sweep via ppg_run.sh
#           in non-interactive mode by setting all env vars upfront.
#
# Usage:
#   MODEL_NAME=v0.6SB ksh run_vdd_sweep.sh          # use a known model
#   MODEL_NAME=v0.7 MODEL_INC=... MODEL_LIB=... ksh run_vdd_sweep.sh
#
# All env vars can be overridden before calling this script.
# Results written to results/PPGRO_chain_menu14_<MODEL>_slvt.txt
#=============================================================================

SCRIPTDIR=$(cd "$(dirname "$0")" && pwd)

export MODEL_NAME="${MODEL_NAME:-v0.6SB}"
export MODEL_INC="${MODEL_INC:-/afs/apd/ant/research/test/2HP/v0.53/Spice-260724-sandbox/design_include.inc}"
export MODEL_LIB="${MODEL_LIB:-/afs/apd/ant/research/test/2HP/v0.53/Spice-260724-sandbox/fixed_corner.lib}"
export VT="${VT:-slvt}"
export VDD="${VDD:-sweep}"
export TEMP="${TEMP:-25}"
export OUTPUT="${OUTPUT:-$SCRIPTDIR/results/PPGRO_chain_menu14_${MODEL_NAME}_${VT}.txt}"

# Note: set SPFDIR and SPF_TCAD_EXPECT before calling this script for new models.
# See NOTES.md Issue 21 for the authoritative model/SPF table.
export SPFDIR="${SPFDIR:-}"
export SPF_TCAD_EXPECT="${SPF_TCAD_EXPECT:-}"
if [ -z "$SPFDIR" ]; then
    echo "WARNING: SPFDIR is not set. Simulation will use DEFAULT_SPFDIR (V0.61 parasitics)." >&2
    echo "         Set SPFDIR and SPF_TCAD_EXPECT before running. See NOTES.md Issue 21." >&2
fi

mkdir -p "$SCRIPTDIR/results"

# Delegate to the archive engine directly (non-interactive).
# For interactive use with prompts, prefer: ksh ppg_run.sh
exec ksh "$SCRIPTDIR/archive/run_ppg_sim.sh" "$@"
