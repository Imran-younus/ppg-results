#!/bin/ksh
# Run v0.6SB SLVT VDD sweep using the parameterised flow.
# Model: v0.6SB with ELVT flavor (NFET and PFET 60 mV Vtsat) — Spice-260724-sandbox
# SPF files are already SLVT — copied as-is, no Vt substitution.
# Drives all 336 jobs (24 cells x 14 VDD), then collects results into
# PPGRO_chain_menu14_v0p6SB_slvt.txt
#
# See NOTES.md for known issues:
#   §1 — LM_LICENSE_FILE is empty; use _LM_LICENSE from ppg_sim_lib.sh
#   §2 — DP ignored on this cluster; results are in *.sp.lis not *_dp.lis

SCRIPTDIR='/afs/apd.pok.ibm.com/u/imranyou/for_imran'
. "$SCRIPTDIR/ppg_sim_lib.sh"

export MODEL_INC='/afs/apd/ant/research/test/2HP/v0.53/Spice-260724-sandbox/design_include.inc'
export MODEL_LIB='/afs/apd/ant/research/test/2HP/v0.53/Spice-260724-sandbox/fixed_corner.lib'
export MODEL_NAME='v0p6SB_ELVT'

validate_model_params

SPFDIR='/gpfs/projects/t/titan/dtco/usr/sbajaj/SPF_files/tpdk0.6sb'
BASESP="$SCRIPTDIR/invfo3_base.sp"
RUNDIR="$SCRIPTDIR/run_vdd_v0p6SB_slvt"
NETLIST='invfo3_mod.sp'
SPF_OUT='PPGchain.spf'
RESULTS="$SCRIPTDIR/PPGRO_chain_menu14_v0p6SB_slvt.txt"
LSF_SELECT='(osver==rh8) && (type == X86_64) && ! etx && ! nojobs'
LSF_JOBPREFIX='PPGv2sl'
HSPICE_BIN='/afs/apd.pok.ibm.com/ant/cad_tools/synopsys/Hspice/T-2022.06-SP2/hspice/hspice/T-2022.06-SP2/hspice/bin'
VOLTAGES='0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0 1.05 1.1 1.15'

CELL_ENTRIES="
6TSL_INV    $SPFDIR/PPG1_INV_X2_6TSL.spf          PPG1_INV_X2_6TSL
6TSL_NAND2B $SPFDIR/PPG1_NAND2_X1_B_6TSL.spf      PPG1_NAND2_X1_B_6TSL
6TSL_NOR2B  $SPFDIR/PPG1_NOR2_X1_B_6TSL.spf       PPG1_NOR2_X1_B_6TSL
6TSL_NAND3B $SPFDIR/PPG1_NAND3_X1_B_6TSL.spf      PPG1_NAND3_X1_B_6TSL
6TSL_AOI21  $SPFDIR/PPG1_AOI21_X1_1S0_6TSL.spf    PPG1_AOI21_X1_1S0_6TSL
6TSL_AOI22  $SPFDIR/PPG1_AOI22_X1_S110_6TSL.spf   PPG1_AOI22_X1_S110_6TSL
6TSL_OAI21  $SPFDIR/PPG1_OAI21_X1_0S1_6TSL.spf    PPG1_OAI21_X1_0S1_6TSL
6TSL_OAI22  $SPFDIR/PPG1_OAI22_X1_0S11_6TSL.spf   PPG1_OAI22_X1_0S11_6TSL
7TSL_INV    $SPFDIR/PPG1_INV_X2_7TSL.spf          PPG1_INV_X2_7TSL
7TSL_NAND2B $SPFDIR/PPG1_NAND2_X1_B_7TSL.spf      PPG1_NAND2_X1_B_7TSL
7TSL_NOR2B  $SPFDIR/PPG1_NOR2_X1_B_7TSL.spf       PPG1_NOR2_X1_B_7TSL
7TSL_NAND3B $SPFDIR/PPG1_NAND3_X1_B_7TSL.spf      PPG1_NAND3_X1_B_7TSL
7TSL_AOI21  $SPFDIR/PPG1_AOI21_X1_1S0_7TSL.spf    PPG1_AOI21_X1_1S0_7TSL
7TSL_AOI22  $SPFDIR/PPG1_AOI22_X1_S110_7TSL.spf   PPG1_AOI22_X1_S110_7TSL
7TSL_OAI21  $SPFDIR/PPG1_OAI21_X1_0S1_7TSL.spf    PPG1_OAI21_X1_0S1_7TSL
7TSL_OAI22  $SPFDIR/PPG1_OAI22_X1_0S11_7TSL.spf   PPG1_OAI22_X1_0S11_7TSL
8TSL_INV    $SPFDIR/PPG1_INV_X2_8TSL.spf          PPG1_INV_X2_8TSL
8TSL_NAND2B $SPFDIR/PPG1_NAND2_X1_B_8TSL.spf      PPG1_NAND2_X1_B_8TSL
8TSL_NOR2B  $SPFDIR/PPG1_NOR2_X1_B_8TSL.spf       PPG1_NOR2_X1_B_8TSL
8TSL_NAND3B $SPFDIR/PPG1_NAND3_X1_B_8TSL.spf      PPG1_NAND3_X1_B_8TSL
8TSL_AOI21  $SPFDIR/PPG1_AOI21_X1_1S0_8TSL.spf    PPG1_AOI21_X1_1S0_8TSL
8TSL_AOI22  $SPFDIR/PPG1_AOI22_X1_S110_8TSL.spf   PPG1_AOI22_X1_S110_8TSL
8TSL_OAI21  $SPFDIR/PPG1_OAI21_X1_0S1_8TSL.spf    PPG1_OAI21_X1_0S1_8TSL
8TSL_OAI22  $SPFDIR/PPG1_OAI22_X1_0S11_8TSL.spf   PPG1_OAI22_X1_0S11_8TSL
"

