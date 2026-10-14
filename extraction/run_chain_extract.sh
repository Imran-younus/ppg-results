#!/bin/bash
#=============================================================================
# extraction/run_chain_extract.sh <CELL> [LIB]
#
# Layout cell (CTE/Cadence library) -> ported, simulation-ready SPF for the
# full-DUT chain flow (RPDK0.43 deck). Mirrors the validated F03 run
# (NOTES.md Issue 32/33):
#   1. find schematic sub-cells, copy them to a local library, schCheck+save
#   2. si (auCdl) -> CDL
#   3. oasisout layout -> OASIS
#   4. full ICV LVS (gives agds.gds + LVS net table)
#   5. StarRC PEX (RPDK0.43 V0p42 TCAD) on the LVS outputs
#   6. add '.SUBCKT <cell> ENA VSS VDD RO_OUT' + 4 R_PORT_* 1u bridges using
#      the LVS "schematic port nets equated to layout non-port nets" table
# Output: extraction/ext_<CELL>/<CELL>_ported.spf  (last stdout line PORTED_SPF=<path>)
# Env: LIBNAME (default test_C18mintaka_PPG_ROs). Run from any shell: bash this_script.
#=============================================================================
set -eo pipefail

CELL="${1:-}"
LIB="${2:-${LIBNAME:-test_C18mintaka_PPG_ROs}}"
[ -n "$CELL" ] || { echo "Usage: bash extraction/run_chain_extract.sh <CELL> [LIB]" >&2; exit 1; }

SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$SCRIPTDIR/ext_$CELL"
SHARED="$(grep "^DEFINE $LIB " "$SCRIPTDIR/cds.lib" | awk '{print $3}')"
[ -n "$SHARED" ] && [ -d "$SHARED" ] || { echo "ERROR: library $LIB not defined in $SCRIPTDIR/cds.lib (or dir missing)" >&2; exit 1; }
for v in layout/layout.oa schematic/sch.oa; do
    [ -f "$SHARED/$CELL/$v" ] || { echo "ERROR: $SHARED/$CELL/$v not found - cell needs BOTH layout and schematic views" >&2; exit 1; }
done

TECHDIR="/gpfs/projects/t/titan/dtco/usr/sbajaj/public/PDKs/RPDK0.43/V43"
BEOL_STACK_NAME="20M_6Mx_10Dx_2Kx_2Gx_LB"
TCAD_DIR="$TECHDIR/PEX/StarRC/$BEOL_STACK_NAME/tcad"
LVS_RS="$TECHDIR/LVS/2HP_RPD_ICVLVS_V0p43_0.rs"
LICENSES="27020@riclic.pok.ibm.com:27020@poklnxlic04.pok.ibm.com:27020@cdsserv1.pok.ibm.com:27020@cdsserv2.pok.ibm.com:27020@cdsserv3.pok.ibm.com"

echo "=== Chain extraction: cell=$CELL lib=$LIB  work=$WORK"
rm -rf "$WORK"; mkdir -p "$WORK/lib" "$WORK/LVS" "$WORK/PEX"

# Cadence environment (PATH with virtuoso/si/oasisout, licences)
. "$SCRIPTDIR/env_cds.sh"

# cds.lib helpers: shared library (read only) and local copy (schCheck writes)
mk_cdslib() {   # $1=dir $2=path of LIB
    sed "s|^DEFINE $LIB .*|DEFINE $LIB $2|" "$SCRIPTDIR/cds.lib" > "$1/cds.lib"
}
mk_cdslib "$WORK" "$SHARED"

# ---- [1/7] schematic hierarchy inside LIB --------------------------------
echo "[1/7] Finding schematic sub-cells of $CELL ..."
cat > "$WORK/deps.il" <<EOF
ppgSeen = nil
procedure(ppgDeps(lib cell)
  let((cv)
    unless(member(cell ppgSeen)
      ppgSeen = cons(cell ppgSeen)
      cv = dbOpenCellViewByType(lib cell "schematic" nil "r")
      when(cv
        foreach(inst cv~>instances
          when(equal(inst~>libName lib) ppgDeps(lib inst~>cellName)))
        dbClose(cv)))))
