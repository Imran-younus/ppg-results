#!/bin/ksh
#=============================================================================
# run_v0p6SB2_slvt_vdd_sweep.sh
# Purpose : Run 14-point VDD sweep (336 jobs) for v0.6SB SLVT (Spice-260724-sandbox)
#=============================================================================

SCRIPTDIR=$(cd "$(dirname "$0")" && pwd)

export MODEL_NAME="${MODEL_NAME:-v0p6SB_ELVT}"
export MODEL_INC="${MODEL_INC:-/afs/apd/ant/research/test/2HP/v0.53/Spice-260724-sandbox/design_include.inc}"
export MODEL_LIB="${MODEL_LIB:-/afs/apd/ant/research/test/2HP/v0.53/Spice-260724-sandbox/fixed_corner.lib}"
export VT="${VT:-slvt}"
export VDD="${VDD:-sweep}"
export TEMP="${TEMP:-25}"
export OUTPUT="${OUTPUT:-$SCRIPTDIR/PPGRO_chain_menu14_v0p6SB_slvt.txt}"

exec "$SCRIPTDIR/run_ppg_sim.sh" "$@"
