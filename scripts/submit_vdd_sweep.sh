#!/bin/ksh
#=============================================================================
# submit_vdd_sweep.sh
# Submits all 336 LSF jobs (14 voltages x 24 cells) and writes
# run_vdd/SUBMITTED when done. Run detached: nohup ksh submit_vdd_sweep.sh &
#=============================================================================
SCRIPTDIR='/afs/apd.pok.ibm.com/u/imranyou/for_imran'
SPFDIR='/gpfs/projects/t/titan/dtco/usr/sbajaj/SPF_files/tpdk0.6sb'
BASESP="$SCRIPTDIR/invfo3_base.sp"
SPF_OUT='PPGchain.spf'
NETLIST='invfo3_mod.sp'
HSPICE_BIN='/afs/apd.pok.ibm.com/ant/cad_tools/synopsys/Hspice/T-2022.06-SP2/hspice/hspice/T-2022.06-SP2/hspice/bin'
LSF_SELECT='(osver==rh8) && (type == X86_64) && ! etx && ! nojobs'
LSF_JOBPREFIX='PPGvdd'
VOLTAGES='0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0 1.05 1.1 1.15'
SUBCKT_SED_1='s/\.SUBCKT \([0-9a-zA-Z*_]*\) Z VDD A VSS/.SUBCKT \1 VSS VDD A Z/g'
SUBCKT_SED_2='s/\.SUBCKT \([0-9a-zA-Z*_]*\) VDD Z A VSS/.SUBCKT \1 VSS VDD A Z/g'
SUBCKT_SED_3='s/\.SUBCKT \([0-9a-zA-Z*_]*\) A VDD Z VSS/.SUBCKT \1 VSS VDD A Z/g'
VT_SED_N='s^.slvtnfet^ ulvtnfet^'
VT_SED_P='s^.slvtpfet^ ulvtpfet^'

mkdir -p $SCRIPTDIR/run_vdd
rm -f $SCRIPTDIR/run_vdd/SUBMITTED
echo "Starting submission at $(date)" > $SCRIPTDIR/run_vdd/submit.log