mkdir -p "$RUNDIR"
echo "Submitting 336 jobs: model=$MODEL_NAME  prefix=${LSF_JOBPREFIX}_"

for vdd in $VOLTAGES; do
    vdd_tag=$(echo "$vdd" | sed 's/\./_/g')
    vdd_dir="$RUNDIR/$vdd_tag"
    mkdir -p "$vdd_dir"

    # Per-voltage template: inject PVDD and MODEL_INC/LIB from BASESP
    TEMPLATE="$vdd_dir/invfo3_sweep.sp"
    patch_netlist "$BASESP" "$TEMPLATE" "" "" "$vdd"

    echo "$CELL_ENTRIES" | while read label spf_file subckt; do
        [ -z "$label" ] && continue
        rundir="$vdd_dir/$label"
        mkdir -p "$rundir"

        # SLVT SPF files — reorder terminals to VSS VDD A Z but preserve slvt device names.
        # Do NOT call process_spf (which also substitutes slvt→ulvt — wrong for SLVT).
        process_spf_slvt "$spf_file" "$rundir/$SPF_OUT"

        # Patch per-cell netlist from per-voltage template; verify model
        patch_netlist "$TEMPLATE" "$rundir/$NETLIST" "$rundir/$SPF_OUT" "$subckt"

        # Write per-job wrapper with hardcoded license (_LM_LICENSE from lib)
        cat > "$rundir/run_hsp.sh" << WRAPPER
#!/bin/ksh
export PATH=${HSPICE_BIN}:$PATH
export LM_LICENSE_FILE=${_LM_LICENSE}
$SCRIPTDIR/hsp_2022_new $rundir/$NETLIST
WRAPPER
        chmod +x "$rundir/run_hsp.sh"

        bsub -J "${LSF_JOBPREFIX}_${vdd_tag}_${label}" \
             -M 128 -n 8 -W 4:00 \
             -R "select[ $LSF_SELECT ]" \
             -cwd "$rundir" \
             "ksh $rundir/run_hsp.sh"
    done
done

# Wait for all jobs
wait_for_jobs "$LSF_JOBPREFIX"

# Collect results
# NOTE: DP is always ignored on this cluster; results are in invfo3_mod.sp.lis (see NOTES.md §2)
CELLS='6TSL_INV 6TSL_NAND2B 6TSL_NOR2B 6TSL_NAND3B 6TSL_AOI21 6TSL_AOI22 6TSL_OAI21 6TSL_OAI22
       7TSL_INV 7TSL_NAND2B 7TSL_NOR2B 7TSL_NAND3B 7TSL_AOI21 7TSL_AOI22 7TSL_OAI21 7TSL_OAI22
       8TSL_INV 8TSL_NAND2B 8TSL_NOR2B 8TSL_NAND3B 8TSL_AOI21 8TSL_AOI22 8TSL_OAI21 8TSL_OAI22'

printf "" > "$RESULTS"
echo "Collecting results -> $RESULTS"

for label in $CELLS; do
    {
        printf "%s" "$label"
        for vdd in $VOLTAGES; do
            vdd_tag=$(echo "$vdd" | sed 's/\./_/g')
            lis=$(LIS_FILE "$RUNDIR/$vdd_tag/$label/$NETLIST")
            val=$(grep "stage_delay=" "$lis" 2>/dev/null | awk '{print $NF}')
            printf "\t%s" "${val:--}"
        done
        printf "\n"

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

echo "Done. Results: $RESULTS"
