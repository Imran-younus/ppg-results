#!/bin/ksh
#=============================================================================
# collect_vdd_sweep.sh
# Waits for all PPGvdd_* LSF jobs to finish, then collects results into
# PPGRO_chain_menu14.txt. Run detached: nohup ksh collect_vdd_sweep.sh &
#=============================================================================
SCRIPTDIR='/afs/apd.pok.ibm.com/u/imranyou/for_imran'
NETLIST='invfo3_mod.sp'
RESULTS14="$SCRIPTDIR/PPGRO_chain_menu14.txt"
VOLTAGES='0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0 1.05 1.1 1.15'
CELLS='6TSL_INV 6TSL_NAND2B 6TSL_NOR2B 6TSL_NAND3B 6TSL_AOI21 6TSL_AOI22 6TSL_OAI21 6TSL_OAI22
       7TSL_INV 7TSL_NAND2B 7TSL_NOR2B 7TSL_NAND3B 7TSL_AOI21 7TSL_AOI22 7TSL_OAI21 7TSL_OAI22
       8TSL_INV 8TSL_NAND2B 8TSL_NOR2B 8TSL_NAND3B 8TSL_AOI21 8TSL_AOI22 8TSL_OAI21 8TSL_OAI22'

echo "Collect script started at $(date)" > $SCRIPTDIR/run_vdd/collect.log

# Wait for SUBMITTED sentinel — submission loop must finish first
echo "Waiting for all jobs to be submitted..." >> $SCRIPTDIR/run_vdd/collect.log
while [[ ! -f $SCRIPTDIR/run_vdd/SUBMITTED ]]; do
    sleep 15
done
echo "Submission complete. Now waiting for LSF jobs..." >> $SCRIPTDIR/run_vdd/collect.log

# Wait for all PPGvdd_* jobs to finish
sleep 15
while [[ $(bjobs 2>/dev/null | grep -c "PPGvdd_") -gt 0 ]]; do
    sleep 15
done
echo "All LSF jobs done at $(date). Collecting results..." >> $SCRIPTDIR/run_vdd/collect.log

# Collect results — tab-separated, one column per voltage
printf "" > $RESULTS14

for label in $CELLS; do
    {
        printf "%s" "$label"
        for vdd in $VOLTAGES; do
            vdd_tag=$(echo $vdd | sed 's/\./_/g')
            lisfile="$SCRIPTDIR/run_vdd/$vdd_tag/$label/${NETLIST}.lis"
            val=$(grep "stage_delay=" $lisfile 2>/dev/null | awk '{print $NF}')
            printf "\t%s" "${val:--}"
        done
        printf "\n"

        printf "%s_iddq" "$label"
        for vdd in $VOLTAGES; do
            vdd_tag=$(echo $vdd | sed 's/\./_/g')
            lisfile="$SCRIPTDIR/run_vdd/$vdd_tag/$label/${NETLIST}.lis"
            val=$(grep "iddq=" $lisfile 2>/dev/null | awk '{print $NF}')
            printf "\t%s" "${val:--}"
        done
        printf "\n"

        printf "%s_iddarail" "$label"
        for vdd in $VOLTAGES; do
            vdd_tag=$(echo $vdd | sed 's/\./_/g')
            lisfile="$SCRIPTDIR/run_vdd/$vdd_tag/$label/${NETLIST}.lis"
            val=$(grep "iddarail_qcorr=" $lisfile 2>/dev/null | awk '{print $NF}')
            printf "\t%s" "${val:--}"
        done
        printf "\n"

        printf "%s_acceff" "$label"
        for vdd in $VOLTAGES; do
            vdd_tag=$(echo $vdd | sed 's/\./_/g')
            lisfile="$SCRIPTDIR/run_vdd/$vdd_tag/$label/${NETLIST}.lis"
            val=$(grep "acceffrail_qcorr=" $lisfile 2>/dev/null | awk '{print $NF}')
            printf "\t%s" "${val:--}"
        done
        printf "\n"

        printf "%s_acreff" "$label"
        for vdd in $VOLTAGES; do
            vdd_tag=$(echo $vdd | sed 's/\./_/g')
            lisfile="$SCRIPTDIR/run_vdd/$vdd_tag/$label/${NETLIST}.lis"
            val=$(grep "acreffrail_qcorr=" $lisfile 2>/dev/null | awk '{print $NF}')
            printf "\t%s" "${val:--}"
        done
        printf "\n"
    } >> $RESULTS14
done

echo "Collection complete at $(date). Results in $RESULTS14" >> $SCRIPTDIR/run_vdd/collect.log
touch $SCRIPTDIR/run_vdd/DONE