ppgDeps("$LIB" "$CELL")
let((p) p = outfile("$WORK/deps.txt" "w")
  foreach(c ppgSeen fprintf(p "%s\n" c))
  close(p))
exit()
EOF
(cd "$WORK" && timeout 600 virtuoso -nographE -replay deps.il -log deps.log > deps.stdout 2>&1) || true
[ -s "$WORK/deps.txt" ] || { echo "ERROR: could not read schematic hierarchy (see $WORK/deps.log)" >&2; exit 1; }
DEPS="$(cat "$WORK/deps.txt")"
echo "      cells: $(echo $DEPS)"

# ---- [2/7] local library copy + schCheck/save ----------------------------
echo "[2/7] Copying cells to local library and running schCheck ..."
[ -f "$SHARED/.oalib" ] && cp "$SHARED/.oalib" "$WORK/lib/.oalib"
[ -f "$SHARED/data.dm" ] && cp "$SHARED/data.dm" "$WORK/lib/data.dm"
for c in $DEPS; do
    mkdir -p "$WORK/lib/$c"
    for v in layout schematic symbol; do
        [ -d "$SHARED/$c/$v" ] && cp -r "$SHARED/$c/$v" "$WORK/lib/$c/$v"
    done
    [ -f "$SHARED/$c/data.dm" ] && cp "$SHARED/$c/data.dm" "$WORK/lib/$c/data.dm"
done
chmod -R u+w "$WORK/lib"
mk_cdslib "$WORK" "$WORK/lib"
{
    echo "let((cv)"
    printf '  foreach(cn list('
    for c in $DEPS; do printf '"%s" ' "$c"; done
    echo ')'
    echo "    cv = dbOpenCellViewByType(\"$LIB\" cn \"schematic\" nil \"a\")"
    echo '    printf("CELL %s opened=%L\n" cn cv)'
    echo '    when(cv schCheck(cv) dbSave(cv) dbClose(cv))))'
    echo 'exit()'
} > "$WORK/chk.il"
(cd "$WORK" && timeout 600 virtuoso -nographE -replay chk.il -log chk.log > chk.stdout 2>&1) || true
if grep -q "opened=nil" "$WORK/chk.log"; then
    echo "ERROR: a schematic could not be opened (see $WORK/chk.log)" >&2; exit 1
fi

# ---- [3/7] CDL netlist ----------------------------------------------------
echo "[3/7] Netlisting schematic to CDL (si/auCdl) ..."
cat > "$WORK/si.env" <<EOF
simLibName = "$LIB"
simCellName = "$CELL"
simViewName = "schematic"
simSimulator = "auCdl"
simNotIncremental = nil
simReNetlistAll = nil
simViewList = '("auCdl" "schematic")
simStopList = '("auCdl")
hnlNetlistFileName = "$CELL.cdl"
resistorModel = ""
shortRES = 2000.0
preserveRES = 'nil
checkRESVAL = 'nil
checkRESSIZE = 'nil
preserveCAP = 'nil
checkCAPVAL = 'nil
checkCAPAREA = 'nil
preserveDIO = 'nil
checkDIOAREA = 'nil
checkDIOPERI = 'nil
checkCAPPERI = 'nil
simPrintInhConnAttributes = 'nil
checkScale = "meter"
checkLDD = 'nil
pinMAP = 'nil
shrinkFACTOR = 0.0
globalPowerSig = ""
globalGndSig = ""
displayPININFO = 't
preserveALL = 'nil
setEQUIV = ""
incFILE = ""
EOF
(cd "$WORK" && si "$WORK" -batch -command netlist -cdslib "$WORK/cds.lib" > si.stdouterr.log 2>&1) || true
[ -s "$WORK/$CELL.cdl" ] || { echo "ERROR: CDL not created (see $WORK/si.stdouterr.log)" >&2; exit 1; }
grep -q "^\.SUBCKT $CELL " "$WORK/$CELL.cdl" || { echo "ERROR: $WORK/$CELL.cdl has no .SUBCKT $CELL" >&2; exit 1; }
# Chain flow needs a ring cell with ports RO_ENA / RO_OUT (e.g. NAND2_X1_5T_..._F03_...); a single gate (INV_X2_...) is not a ring.
_top="$(grep -m1 "^\.SUBCKT $CELL " "$WORK/$CELL.cdl")"
case "$_top" in
    *RO_ENA*RO_OUT*|*RO_OUT*RO_ENA*) ;;
    *) echo "ERROR: $CELL is not a ring-oscillator cell (top .SUBCKT lacks RO_ENA/RO_OUT): $_top" >&2; exit 1 ;;