for vdd in $VOLTAGES; do
    vdd_tag=$(echo $vdd | sed 's/\./_/g')
    vdd_dir="$SCRIPTDIR/run_vdd/$vdd_tag"
    mkdir -p $vdd_dir
    TEMPLATE="$vdd_dir/invfo3_sweep.sp"
    sed "s|\.param PVDD=[0-9][0-9.]*|.param PVDD=$vdd|" < $BASESP > $TEMPLATE

    for entry in \
        "6TSL_INV    $SPFDIR/PPG1_INV_X2_6TSL.spf         PPG1_INV_X2_6TSL" \
        "6TSL_NAND2B $SPFDIR/PPG1_NAND2_X1_B_6TSL.spf    PPG1_NAND2_X1_B_6TSL" \
        "6TSL_NOR2B  $SPFDIR/PPG1_NOR2_X1_B_6TSL.spf     PPG1_NOR2_X1_B_6TSL" \
        "6TSL_NAND3B $SPFDIR/PPG1_NAND3_X1_B_6TSL.spf    PPG1_NAND3_X1_B_6TSL" \
        "6TSL_AOI21  $SPFDIR/PPG1_AOI21_X1_1S0_6TSL.spf  PPG1_AOI21_X1_1S0_6TSL" \
        "6TSL_AOI22  $SPFDIR/PPG1_AOI22_X1_S110_6TSL.spf PPG1_AOI22_X1_S110_6TSL" \
        "6TSL_OAI21  $SPFDIR/PPG1_OAI21_X1_0S1_6TSL.spf  PPG1_OAI21_X1_0S1_6TSL" \
        "6TSL_OAI22  $SPFDIR/PPG1_OAI22_X1_0S11_6TSL.spf PPG1_OAI22_X1_0S11_6TSL" \
        "7TSL_INV    $SPFDIR/PPG1_INV_X2_7TSL.spf         PPG1_INV_X2_7TSL" \
        "7TSL_NAND2B $SPFDIR/PPG1_NAND2_X1_B_7TSL.spf    PPG1_NAND2_X1_B_7TSL" \
        "7TSL_NOR2B  $SPFDIR/PPG1_NOR2_X1_B_7TSL.spf     PPG1_NOR2_X1_B_7TSL" \
        "7TSL_NAND3B $SPFDIR/PPG1_NAND3_X1_B_7TSL.spf    PPG1_NAND3_X1_B_7TSL" \
        "7TSL_AOI21  $SPFDIR/PPG1_AOI21_X1_1S0_7TSL.spf  PPG1_AOI21_X1_1S0_7TSL" \
        "7TSL_AOI22  $SPFDIR/PPG1_AOI22_X1_S110_7TSL.spf PPG1_AOI22_X1_S110_7TSL" \
        "7TSL_OAI21  $SPFDIR/PPG1_OAI21_X1_0S1_7TSL.spf  PPG1_OAI21_X1_0S1_7TSL" \
        "7TSL_OAI22  $SPFDIR/PPG1_OAI22_X1_0S11_7TSL.spf PPG1_OAI22_X1_0S11_7TSL" \
        "8TSL_INV    $SPFDIR/PPG1_INV_X2_8TSL.spf         PPG1_INV_X2_8TSL" \
        "8TSL_NAND2B $SPFDIR/PPG1_NAND2_X1_B_8TSL.spf    PPG1_NAND2_X1_B_8TSL" \
        "8TSL_NOR2B  $SPFDIR/PPG1_NOR2_X1_B_8TSL.spf     PPG1_NOR2_X1_B_8TSL" \
        "8TSL_NAND3B $SPFDIR/PPG1_NAND3_X1_B_8TSL.spf    PPG1_NAND3_X1_B_8TSL" \
        "8TSL_AOI21  $SPFDIR/PPG1_AOI21_X1_1S0_8TSL.spf  PPG1_AOI21_X1_1S0_8TSL" \
        "8TSL_AOI22  $SPFDIR/PPG1_AOI22_X1_S110_8TSL.spf PPG1_AOI22_X1_S110_8TSL" \
        "8TSL_OAI21  $SPFDIR/PPG1_OAI21_X1_0S1_8TSL.spf  PPG1_OAI21_X1_0S1_8TSL" \
        "8TSL_OAI22  $SPFDIR/PPG1_OAI22_X1_0S11_8TSL.spf PPG1_OAI22_X1_0S11_8TSL"
    do
        label=$(echo $entry | awk '{print $1}')
        spf_file=$(echo $entry | awk '{print $2}')
        subckt=$(echo $entry | awk '{print $3}')
        rundir="$vdd_dir/$label"
        mkdir -p $rundir

        sed -e "$SUBCKT_SED_1" -e "$SUBCKT_SED_2" -e "$SUBCKT_SED_3" \
            -e "$VT_SED_N" -e "$VT_SED_P" \
            < $spf_file > $rundir/$SPF_OUT

        sed -e "s^.Titan_spf^ $rundir/$SPF_OUT^" \
            -e "s^.Titan_RO^ $subckt^" \
            < $TEMPLATE > $rundir/$NETLIST

        cat > $rundir/run_hsp.sh << WRAPPER
#!/bin/ksh
export PATH=${HSPICE_BIN}:$PATH
export LM_LICENSE_FILE=$LM_LICENSE_FILE
$SCRIPTDIR/hsp_2022_new $rundir/$NETLIST
WRAPPER
        chmod +x $rundir/run_hsp.sh

        bsub -J "${LSF_JOBPREFIX}_${vdd_tag}_${label}" \
             -M 128 -n 8 -W 4:00 \
             -R "select[ $LSF_SELECT ]" \
             -cwd "$rundir" \
             "ksh $rundir/run_hsp.sh" >> $SCRIPTDIR/run_vdd/submit.log 2>&1
    done
    echo "  Submitted vdd=$vdd at $(date)" >> $SCRIPTDIR/run_vdd/submit.log
done

echo "All 336 jobs submitted at $(date)" >> $SCRIPTDIR/run_vdd/submit.log
touch $SCRIPTDIR/run_vdd/SUBMITTED