esac

# ---- [4/7] OASIS stream-out + full LVS -----------------------------------
echo "[4/7] Streaming out OASIS and running ICV LVS ..."
mk_cdslib "$WORK/LVS" "$SHARED"
cp "$WORK/$CELL.cdl" "$WORK/LVS/"
(cd "$WORK/LVS" && oasisout -enableColoring -runDir "$WORK/LVS" -library "$LIB" -topCell "$CELL" -view layout \
    -oasisFile "$WORK/LVS/$CELL.oas" -logFile oasisout.log > oasisout.stdout 2>&1) || true
[ -s "$WORK/LVS/$CELL.oas" ] || { echo "ERROR: OASIS not created (see $WORK/LVS/oasisout.stdout)" >&2; exit 1; }
(
    cd "$WORK/LVS"
    export ICV_HOME_DIR=/gpfs/projects/t/tools/Synopsys/icvalidator/W-2024.09-SP4-1
    export PATH="$ICV_HOME_DIR/bin:$ICV_HOME_DIR/bin/LINUX.64:$PATH"
    . /gsa/pokgsa/projects/p/pde/cte_tech/1p4/tools/cte/LVST/sourceme_LVS
    export SNPSLMD_LICENSE_FILE="$LICENSES"
    export TECHDIR BEOL_STACK="$BEOL_STACK_NAME" SYNOPSYS_INCPATH="$TECHDIR/LVS/Include"
    export CONNECT_BY_NET=TRUE USE_EXPLODED_TEXT=FALSE VIRTUALCONNECT=TRUE CDS_Netlisting_Mode=Analog
    export ICV_RUNSET_CACHE_DIR="$PWD/.cache" ICV_RUNSET_CACHE_MAXFILES=5
    mkdir -p .cache
    icv -stc "$CELL" -vue -host_init 2 -rd "$PWD/run_details" -sf SPICE -f OASIS -c "$CELL" \
        -i "$PWD/$CELL.oas" -s "$PWD/$CELL.cdl" -I "$TECHDIR/LVS" "$LVS_RS" > icv.stdouterr.log 2>&1 || true
)
LVSERR="$WORK/LVS/$CELL.LVS_ERRORS"
[ -f "$LVSERR" ] && [ -f "$WORK/LVS/agds.gds" ] || { echo "ERROR: LVS produced no LVS_ERRORS/agds.gds (see $WORK/LVS/icv.stdouterr.log)" >&2; exit 1; }

# ---- [5/7] LVS topology gate ---------------------------------------------
echo "[5/7] Checking LVS topology ..."
BAD="$(grep -E '^ +[0-9]+ Unmatched (schematic|layout) (instance|net)' "$LVSERR" | awk '$1 != 0' || true)"
if [ -n "$BAD" ]; then
    echo "ERROR: LVS has unmatched devices/nets - layout and schematic differ, extraction not trusted:" >&2
    echo "$BAD" >&2
    echo "       See $LVSERR ('open layout nets' diagnostics). The layout pulls pcells from shared libraries" >&2
    echo "       (e.g. C18mintaka_SA_pcells, edited by other users): if they changed since the last good run" >&2
    echo "       the same cell can stop matching (seen 2026-10-14, NOTES.md Issue 34). Ask the layout owner." >&2
    exit 1
fi
grep -E "Matched instances|Matched nets|Matched ports" "$LVSERR" | sed 's/^/      /'

# ---- [6/7] StarRC ---------------------------------------------------------
echo "[6/7] Running StarRC PEX ..."
for f in agds.gds NS_PROCESS_MAP NS_RCXT_REPORT agds_cell_extents agds_cell_port; do
    [ -f "$WORK/LVS/$f" ] && cp "$WORK/LVS/$f" "$WORK/PEX/$f"
done
cat > "$WORK/PEX/star_cmd" <<EOF
* StarRC command file
BLOCK: $CELL
TCAD_GRD_FILE: $TCAD_DIR/2HP_RPD_StarRC_${BEOL_STACK_NAME}_V0p42_0.nxtgrd
MAPPING_FILE: $TCAD_DIR/2HP_RPD_StarRC_${BEOL_STACK_NAME}_V0p42_0.mapfile
EXTRACTION: RC
OPERATING_TEMPERATURE: 25

ICV_RUNSET_REPORT_FILE:NS_RCXT_REPORT
GDS_LAYER_MAP_FILE:NS_PROCESS_MAP
GDS_FILE:agds.gds
IGNORE_CAPACITANCE:ALL
IGNORE_FIELDPOLY_DIFFUSION_COUPLING:NO
FS_VISUALIZATION: NO
FS_DP_STRING: list localhost:16
PRINT_FSCOMPARE_REPORT: NO
FSCOMPARE_THRESHOLD: 0
FSCOMPARE_COUPLING_THRESHOLD: 0
FSCOMPARE_COUPLING_RATIO: 0
TRENCH_CONTACT_VIRTUAL_VIA_SEGMENTATION_RATIO: 1
NETLIST_PASSIVE_PARAMS:YES
TRANSLATE_RETAIN_BULK_LAYERS: YES
TRANSLATE_FLOATING_AS_FILL: YES
SKIP_CELLS: *!
MULTIGATE_MODELS: YES
COUPLE_TO_GROUND: NO
COUPLING_ABS_THRESHOLD: 0.00
COUPLING_REL_THRESHOLD: 0.00
COUPLING_REPORT_FILE: coupling.txt
NETLIST_FORMAT: NETNAME
EXTRACT_VIA_CAPS:YES
CASE_SENSITIVE: NO
NETLIST_TAIL_COMMENTS: YES
CAPACITOR_TAIL_COMMENTS:YES
PRINT_SILICON_INFO:YES
NETLIST_DEVICE_LOCATION_ORIENTATION: COMMENT
SNAP_RESISTOR_WIDTH: NO
NETLIST_NODE_SECTION: NO
EXTRA_GEOMETRY_INFO: NONE
XTOR_GPD: NO
TEMPERATURE_SENSITIVITY: YES
REDUCTION: LAYER
POWER_NETS: VDD VSS
POWER_EXTRACT: YES
XREF: NO
EOF
(
    cd "$WORK/PEX"
    export STAR_HOME_DIR=/gpfs/projects/t/tools/Synopsys/starrc/X-2025.06-SP2-1
    export PATH="$STAR_HOME_DIR/bin:$STAR_HOME_DIR/linux64_starrc/bin:$PATH"
    export SNPSLMD_LICENSE_FILE="$LICENSES"
    StarXtract -clean star_cmd > StarXtract.stdout 2>&1 || true
)
RAWSPF="$WORK/PEX/$CELL.spf"
[ -s "$RAWSPF" ] || { echo "ERROR: StarRC produced no SPF (tail of $WORK/PEX/StarXtract.stdout):" >&2; tail -n 20 "$WORK/PEX/StarXtract.stdout" >&2; exit 1; }
TCAD="$(grep -m1 TCAD_GRD_FILE "$RAWSPF" | awk '{print $NF}')"
case "$TCAD" in *V0p42*) ;; *) echo "ERROR: SPF TCAD header is not RPDK0.43 (V0p42): $TCAD (Issue 29)" >&2; exit 1 ;; esac
echo "      TCAD: $TCAD"

# ---- [7/7] port bridging (Issue 33) --------------------------------------
echo "[7/7] Adding SUBCKT ports and R_PORT_* bridges from the LVS net table ..."
TABLE="$(awk '/schematic port nets equated to layout non-port nets/{f=1;next}
              f && NF==2 && $2 ~ /^[0-9]+$/ {print $1, $2}
              f && /untexted layout ports/{exit}' "$LVSERR")"
[ -n "$TABLE" ] || { echo "ERROR: no 'port nets equated to layout non-port nets' table in $LVSERR - cannot derive ports (see NOTES.md Issue 33)" >&2; exit 1; }
NET_ENA=""; NET_VSS=""; NET_VDD=""; NET_OUT=""
while read -r pname pnet; do
    case "$pname" in
        *ENA*)       NET_ENA="$pnet" ;;
        *OUT*)       NET_OUT="$pnet" ;;
        *VDD*)       NET_VDD="$pnet" ;;
        *VSS*|*GND*) NET_VSS="$pnet" ;;
    esac
done <<EOF
$TABLE
EOF
for n in "$NET_ENA" "$NET_VSS" "$NET_VDD" "$NET_OUT"; do
    [ -n "$n" ] || { echo "ERROR: could not map all of ENA/VSS/VDD/RO_OUT from LVS table:" >&2; echo "$TABLE" >&2; exit 1; }
done
echo "      LVS nets: ENA=$NET_ENA VSS=$NET_VSS VDD=$NET_VDD RO_OUT=$NET_OUT"

# hub node = most referenced '<net>:<id>' token outside comments
HUBS="$(awk -v nets="$NET_ENA $NET_VSS $NET_VDD $NET_OUT" '
    BEGIN { n = split(nets, a, " "); for (i = 1; i <= n; i++) want[a[i]] = 1 }
    /^\*/ { next }
    { for (i = 1; i <= NF; i++) if ($i ~ /^[0-9]+:[A-Za-z0-9_]+$/) { split($i, p, ":"); if (p[1] in want) cnt[$i]++ } }
    END { for (t in cnt) { split(t, p, ":"); k = p[1]
            if (cnt[t] > best[k] || (cnt[t] == best[k] && t < hub[k])) { best[k] = cnt[t]; hub[k] = t } }
          for (k in hub) print k, hub[k] }' "$RAWSPF")"
hub_of() { echo "$HUBS" | awk -v n="$1" '$1 == n {print $2}'; }
H_ENA="$(hub_of "$NET_ENA")"; H_VSS="$(hub_of "$NET_VSS")"; H_VDD="$(hub_of "$NET_VDD")"; H_OUT="$(hub_of "$NET_OUT")"
for h in "$H_ENA" "$H_VSS" "$H_VDD" "$H_OUT"; do
    [ -n "$h" ] || { echo "ERROR: no SPF node found for one of the LVS port nets ($HUBS)" >&2; exit 1; }
done
echo "      bridge nodes: ENA=$H_ENA VSS=$H_VSS VDD=$H_VDD RO_OUT=$H_OUT"

PORTED="$WORK/${CELL}_ported.spf"
awk -v cell="$CELL" -v ena="$H_ENA" -v vss="$H_VSS" -v vdd="$H_VDD" -v out="$H_OUT" '
    $0 == ".SUBCKT " cell { print $0 " ENA VSS VDD RO_OUT"; next }
    /^\.ENDS/ && !done {
        print "* Port bridging (LVS-mapped nets)"
        print "R_PORT_ENA ENA " ena " 1u"
        print "R_PORT_VSS VSS " vss " 1u"
        print "R_PORT_VDD VDD " vdd " 1u"
        print "R_PORT_OUT RO_OUT " out " 1u"
        print ""
        done = 1
    }
    { print }' "$RAWSPF" > "$PORTED"
grep -q "^\.SUBCKT $CELL ENA VSS VDD RO_OUT\$" "$PORTED" && [ "$(grep -c '^R_PORT_' "$PORTED")" -eq 4 ] \
    || { echo "ERROR: port insertion failed in $PORTED" >&2; exit 1; }

# disk hygiene: keep logs + ported SPF, drop big intermediates
rm -rf "$WORK/PEX/star" "$WORK/PEX/agds."* "$WORK/PEX/coupling.txt" "$WORK/LVS/run_details" "$WORK/LVS/.cache" \
       "$WORK/LVS/agds."* "$WORK/LVS/$CELL.net" "$WORK/LVS/$CELL.net.gz" "$WORK/LVS/$CELL.LAYOUT_ERRORS" "$RAWSPF"

echo "=== Extraction done: $(ls -lh "$PORTED" | awk '{print $5}')"
echo "PORTED_SPF=$PORTED"
