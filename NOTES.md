# PPG Simulation Flow — Known Issues & Fixes

This file exists so that bugs already diagnosed and fixed are not re-investigated
from scratch in new sessions.  Update this whenever a new root cause is found.

---
## START HERE — which kind of simulation was requested? (added 2026-10-14)

There are TWO different simulation requests. Never mix their scripts, run dirs, result files or website fields.

| | **A. Single-stage VDD sweep** | **B. Full DUT 101-stage chain** |
|---|---|---|
| Typical wording | "run model X", "single stage", "24 cells", "VDD sweep for TPDK/RPDK" | "chain", "full DUT", "101 stage", "ring oscillator", "NAND2_F03 / layout SPF", "at 0.7 V" |
| What is simulated | 24 cells (6/7/8TSL x INV,NAND2B,NOR2B,NAND3B,AOI21,AOI22,OAI21,OAI22), one stage | ONE extracted layout ring (enable NAND2 + 100 INV + buffer), 101 stages |
| Voltages | normally 14-point sweep 0.50-1.15 V (336 jobs) | ANY: one VDD (default 0.70), a list, or `sweep`. Do not assume 14 points; do not assume 0.70 either - take what the user asked |
| Parasitics | `SPFDIR` of per-cell `PPG1_*` SPFs (Issue 21) | ONE layout SPF of the whole ring (`-s`), ports must be bridged (Issue 33) |
| Script | `run_ppg_sim.sh` | `full_dut/run_ppg_dut.sh` (NOT `collect_chain_and_push.sh`, Issue 23; NOT `full_dut/PPGRO_DUT_...sweep...`, hardcoded) |
| Run dir | `run_vdd_<model>_slvt/<vdd_tag>/<cell>/` | `full_dut/run_dut_<model>_<cellname>/<vdd_tag>/` |
| Result file | `PPGRO_chain_menu14_<model>_slvt.txt` | `full_dut/results_dut_<model>_<cellname>.txt` (or `-o`) |
| Metrics | stage_delay, iddq, iddarail, acceff, acreff | stage_delay, stage_freq, idda, iddq_stage, ceff, acreff |
| Website | `registerDataset(...)` via `add_dataset_to_html.py`; no chain fields (Issue 17/24) | `chain_cells` row inside the SAME model's dataset (`v0p43_SLVT_TT`) + `chain_meta`; edited by hand (no script) |
| Success | exit 0 and no `.missing` | `.lis` exists for every VDD, 0 `failed`, numeric stage_delay/ceff/acreff/iddq_stage |

If the request is ambiguous (e.g. just "run v0.43"), ask which of A or B. "chain at 0.7 V" is B, not a one-point A.

### Runbook A — single-stage VDD sweep (summary; full text in "Runbook — single-stage sweep" below, Issues 21/27/29)
1. Model row from Issue 21 table (MODEL_NAME, MODEL_INC, MODEL_LIB, SPFDIR, SPF_TCAD_EXPECT). Unknown model -> ask.
2. `ls` the model files and `$SPFDIR/PPG1_INV_X2_7TSL.spf`; `grep -m1 TCAD_GRD_FILE` it. `fs lq .` < 70% (Issue 28).
3. Pre-flight: Issue 27 (24/24 SPF port order) + Issue 29 (extraction vs model). Dry run `ksh run_ppg_sim.sh -d`.
4. `export` all five vars; run `ksh run_ppg_sim.sh` in background (`-v 0.70` for a single point); poll `bjobs | grep PPG_<model>`.
5. Exit 0 required; else read `<results>.missing`, fix (Issues 1/5/19), retry with `CELL_FILTER`.
6. `python3 add_dataset_to_html.py --results ... --id ... --name "..." [--replace]`; then `node verify_dataset_consistency.js` on index.html AND ppg_results.html.
7. GITHUB GATE (ask user), explicit `git add`, token push, curl live site, remind hard refresh (Issue 18). Cleanup binaries (Issue 13).

### Runbook B — full DUT 101-stage chain at any VDD (validated 2026-10-14, v0.43 F03 @ 0.70 V)
1. **Collect inputs:** model (`v0.43`, `v0.53`, `v0.6SB`, `v0.6SB2` auto-resolve inside the script; others need `-i/-l`), layout SPF path (`-s`), cell name (`-c`, must equal the SPF `.SUBCKT` name), VDD (`-v 0.70` | `-v "0.6 0.7 0.8"` | `-v sweep`), temp (`-t`, default 25), stages (`-n`, default 101). Ask the user only for what is missing.
2. **SPF pre-flight (mandatory, this is where chain runs fail):**
   - `grep -n "^\.SUBCKT\|^R_PORT\|^\.ENDS" <spf>` -> must show `.SUBCKT <cell> ENA VSS VDD RO_OUT` and four `R_PORT_* <port> <node> 1u` lines. The base netlist instantiates `XRO1 RO_ENA PSS PDD RO_OUT <cell>`, i.e. port order ENA, VSS, VDD, RO_OUT.
   - A fresh StarRC SPF has NO ports. Derive the 4 nets from the LVS `.LVS_ERRORS` "schematic port nets equated to layout non-port nets" table (VSS!, VDD!, RO_ENA, RO_OUT -> net numbers), pick the most referenced `<net>:<id>` node of each, append the bridges (Issue 33). Never copy node names from an older SPF.
   - `grep -m1 TCAD_GRD_FILE <spf>` must match the model (RPDK0.43 -> `V0p42`), Issue 29.
3. **Dry run:** `ksh full_dut/run_ppg_dut.sh -c <cell> -s <spf> -m <model> -v <vdd> -d`. Check the patched `invfo3_mod.sp`: one `.inc`/`.lib` pair of the intended model (not the Spice-260724 sandbox lines left in the base file's comments), `.inc '<spf>'` points at the intended SPF, `XRO1 ... <cell>`.
4. **Old results:** the run dir `full_dut/run_dut_<model>_<cell>/` is reused and overwritten. If earlier results must be kept, `mv` the dir and results file first (done for `..._F03_prereext`).
5. **Run in background** (LSF, `-R select[...]` is built in): `(ksh full_dut/run_ppg_dut.sh ... -o <results> > run.log 2>&1 &)`; poll `bjobs | grep DUT_<model>`; typical 0.70 V job takes ~1-3 min. Jobs for different VDDs are independent LSF jobs, so a list/sweep already runs in parallel.
6. **Locate outputs correctly:** the vdd tag is the literal string with `.`->`_`: `-v 0.70` -> `0_70`, `-v 0.7` -> `0_7`, sweep -> `0_5 0_55 ... 1_0 ... 1_15`. Always `ls full_dut/run_dut_<model>_<cell>/` before `cd` (a failed `cd` makes later greps silently hit other files).
7. **Validate:** per VDD `grep -c failed invfo3_mod.sp.lis` = 0; `grep -E "^ *(stage_delay|ceff|acreff|iddq_stage)=" invfo3_mod.sp.lis` numeric; monotonic trend over a sweep. Compare with published values (below) and report the % delta.
8. **Publish:** only the datasets/rows requested. Chain rows live in `chain_cells` of the model's dataset (e.g. `v0p43_SLVT_TT`, index.html ~l.948, ppg_results.html ~l.883) with fields `label, stage_delay, ceff, acreff, iddq`; `chain_meta.vdd` is one string (`'0.70 V'`). Edit both files, then `node verify_dataset_consistency.js` on both. NOTE (from reading index.html l.1340, not yet exercised): the site groups chain VDDs across datasets with the same model+vt, so a chain at another VDD or a chain sweep needs its own dataset id/`chain_meta.vdd`, not extra rows in the 0.70 V dataset. Ask the user before restructuring.
9. GITHUB GATE (ask user: model, SPF TCAD header, key numbers, verify results, git status), explicit `git add`, token push, curl live site (Issue 18).
10. Log new problems as numbered Issues in BOTH this file and SKILL.md.

### Published chain data (website `chain_cells`, TT, 25 C, 101 stages)
| Model / cell | VDD | stage_delay ps | ceff fF | acreff kOhm | iddq_stage nA | Source |
|---|---|---|---|---|---|---|
| RPDK0.43 `5T_NAND2_F03` | 0.70 V | 14.20280 | 2.03313 | 6.98569 | 3.19155 | re-extracted SPF `extraction/reext_F03/..._ported.spf`, 2026-10-14 (replaces 14.61083 / 1.96227 / 7.44588 / 3.19102 from the 2026-10-13 `layout/` SPF) |

---



## 1. LM_LICENSE_FILE is empty in the login environment

**Symptom:** All jobs fail immediately with:
```
lic: Cannot find license file.
lic: Unable to checkout (hspice)
**error** DP parseonly failed.
***** hspice job aborted *****
```
The `invfo3_mod_dp.lis` file is ~37 lines (header only, no simulation results).
The `invfo3_mod.sp.lis` file is ~15 lines (also header only).

**Root cause:** `echo $LM_LICENSE_FILE` returns empty string in this login shell.
The per-job `run_hsp.sh` wrapper bakes in `export LM_LICENSE_FILE=$LM_LICENSE_FILE`
at the time the heredoc is written, so the compute node also gets an empty value.

**Fix:** Always hardcode the known-working license string in the `run_hsp.sh` heredoc.
Do NOT rely on `$LM_LICENSE_FILE` being set in the environment.

**Working license string (verified from full_dut/run/7TSL_INVX2/run_hsp.sh):**
```
export LM_LICENSE_FILE=27020@riclic.pok.ibm.com:27020@poklnxlic04.pok.ibm.com:27020@cdsserv1.pok.ibm.com:27020@cdsserv2.pok.ibm.com:27020@cdsserv3.pok.ibm.com
```

**Where this is set in the codebase:**
- `ppg_sim_lib.sh` → `_LM_LICENSE_FILE` constant, used in all `run_hsp.sh` heredocs
- `run_v0p6SB2_slvt_vdd_sweep.sh` — same constant used directly

---

## 2. hspice -dp output: DP is always ignored on this cluster

**Previous (wrong) belief:** `hspice -dp` forks a child that writes results to
`invfo3_mod_dp.lis`; the `invfo3_mod.sp.lis` only has a 15-line header.

**Corrected:** On this cluster `hspice -dp` always emits:
```
**warning** DP feature limitation, DP ignored.
```
and falls back to single-process mode.  `invfo3_mod_dp.lis` is only ~20 lines
(just the header + the warning above).  All `.measure` results (`stage_delay=`,
`ceff=`, etc.) are written to **`invfo3_mod.sp.lis`** — the standard output file.

**Fix:** All result-collection scripts must grep `invfo3_mod.sp.lis`.
The `LIS_FILE()` helper in `ppg_sim_lib.sh` returns `$netlist.lis` (i.e.
`invfo3_mod.sp.lis`), which is correct.

**Note:** `hsp_2022_new` checks `stage_delay=` in `invfo3_mod.sp.lis` — this is
consistent with the above and works correctly.

---

## 3. `local` keyword not available in /bin/ksh

**Symptom:** `ppg_sim_lib.sh` or any sourced script fails with:
```
script.sh[N]: local: not found [No such file or directory]
```

**Root cause:** `/bin/ksh` on this system is POSIX ksh88, not ksh93 or bash.
The `local` keyword is not available.

**Fix:** All functions in `ppg_sim_lib.sh` use prefixed global variables
(`_vm_*`, `_pn_*`, `_ps_*`, `_wj_*`) instead of `local` declarations.

---

## 4. eval + complex quoting breaks in subshells spawned by while read

**Symptom:** `patch_netlist` silently produces an empty or corrupt output file
when called from inside a `while read` loop.

**Root cause:** `eval` re-evaluates quoting, which interacts badly with the
shell's word-splitting in subshells.  Also, paths containing `/` confuse
sed expressions written inline as strings.

**Fix:** `patch_netlist` in `ppg_sim_lib.sh` writes a `sed -f` script to a
`mktemp` file, then runs `sed -f "$_pn_sedscript"`.  No `eval` is used.

---

## 5. SPF terminal order must always be verified and normalised — never assume correct

**This is a mandatory pre-flight check. Never use plain `cp` for SPF files.**

**Symptom:** `stage_delay= failed` for AOI21, OAI21, OAI22 at all voltages.
INV, NAND, NOR, AOI22 pass. Model and netlist paths look correct.

**Root cause:** The netlist instantiates every cell as `XINV1 VSS VDD A Z subckt`
(port order: VSS VDD A Z — as shown in the `invfo3_base.sp` comment).
But SPF `.SUBCKT` port orders differ by cell and are **not guaranteed to match**:

| Cell | SPF `.SUBCKT` order | Netlist order | Match? |
|---|---|---|---|
| AOI22 | `VSS VDD A Z` | `VSS VDD A Z` | ✅ |
| AOI21 | `Z VDD A VSS` | `VSS VDD A Z` | ❌ Z↔VSS swapped |
| OAI21 | `A VDD Z VSS` | `VSS VDD A Z` | ❌ A↔VSS, Z↔A swapped |
| OAI22 | `A VDD Z VSS` | `VSS VDD A Z` | ❌ A↔VSS, Z↔A swapped |

When Z is wired to VSS rail the circuit never oscillates — `tdlyrr1` never
triggers and `stage_delay= failed` with no obvious error.

**Fix:** Always call `process_spf_slvt` for SLVT runs — it reorders terminals
to `VSS VDD A Z` without substituting `slvt→ulvt`. Never use plain `cp`.

```
SLVT runs:  process_spf_slvt "$spf_src" "$dst"   ← reorder only, keep slvt names
ULVT runs:  process_spf       "$spf_src" "$dst"   ← reorder + slvt→ulvt swap
plain cp:   NEVER — skips terminal reorder, breaks AOI/OAI cells silently
```

**Pre-flight check — always run before submitting jobs:**
```sh
grep -i "^\.SUBCKT" <spf_file>
# Compare port order against VSS VDD A Z
# If different, process_spf_slvt (or process_spf) will normalise it
```

**`_SUBCKT_SED` rules in `ppg_sim_lib.sh` (covers all known variants):**
```
SED_1: Z VDD A VSS  → VSS VDD A Z   (AOI21)
SED_2: VDD Z A VSS  → VSS VDD A Z
SED_3: A VDD Z VSS  → VSS VDD A Z   (OAI21, OAI22)
```

If a new cell has a different port order not covered by SED_1/2/3, add a new
`_SUBCKT_SED_4` rule before running.

---

## 6. patch_netlist must block/unblock .inc/.lib pairs — never swap paths inline

**This is the most important rule. Violating it produces mixed-model netlists
that simulate but give wrong results with no obvious error message.**

**Symptom:** `stage_delay= failed` for AOI/OAI cells at all voltages while
INV/NAND/NOR cells produce plausible numbers. The `.inc` path looks correct but
the `.lib` points to a different sandbox.

**Root cause:** `invfo3_base.sp` contains many commented model blocks. A naive
`s|active .inc path|new path|` replaces only the `.inc` inside the currently-active
block, leaving `.lib` pointing to the old sandbox.  Simple cells converge; complex
cells (AOI/OAI) fail `.MEASURE tdlyrr1` with no model-mismatch error.

**Fix — block/unblock the full pair (implemented in `ppg_sim_lib.sh::patch_netlist`):**
1. Comment out ALL active `.inc`/`.lib` model lines (prepend `*`)
2. Uncomment ONLY the `.inc` line matching `MODEL_INC`
3. Uncomment ONLY the `.lib` line matching `MODEL_LIB`

**Corollary:** `MODEL_INC` and `MODEL_LIB` must always be from the **same sandbox
directory**.  Never mix sandbox paths (`260604` inc + `260724` lib = wrong).

**Verification after patch:**
```sh
grep "^\.inc\|^\.lib" <netlist> | grep -v "spf'"
# Must show exactly two lines, both ending in the same Spice-XXXXXX-sandbox/
```

---

## 7. sed backreference quoting in patch_netlist — use address/substitution form

**Symptom:** `patch_netlist` passes `verify_model` but Step 1 (comment-out) is
silently skipped, leaving the previously-active `.inc` line still active alongside
the newly-uncommented target line → `verify_model` fails with "Multiple active
model .inc lines".

**Root cause:** The original Step 1 used a backreference form:
```
printf 's|^\.inc ...\(.*design_include\.inc\)|*.inc \1|g\n'
```
The `\1` backreference was lost during shell quoting expansion inside `printf`,
producing a broken sed rule that matched nothing.

**Fix:** Use the address/substitution form which needs no backreference:
```sh
printf '/^\.inc '"'"'.*design_include\.inc/s/^\./\*./\n' >> "$_pn_sedscript"
printf '/^\.lib .*fixed_corner\.lib/s/^\./\*./\n'        >> "$_pn_sedscript"
```
This matches lines by address, then simply replaces the leading `.` with `*.` —
no backreference needed, no quoting fragility.

**Rule:** In `/bin/ksh` `printf` strings destined for sed scripts, avoid
backreferences (`\1`, `\2`). Use address/command separation instead.


---

## 8. HTML Dataset Synchronization & Cross-Model Delta Distortion

**Symptom:** On Page ③ (*Single Stage vs Chain Comparison*), selecting model `v0.6SB` showed an inflated delta (+17.5% to +20.6% delay, +11.8% to +19.1% ACReff) compared to `v0.6SB2` (~6.4% to ~8.6% delay, ~3.7% ACReff).

**Root cause:** In `index.html`, the single-stage VDD sweep arrays registered under `v0p6SB_SLVT_TT` were retaining `v0.6SB2` simulation data (`7TSL_INV`: 6.339 ps @ 0.7V) instead of the actual `v0.6SB` simulation data (`7TSL_INV`: 6.856 ps @ 0.7V from `PPGRO_chain_menu14_v0p6SB_slvt.txt`). Comparing faster v0.6SB2 single-stage numbers against slower v0.6SB chain numbers created an artificial cross-model delta inflation.

**Mandatory Rules Going Forward:**
1. **Single Model Provenance:** Single-stage data (`rr(id, cell, ...)`), chain data (`chain_cells`), and HTML metadata (`model`, `chain_meta.model`) within any registered dataset must all come from the exact same model version and simulation sandbox.
2. **No Dataset Mixing:** Never copy an existing dataset entry without replacing all 14-point sweep arrays with verified numbers directly extracted from the target model's `PPGRO_chain_menu14_${MODEL_NAME}.txt`.
3. **Model Name Validation:** Validate model names in metadata and verify that `ds.model === ds.chain_meta.model` before generating or updating HTML.
4. **Pre-Publish Cross-Check:** HTML values must be cross-checked against source simulation files before publishing.
5. **Automated Consistency Check:** Run `node verify_dataset_consistency.js <html_file>` prior to any push. The script flags any single-stage vs chain delta outside the physical topology range (+2% to +12%) or any cross-model metadata discrepancy.

## 9. GitHub push — always use the token file, never `git push origin main`

**Symptom:** `git push origin main` fails with "No such device or address" —
interactive HTTPS credentials are not available in this login shell.

**Token file:** `/afs/apd.pok.ibm.com/u/imranyou/.github_token`
**Remote:** `https://github.com/Imran-younus/ppg-results.git`
**Branch:** `main`

**Fix — always use:**
```sh
TOKEN=$(grep "^GITHUB_TOKEN=" /afs/apd.pok.ibm.com/u/imranyou/.github_token | cut -d= -f2)
git push "https://${TOKEN}@github.com/Imran-younus/ppg-results.git" main
```

If rejected with "fetch first" (remote diverged):
```sh
git pull "https://${TOKEN}@github.com/Imran-younus/ppg-results.git" main --rebase
# If conflicts and our results are authoritative:
git rebase --abort
git push --force "https://${TOKEN}@github.com/Imran-younus/ppg-results.git" main
```

**Staging rule:** never `git add .` — explicitly name each file to avoid
committing hundreds of per-cell `run_vdd/` netlists.

---

## 10. Unified Simulation Workflow & Coding Guidelines

### Unified Architecture (`run_ppg_sim.sh`)
All standard cell simulations across any model version are driven by the unified, model-agnostic entrypoint `run_ppg_sim.sh` backed by `ppg_sim_lib.sh`:

1. **Parameters & Overrides:**
   - `MODEL_NAME` (required): short model label (e.g. `v0.6SB`, `v0.6SB2`, `v0.22`)
   - `MODEL_INC` (required): path to `design_include.inc`
   - `MODEL_LIB` (required): path to `fixed_corner.lib` (must match sandbox of `MODEL_INC`)
   - `VDD` (optional): `sweep` (default 14 voltages: 0.5V to 1.15V) or single point (`0.70`) or custom list
   - `TEMP` (optional): simulation temperature in °C (default: `25`)
   - `VT` (optional): `slvt` (default, preserves SLVT device names) or `ulvt` (converts slvt→ulvt)
   - `SPFDIR` (optional): override default SPF directory
   - `OUTPUT` (optional): custom output results path

2. **Execution Flow:**
   - Validates model paths (`validate_model_params`)
   - Generates per-voltage templates and per-cell netlists (`patch_netlist`)
   - Normalises SPF pin order to `VSS VDD A Z` (`process_spf_slvt` / `process_spf`)
   - Emits standalone `run_hsp.sh` wrappers containing verified license strings (`create_hsp_wrapper`)
   - Dispatches parallel LSF jobs and monitors queue (`wait_for_jobs`)
   - Extracts metrics into tab-separated results file (`stage_delay`, `iddq`, `iddarail_qcorr`, `acceffrail_qcorr`, `acreffrail_qcorr`)

3. **Coding Standards for Future Scripts:**
   - **POSIX ksh:** Never use `local` keyword; use prefixed globals (`_vm_*`, `_pn_*`, `_ps_*`, `_cw_*`, `_wj_*`).
   - **Concise Comments:** Add brief, actionable comments explaining interface and non-obvious steps.
   - **Zero Hardcoded Paths in Libs:** Keep model paths in environment variables or caller scripts.
   - **Automated Validation:** Always run `verify_dataset_consistency.js` before staging and pushing.

---

## 11. Post-Refactor Regression Test: 7TSL_INV @ 0.70V, 25C

**Run after every code reorganisation or refactor of `run_ppg_sim.sh` / `ppg_sim_lib.sh`.**

```sh
ksh regression_7TSL_INV.sh
# Expected: 10/10 PASS, exit code 0
```

The script reads existing `.lis` files from `run_vdd_{MODEL}_slvt/0_7/7TSL_INV/invfo3_mod.sp.lis` — no new simulations are submitted. It uses `node` for floating-point comparison with a 0.01% pass threshold.

**Reference values (from `index.html`, VDD index 4 = 0.70V, 25C, SLVT):**

| Metric | v0.6SB | v0.6SB2 |
|---|---|---|
| stage_delay (ps) | 6.85628 | 6.33879 |
| iddq (A) | 1.25955e-08 | 1.26121e-08 |
| iddarail_qcorr (A) | 5.35584e-04 | 5.76559e-04 |
| acceffrail_qcorr (F) | 5.24615e-15 | 5.22122e-15 |
| acreffrail_qcorr (Ω) | 1.30692e+03 | 1.21404e+03 |

**Validated 2025-07:** refactored `run_ppg_sim.sh` → 10/10 PASS, 0.000000% delta on all metrics.

**If FAIL:** check Issues 6 (model patch), 5 (SPF terminal order), 3 (no `local`).

---

## 12. Fresh-Simulation Regression: 7TSL_INV @ 0.70V, 25C

**Run after any refactor.** Submits new LSF jobs — does NOT read existing `.lis` files.

```sh
ksh regression_7TSL_INV_fresh.sh
# Expected: 10/10 PASS, exit code 0  (~2-3 min)
```

**Pipeline exercised:** `patch_netlist → process_spf_slvt → create_hsp_wrapper → bsub → wait → collect → compare`

**Run directory:** `regression_run_7TSL_INV/` (wiped and rebuilt each run)

**Sandbox paths (verified 2025-07):**
- v0.6SB → `Spice-260724-sandbox/` for both `.inc` and `.lib`
- v0.6SB2 → `Spice-260604-sandbox/` for both `.inc` and `.lib`

**Reference values @ 0.70V, 25C, SLVT (from `index.html` VDD index 4):**

| Metric | v0.6SB | v0.6SB2 |
|---|---|---|
| stage_delay (ps) | 6.85628 | 6.33879 |
| iddq (A) | 1.25955e-08 | 1.26121e-08 |
| iddarail_qcorr (A) | 5.35584e-04 | 5.76559e-04 |
| acceffrail_qcorr (F) | 5.24615e-15 | 5.22122e-15 |
| acreffrail_qcorr (Ω) | 1.30692e+03 | 1.21404e+03 |

**Validated (2025-07, LSF jobs 40337941/40337942):** 10/10 PASS, 0.000000% delta.

**If FAIL:** check Issues 6 (model patch), 5 (SPF terminal order), 3 (no `local`); also verify `DEFAULT_SPFDIR` is mounted and `bsub` is available.

---

## 13. Directory Cleanup Rules (Post-Run Maintenance)

### Safe-to-delete after any completed VDD sweep

```sh
# Verify .lis count first (must be 336 for a full 24-cell × 14-VDD run)
find run_vdd_<MODEL>_slvt -name "*.sp.lis" | wc -l

# Then delete HSPICE binary outputs (not needed once .lis is extracted)
find run_vdd_<MODEL>_slvt -name "*.dp0" -o -name "*.ic0" -o -name "*.ic0@0" \
  -o -name "*.tr0" -o -name "*.mt0" -o -name "*.pa0" | xargs rm -f
find run_vdd_<MODEL>_slvt -name "*parseonly*" -delete
```

### Never delete
- `*.sp.lis`, `*_dp.lis` — simulation results, primary data source
- `invfo3_base.sp`, `invfo3_mod.sp` — base and reference netlists
- `PPGRO_chain_menu14_*.txt`, `chain_results_*.txt` — reference results
- `index.html`, `ppg_results.html` — website assets
- `run_ppg_sim.sh`, `ppg_sim_lib.sh`, `hsp_2022_new` — simulation pipeline

### Before deleting any run_vdd_* directory: confirm it's a duplicate
```sh
for cell in 7TSL_INV 6TSL_INV 8TSL_NAND2B; do
  r1=$(grep "stage_delay=" run_vdd_OLD/0_7/${cell}/invfo3_mod.sp.lis 2>/dev/null | awk '{print $NF}')
  r2=$(grep "stage_delay=" run_vdd_CANONICAL/0_7/${cell}/invfo3_mod.sp.lis 2>/dev/null | awk '{print $NF}')
  [ "$r1" = "$r2" ] && echo "MATCH $cell" || echo "DIFFER $cell — do NOT delete"
done
```

### Ephemeral: always safe to delete
- `regression_run_7TSL_INV/` — rebuilt by `regression_7TSL_INV_fresh.sh`
- Root-level `invfo3_mod.mt0`, `invfo3_mod.pa0`, `invfo3_mod.st0`, `PPGchain.spf` — orphan outputs from interactive runs

### Disk impact (2025-07 cleanup): 6.8 GB → 849 MB (~6.1 GB freed)

---

## 14. Debugging Capability Audit After Cleanup

**Confirmed (2025-07):** No deleted file removes a debugging path. All failures are diagnosable from retained files.

### Files retained per cell (full debug capability)

| File | What it provides |
|---|---|
| `invfo3_mod.sp` | Patched netlist — re-runnable, shows active `.inc`/`.lib`, PVDD, TEMP |
| `invfo3_mod.sp.lis` | **Primary debug source** — all `.MEASURE` pass/fail, exact warning messages + line numbers, `power_supply=` |
| `invfo3_mod.st0` | License checkout, tool version, all `init/dcop/tran` phase timings, `tot_iter`, `peak memory` — convergence diagnosis |
| `invfo3_mod_dp.lis` | DP-ignored confirmation (expected artefact — Issue 2) |
| `PPGchain.spf` | Processed SPF — check `.SUBCKT` terminal order for Issue 5 failures |
| `run_hsp.sh` | Exact re-runnable invocation with hardcoded license |

### Deleted types: why they are NOT needed

- `*.dp0` — DP always ignored (Issue 2), file is header-only
- `*.ic0/ic0@0` — Not relevant to any known failure class; regenerable
- `*.tr0` — Waveform binary; **regenerable**: `cd <cell> && ksh run_hsp.sh`
- `*.mt0` — Binary duplicate of `.sp.lis` measurements
- `*.pa0` — PVDD in `.sp` and `.sp.lis`; options in `.st0`

### Known open failure (SPF terminal order bug — Issue 5)

`7TSL_AOI21`, `7TSL_OAI21`, `7TSL_OAI22` in `run_vdd_v0p6SB2_slvt` show `stage_delay=failed`. Diagnosed from retained SPF files:

```sh
grep -i "^\.SUBCKT" run_vdd_v0p6SB2_slvt/0_7/7TSL_AOI21/PPGchain.spf
# VDD Z A VSS ← wrong; process_spf_slvt was not applied to this run
```

Fix on next run: `run_ppg_sim.sh` calls `process_spf_slvt` and will correct this.

### Debug checklist

1. `grep -E "failed|WARNING|ERROR|abort" <cell>/invfo3_mod.sp.lis`
2. `grep "^\.SUBCKT" <cell>/PPGchain.spf` — must end in `VSS VDD A Z`
3. `grep "^\.inc\|^\.lib" <cell>/invfo3_mod.sp | grep -v spf` — same sandbox?
4. `cat <cell>/run_hsp.sh` — `LM_LICENSE_FILE` hardcoded?
5. `grep -E "dcop|tran:|convergence" <cell>/invfo3_mod.st0`
6. Waveforms: `cd <cell> && ksh run_hsp.sh` to regenerate `.tr0`

---

## Issue 17 — No Chain Data: Dataset Registration & Website Rules

**Date:** 2025-07

### Rule: Never register chain_meta/chain_cells without completed chain sims

When adding a new model to `index.html` or `ppg_results.html`, omit `chain_meta` and
`chain_cells` entirely from the `registerDataset()` call if chain simulations have not
been run yet for that model. Only single-stage VDD sweep data should be registered.

**Correct pattern (chain sims pending):**
```js
registerDataset({
  id:    'v0p43_SLVT_TT',
  name:  'v0.43 (SpiceModel_V0.430)',
  model: 'v0.43 (SpiceModel_V0.430)',
  ...
  // chain_meta and chain_cells omitted — chain sims not yet run
});
```

**Wrong pattern (do NOT do this):**
```js
registerDataset({
  ...
  chain_meta: { ... },   // ← WRONG: fabricating chain data
  chain_cells: [ ... ],  // ← WRONG: no real chain results exist
});
```

### Website behaviour when chain_cells is absent

Both `index.html` and `ppg_results.html` automatically:
- Hide chain page options (② Chain, ③ Raw Totals / ③ Chain, ④ Comparison) from the
  page dropdown when the active model has no `chain_cells`
- Redirect to the single-stage sweep page if a chain page is somehow selected
- Never crash on missing `chain_meta` (all `chain_meta.xxx` accesses use `cm.xxx||fallback`)

### When chain sims complete for a model

1. Run chain jobs via `full_dut/PPGRO_DUT_7TINVNANDNOR_menu_sweep_...`
2. Collect with `MODEL_NAME=<model> ksh collect_chain_and_push.sh`
   - The push prompt at the end will offer to commit and push results
3. Add `chain_meta` and `chain_cells` to the existing `registerDataset()` call
4. Run `node verify_dataset_consistency.js index.html ppg_results.html` — must be all ✅
5. Push to GitHub

### GitHub push prompt (collect_chain_and_push.sh)

After successful validation, `collect_chain_and_push.sh` now prompts:
```
Push results to GitHub? [y/N]
```
Answering `y` stages `index.html`, `ppg_results.html`, the result file, and `NOTES.md`,
commits with a dated message, and pushes using the token in `~/.github_token`.
Answering `n` prints the manual push command and exits cleanly.

### Model name display convention

All model `name` fields in `registerDataset()` must include the sandbox identifier:
```js
name: 'v0.6SB2 (Spice-260604-sandbox)'   // ✅ correct
name: 'v0.6SB'                             // ✗ ambiguous — do not use
```
This ensures the model dropdown in the website clearly identifies each model version.

## Issue 18 — GitHub Pages Browser Cache: "I Don't See the Changes"

**Date:** 2025-07
**Symptom:** User reports not seeing new pages/features on the live GitHub Pages site after a confirmed push.

**Root cause:** GitHub Pages sets `Cache-Control: max-age=600`. The browser serves the cached version for up to 10 minutes. The push was correct; the code was live; the browser just hadn't refreshed.

**Verification protocol (always do this first):**
```sh
# Check live HTML content
curl -s "https://imran-younus.github.io/ppg-results/ppg_results.html" | grep 'option value='

# Check last-modified timestamp
curl -sI "https://imran-younus.github.io/ppg-results/ppg_results.html" | grep last-modified
```
If these return the correct content → browser cache issue, NOT a code problem.

**Fix (commit c475525):**
- `<meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">` added to both HTML files
- `<meta http-equiv="Pragma" content="no-cache">` added to both HTML files
- Version stamp added to footer: `v2025-07-<commit> · N models · page-numbers`

**User fix:** Hard refresh (`Ctrl+Shift+R` / `Cmd+Shift+R`) or open in private/incognito window.

**Rule going forward:** Never diagnose a GitHub push failure based on what the user sees in the browser without first running `curl` to verify the live content.

**Version stamp maintenance:** Update footer stamp in every commit that adds features:
- `ppg_results.html`: `v2025-07-<short-hash> · N models · ①②③④`
- `index.html`:       `v2025-07-<short-hash> · N models · ①②③④⑤`

---

## Issue 19 — LSF Jobs Land on Wrong Nodes: "HSPICE is not supported on linux currently"

**Date:** 2025-10 (v0.53 simulation run)

### Symptom
All 336 `.sp.lis` files written almost instantly, every one containing only:
```
Error : HSPICE is not supported on linux currently.
```
No `stage_delay=` results anywhere. `bjobs` shows all jobs DONE before simulations could have run.

### Root cause
`bsub` was invoked **without** the required LSF resource selector. Jobs dispatched to arbitrary nodes — including compute nodes that do not have the HSPICE binary available or licensed.

The correct selector, defined in `ppg_sim_lib.sh::DEFAULT_LSF_SELECT`, is:
```
(osver==rh8) && (type == X86_64) && ! etx && ! nojobs
```

When `bsub` was called manually (outside `run_ppg_sim.sh`) during the v0.53 token-expiry recovery, the `-R` flag was omitted:
```sh
# WRONG — missing -R selector:
bsub -J "PPGv053_${vdd}_${cell}" -M 128 -n 8 -cwd "$celldir" "ksh run_hsp.sh"

# CORRECT — as used by run_ppg_sim.sh:
bsub -J "..." -M 128 -n 8 -W 4:00 \
     -R "select[(osver==rh8) && (type == X86_64) && ! etx && ! nojobs]" \
     -cwd "$celldir" "ksh run_hsp.sh"
```

### Why it was missed
The `.sp.lis` files were created immediately (job "finished"), and the check `find ... -name "*.sp.lis" | wc -l` returned 336 — the expected count. No further content validation was done at that point. The error only became visible when spot-checking the actual file contents.

### Fix
1. Delete all stale `.sp.lis` files:
   ```sh
   find run_vdd_v0.53_slvt -name "*.sp.lis" -delete
   ```
2. Resubmit using `run_ppg_sim.sh` (which always includes the correct `-R` selector), **or** manually with the full correct `bsub` flags:
   ```sh
   LSF_SELECT='(osver==rh8) && (type == X86_64) && ! etx && ! nojobs'
   find run_vdd_v0.53_slvt -name "run_hsp.sh" | while read sh; do
     celldir=$(dirname "$sh")
     cell=$(basename "$celldir")
     vdd=$(basename $(dirname "$celldir"))
     bsub -J "PPGv053_${vdd}_${cell}" -M 128 -n 8 -W 4:00 \
          -R "select[$LSF_SELECT]" \
          -cwd "$celldir" "ksh run_hsp.sh"
   done
   ```

### Prevention rules (mandatory going forward)

1. **Never call `bsub` manually without `-R "select[$DEFAULT_LSF_SELECT]"`.**  
   Always copy the selector string from `ppg_sim_lib.sh::DEFAULT_LSF_SELECT`.

2. **After any job batch completes, always validate `.sp.lis` content** — not just count:
   ```sh
   # Spot-check 3 cells at one VDD point before declaring success
   for cell in 7TSL_INV 7TSL_NAND2B 7TSL_NOR2B; do
     grep "stage_delay=" run_vdd_<MODEL>_slvt/0_7/${cell}/invfo3_mod.sp.lis
   done
   ```
   If any line is empty or contains `Error :`, the run failed.

3. **Prefer `run_ppg_sim.sh` for all submissions** — it embeds the correct `-R` selector, `-W 4:00` wall time, and validated LSF flags. Manual `bsub` loops are only for recovery and must include the full flag set.

4. **When recovering from a failed batch** (e.g. token expiry mid-run), always:
   - Check which `.sp.lis` files contain actual results vs error messages before deleting anything
   - Delete only the bad `.sp.lis` files, keeping any good ones
   - Resubmit only the missing/failed cells, not the whole batch

---

## Issue 20 — HTML Changes Not Pushed: "I Don't See the New Model Data on GitHub"

**Date:** 2025-07  
**Symptom:** User reported v0.53 model data not visible on GitHub Pages site after simulation results were confirmed complete.

**Root cause:** `index.html` and `ppg_results.html` had 141 lines of v0.53 data added each (plus `invfo3_base.sp` model block) in the working tree, but were **never staged or committed**. `git diff --stat HEAD` showed the changes; `git status` showed both files as `modified` (unstaged). GitHub remote had the previous commit.

**Diagnosis:**
```sh
git diff --stat HEAD
# showed: index.html +141 / ppg_results.html +141 / invfo3_base.sp +6

grep -c "v0p53_SLVT_TT" index.html   # → 117  (data IS local)
curl -s "https://imran-younus.github.io/ppg-results/index.html" | grep -c "v0p53_SLVT_TT"  # → 0 (not on server)
```

**Fix applied:**
```sh
node verify_dataset_consistency.js index.html        # all PASS
node verify_dataset_consistency.js ppg_results.html  # all PASS
git add index.html ppg_results.html invfo3_base.sp
git diff --cached --stat                             # 287 lines confirmed
git commit -m "Add v0.53 single-stage dataset to both HTML pages + invfo3_base.sp model block"
TOKEN=$(grep "^GITHUB_TOKEN=" /afs/apd.pok.ibm.com/u/imranyou/.github_token | cut -d= -f2)
git push "https://${TOKEN}@github.com/Imran-younus/ppg-results.git" main
# → 2045719..4d47cd3  main -> main  ✅
```

**Prevention:** After every HTML update, always complete the full trio: `git add` → `git commit` → `git push`. Never stop at "file edited". Run `verify_dataset_consistency.js` before staging. Validate live site with `curl` 60–90 seconds after push.


---

## Issue 21 — Wrong SPF directory: right SPICE model + wrong parasitics

**Symptom:** TPDK0.53 and RPDK0.43 single-stage sweeps gave numbers almost identical to v0.6SB (7TSL_INV @0.70V: 6.170 / 6.146 / 6.856 ps).
**Root cause:** `ppg_sim_lib.sh::DEFAULT_SPFDIR` is `.../SPF_files/tpdk0.6sb` (StarRC TCAD `V0p61_Typical`). `SPFDIR` was never exported for the v0.53 / v0.43 runs, so all 24 `PPGchain.spf` were byte-identical to `tpdk0.6sb` (verified with `cmp` after `process_spf_slvt`). SPICE model changed, parasitics did not.
**Rule:** Device models come from `MODEL_INC`/`MODEL_LIB`; parasitics come ONLY from the SPF. Every new model run MUST export `SPFDIR` and `SPF_TCAD_EXPECT`.
**Fix (2025-10):** `run_ppg_sim.sh` now (a) warns loudly if `SPFDIR` is unset, (b) prints the SPF `TCAD_GRD_FILE`, (c) aborts if `SPF_TCAD_EXPECT` is set and not found in that header.
**Status of published data:** `v0p53_SLVT_TT` and `v0p43_SLVT_TT` in both HTML files were produced with V0.61 parasitics and must be regenerated (use `add_dataset_to_html.py --replace`).

### Authoritative model / SPF table (source: Sbajaj reference sheet, 2HP_Cronus)

| Dataset label | MODEL_INC / MODEL_LIB dir | SPFDIR | `SPF_TCAD_EXPECT` | Notes |
|---|---|---|---|---|
| `TPDK0.53 (Spice-V0.51-prod)` | `/afs/apd/ant/research/prod/2HP/V0.51/Spice/` (`design_include.inc`, `fixed_corner.lib`) | `/gpfs/projects/t/titan/dtco/usr/sbajaj/public/for_Imran/SPF_files/tpdk0.53/2HP_Cronus` | `V0p53` | TPDK0.53 uses TPDK0.51 LVS (`prod/2HP/V0.51/ICV/LVS`) and SPICE; PEX = `prod/2HP/V0.53/StarRC/tcad/` |
| `RPDK0.43 (SpiceModel_V0.430)` | `/afs/apd/ant/cte_tech/1p4/IIMmintaka/common/pdk/IIM/SpiceModel_V0.430/Hspice/` | `/gpfs/projects/t/titan/dtco/usr/sbajaj/public/for_Imran/SPF_files/rpdk0.43/2HP_Cronus` | `V0p42` | RPDK0.43 uses RPDK0.42 PEX (`.../pdk/IIM/StarRC_V0.420/`); LVS = `.../pdk/IIM/ICV_V0.430/LVS/` |
| `v0.6SB (Spice-260724-sandbox)` | `/afs/apd/ant/research/test/2HP/v0.53/Spice-260724-sandbox/` | `/gpfs/projects/t/titan/dtco/usr/sbajaj/SPF_files/tpdk0.6sb` (= `DEFAULT_SPFDIR`) | `V0p61` | |

Both new SPF folders contain all 24 `PPG1_*` cells and are byte-identical to the older `SPF_files/tpdk0.53` and `SPF_files/rpdk0.43/2HP/ppg_v1` copies (checked on 7TSL_INV). RPDK0.43 SPF header TCAD: `.../RPDK0.43/V43/PEX/StarRC/20M_6Mx_10Dx_2Kx_2Gx_LB/tcad/2HP_RPD_StarRC_..._V0p42_0.nxtgrd`. TPDK0.53: `/afs/apd/ant/research/prod/2HP/V0.53/StarRC/tcad/2HP_V0p53_Typical_16M.nxtgrd`.
`invfo3_base.sp` already holds commented `.inc/.lib` blocks for both models (paths use the `/afs/apd/...` prefix; `verify_model` is an exact-substring match, so `MODEL_INC` must use that same prefix).

## Issue 22 — `run_ppg_sim.sh` reported success when every job had failed

**Symptom:** "Simulation flow completed successfully." printed with `-` in every result column.
**Fix (2025-10):** collection now records each non-numeric `stage_delay` in `<results>.missing`; script prints `FAILED: N stage_delay value(s) missing` and exits 1. Never publish when it exits non-zero. Retry only the bad cells: delete their `.sp.lis`, then `CELL_FILTER='7TSL_AOI21 8TSL_NOR2B' ksh run_ppg_sim.sh ...` (same flags, same VDD list). Typical causes: Issue 19 (wrong LSF node), Issue 5 (terminal order -> `stage_delay=failed`), Issue 1 (license).

## Issue 23 — `collect_chain_and_push.sh` is broken for chain runs (OPEN, not fixed)

* Step 3 requires `$MODEL_NAME` to appear inside the `.inc` path; real paths (`Spice-260724-sandbox`, `V0.51/Spice`, ...) never contain `v0.6SB`/`v0.53`, so every run aborts.
* It truncates the result file before validating (explains empty `chain_results_v0.53.txt`).
Do not use it for single-stage work. Single-stage collection is built into `run_ppg_sim.sh`.

## Issue 24 — Updating the website from a results file (single-stage)

`add_dataset_to_html.py` (workspace root) does steps 1-2 below for BOTH HTML files:
```sh
python3 add_dataset_to_html.py --results PPGRO_chain_menu14_<model>_slvt.txt \
    --id v0p53_SLVT_TT --name "TPDK0.53 (Spice-V0.51-prod)" --replace     # drop --replace for a new id
node verify_dataset_consistency.js index.html
node verify_dataset_consistency.js ppg_results.html
```
It refuses incomplete results (`-`/`failed`, !=24 cells x 5 metrics x 14 VDD), refuses names without a `(sandbox/release)` label, never writes `chain_meta`/`chain_cells`, and does not touch git. `--replace` of an unchanged dataset is a byte-for-byte no-op (tested). Results-file rows are: `<cell>`, `<cell>_iddq`, `<cell>_iddarail_qcorr`, `<cell>_acceffrail_qcorr`, `<cell>_acreffrail_qcorr` -> JS metrics `stage_delay, iddq, iddarail, acceff, acreff`.
After a new model is added also bump the footer `site-version` model count (`N models`) and the model dropdown is automatic. Then follow Issue 20 / "GitHub push procedure" (ask the user before pushing).

## Issue 25 — 101-stage chain topology facts (from the 71.6 MB v0.6.SB chain SPF)

* Ring = 1 enable NAND2 (output net 4; `ENA` on one input, ring feedback net 5 on the other) + 100 inverters = 101 stages (odd, as required). `STAGES=101` in `.measure` is correct.
* Each ring gate net drives 12 FETs (FO3). A separate 8-FET output buffer (4N+4P, gates on NAND output net 4) drives `OUT`; ~200 more 8-FET gate nets are dummy/tie-off devices.
* Chain SPF = one whole-ring layout extraction (149k R, 658k C) incl. real inter-stage routing; single-stage SPF (~760 R, 1.7k C) is one cell, stages joined by ideal nodes in `invfo3_base.sp`. This is why chain stage delay is ~2-10% above single-stage.
* Chain SPFs: `/gpfs/projects/t/titan/pdk/models/upl/2hp/cronus_dd1/PPG_RO_A1_Ref_C45_FO3/netlists/<ver>/` (and `PPG_RO_A13_PPG_Suite`). `v0.51` and `v0.6.SB` flat; `v0.53` only has non-Typical corner subdirs. No RPDK0.43 chain SPFs exist -> v0.43 chain is blocked.
* The chain script `full_dut/PPGRO_DUT_7TINVNANDNOR_menu_sweep_v0p6SB2_slvt` hardcodes SCRIPTDIR, cells and SPF paths; the chain base netlist has no v0.6SB / V0.430 model blocks. The chain flow is NOT agent-ready; agent mode is single-stage only.

## Runbook — single-stage sweep for a new model, end to end (agent mode follows this)

0. **Verify extraction params are consistent with the model (Issue 29) and run the Issue 27 pre-flight (24-cell SPF port-order + TCAD check) for every new model/SPF dir - mandatory.**
1. Pick model row from the Issue 21 table (or ask the user for MODEL_INC/MODEL_LIB/SPFDIR/TCAD tag). `ls` both model files and `ls $SPFDIR/PPG1_INV_X2_7TSL.spf`; `grep -m1 TCAD_GRD_FILE` it.
2. `export MODEL_NAME=... MODEL_INC=... MODEL_LIB=... SPFDIR=... SPF_TCAD_EXPECT=...`; run `fs lq .` - must be < ~70% used (Issue 28).
3. Dry run: `ksh run_ppg_sim.sh -d` -> confirm `grep "^\.inc\|^\.lib" run_vdd_<name>_slvt/0_7/7TSL_INV/invfo3_mod.sp` shows one sandbox, and `PPGchain.spf` first `.SUBCKT` ends `VSS VDD A Z`.
4. Regression first: single point `-v 0.70` on all cells (`ksh run_ppg_sim.sh -v 0.70 ...`), check no MISSING.
5. Full sweep: `ksh run_ppg_sim.sh` (336 LSF jobs, `-R select[...]` is in the script; Issue 19). Run in background; poll `bjobs | grep PPG_<name>`.
6. Exit 0 required. On exit 1 read `<results>.missing`, fix cause (Issues 1/5/19), rerun with `CELL_FILTER` for those cells.
7. Result file `PPGRO_chain_menu14_<name>_slvt.txt` -> `add_dataset_to_html.py` (Issue 24) -> both verify scripts must pass.
8. Show the user: 7TSL_INV stage_delay @0.70V, 24-cell count, SPF TCAD header. STOP and ask before `git add/commit/push`.
9. Push per "GitHub push procedure" (explicit `git add` of index.html, ppg_results.html, the results .txt, NOTES.md; token URL; never `origin`). Then `curl` the live site for the dataset id; remind the user to hard-refresh (Issue 18).
10. Log any new problem as a numbered Issue in BOTH SKILL.md and NOTES.md.
11. Cleanup binaries (Issue 13/28) right after `.lis` count = 336 - not optional, AFS quota is ~9.3 GB.


---

## Issue 26 — New SPF sets (tpdk0.53, rpdk0.43) have port orders the old sed rules did not cover

**Symptom (caught in dry-run, before any LSF submit):** `PPGchain.spf` of `7TSL_INV` kept `.SUBCKT PPG1_INV_X2_7TSL Z VSS A VDD`, so the netlist would connect the wrong nodes (same failure class as Issue 5: `stage_delay=failed` or silently wrong numbers).
**Found by:** processing all 24 cells of each new SPF set and checking that the first `.SUBCKT` ends in `VSS VDD A Z`.

| SPF set | Raw orders NOT handled before | Cells |
|---|---|---|
| tpdk0.53 | `Z VSS A VDD` / `A Z VDD VSS` | 7TSL_INV; 7TSL_NAND2B, 7TSL_NOR2B |
| rpdk0.43 | `VDD Z VSS A` / `VDD VSS A Z` | AOI21 x 6T/7T/8T; OAI21 and OAI22 x 6T/7T/8T (6TSL_OAI21/22, 7TSL_OAI21/22, 8TSL_OAI21/22) |
| tpdk0.6sb | none (all 24 already `VSS VDD A Z`) | - |

**Fix (2025-10):** `ppg_sim_lib.sh` gained `_SUBCKT_SED_4..7` (applied in both `process_spf` and `process_spf_slvt`). `run_ppg_sim.sh` now has a port-order guard right after SPF processing: if the first `.SUBCKT` does not end in `VSS VDD A Z`, it prints the offending line and **exits 1 before any job is submitted**. If a future SPF set trips the guard, add one more `_SUBCKT_SED_n` rule AND register it in both process functions; re-verify all 24 cells.
**Verified:** dry-run (`-d -v 0.70`) of both sets: 24/24 `VSS VDD A Z`; TPDK0.53 patched netlist uses `V0.51/Spice`, RPDK0.43 uses `SpiceModel_V0.430/Hspice`; wrong `SPF_TCAD_EXPECT` aborts with exit 1.
**Lesson:** always dry-run a new SPF set and inspect all 24 headers before the first real sweep; ports are matched by NAME, so only the `.SUBCKT` header line needs rewriting.

## Quick env block (copy/paste)

```sh
# TPDK0.53
export MODEL_NAME='v0.53' \
  MODEL_INC='/afs/apd/ant/research/prod/2HP/V0.51/Spice/design_include.inc' \
  MODEL_LIB='/afs/apd/ant/research/prod/2HP/V0.51/Spice/fixed_corner.lib' \
  SPFDIR='/gpfs/projects/t/titan/dtco/usr/sbajaj/public/for_Imran/SPF_files/tpdk0.53/2HP_Cronus' \
  SPF_TCAD_EXPECT='V0p53'
# RPDK0.43
export MODEL_NAME='v0.43' \
  MODEL_INC='/afs/apd/ant/cte_tech/1p4/IIMmintaka/common/pdk/IIM/SpiceModel_V0.430/Hspice/design_include.inc' \
  MODEL_LIB='/afs/apd/ant/cte_tech/1p4/IIMmintaka/common/pdk/IIM/SpiceModel_V0.430/Hspice/fixed_corner.lib' \
  SPFDIR='/gpfs/projects/t/titan/dtco/usr/sbajaj/public/for_Imran/SPF_files/rpdk0.43/2HP_Cronus' \
  SPF_TCAD_EXPECT='V0p42'
ksh run_ppg_sim.sh            # full 14-point sweep; run dir run_vdd_<MODEL_NAME>_slvt
```
Note: `MODEL_NAME` also names the run dir and result file (`run_vdd_v0.53_slvt/`, `PPGRO_chain_menu14_v0.53_slvt.txt`). Existing dirs with those names hold the OLD V0.61-parasitic data - move them to `archive_<name>_oldSPF/` before rerunning (never overwrite silently).
HTML ids: `v0p53_SLVT_TT`, `v0p43_SLVT_TT` (use `--replace`). Labels: `TPDK0.53 (Spice-V0.51-prod)`, `RPDK0.43 (SpiceModel_V0.430)`.

## Custom Bob mode

`.bob/custom_modes.yaml` (workspace scope) defines mode **PPG Sim Agent** (`ppg-sim-agent`): loads this skill first, single-stage only, asks before any git push. Edit that file to change its behaviour; keep it in sync with this runbook.


---

## Issue 27 — MANDATORY pre-flight for every new model / SPF set (port-order + TCAD check)

Run this BEFORE the first real submit for any model or SPF directory not already validated. Do not skip it, even if the SPF folder "looks the same" as a previous one (Issues 5, 21, 26 were all caught this way).

```sh
. ./ppg_sim_lib.sh
echo "$PPG_STD_CELLS_24" | while read l f s; do [ -z "$l" ] && continue
  [ -f "$SPFDIR/$f" ] || { echo "MISSING SPF: $f"; continue; }
  h=$(sed -e "$_SUBCKT_SED_1" -e "$_SUBCKT_SED_2" -e "$_SUBCKT_SED_3" -e "$_SUBCKT_SED_4" \
         -e "$_SUBCKT_SED_5" -e "$_SUBCKT_SED_6" -e "$_SUBCKT_SED_7" "$SPFDIR/$f" | grep -m1 -i '^\.SUBCKT')
  case "$h" in *"VSS VDD A Z") ;; *) echo "BAD PORT ORDER $l: $h";; esac
done                                                      # must print nothing
grep -m1 TCAD_GRD_FILE "$SPFDIR/PPG1_INV_X2_7TSL.spf"      # must match the model's StarRC release
ksh run_ppg_sim.sh -d -v 0.70                              # dry run: guard in script re-checks all 24
```
Checklist (all must be true, record them in the final report to the user):
1. 24/24 SPF files exist in `$SPFDIR`.
2. 24/24 first `.SUBCKT` lines normalise to `VSS VDD A Z`; if any do not, add a `_SUBCKT_SED_n` rule to `ppg_sim_lib.sh`, register it in BOTH `process_spf` and `process_spf_slvt`, re-run this check, and log it as a new Issue in SKILL.md + NOTES.md.
3. TCAD header matches the model (Issue 21 table) and `SPF_TCAD_EXPECT` is exported.
4. Dry-run netlist has exactly one active `.inc` and one `.lib`, both from the intended sandbox.
5. `run_ppg_sim.sh` itself aborts (exit 1) if any processed SPF fails the port-order guard, but the guard only knows the 7 rules above - step 2 still has to be done by a human/agent when it trips.


---

## Issue 28 — AFS home quota exhausted mid-sweep: misleading "unknown SPF port order" abort

**Symptom:** full RPDK0.43 sweep aborted at 0.7 V / `6TSL_OAI21` with `ERROR: unknown SPF port order for 6TSL_OAI21:` (EMPTY `.SUBCKT` line) preceded by `mkdir: cannot create directory ...: Disk quota exceeded`. The single-point regression and dry run had passed, so the port-order guard looked wrong - it was not.
**Root cause:** `fs lq .` showed `usr.imranyou 9766000 used 9766462 100%`. HSPICE binaries (`*.dp0`, `*.ic0`, `*.ic0@0`, `*.mt0`, `*.pa0`: ~6 MB per cell-run, ~2 GB per 336-run sweep) from the finished v0.53 sweep plus two archived old-SPF run dirs (2.0 GB + 2.2 GB) filled the 9.3 GB AFS volume. An empty SPF means the write failed, not that the port order is unknown.
**Fix:** (1) `bkill -J "PPG_v0.43*"` the stragglers; (2) delete binaries from finished/archived runs (Issue 13 command: `find <dir> \( -name "*.dp0" -o -name "*.ic0" -o -name "*.ic0@0" -o -name "*.tr0" -o -name "*.mt0" -o -name "*.pa0" -o -name "*parseonly*" \) -delete`; 336 `.lis` files must exist first); archives shrank 2.0 GB -> 304 MB and usage went 100% -> 39%; (3) remove the partial run dir and rerun the whole sweep.
**Script hardening:** `run_ppg_sim.sh` now checks the processed SPF exists and is non-empty (`3a`) and exits with `could not write ... (disk quota? run: fs lq .)` instead of the misleading port-order message.
**Mandatory pre-sweep check (add to every runbook run):** `fs lq .` must show < ~70% used (a full sweep needs ~2.5 GB). Cleanup binaries immediately after each model's `.lis` count = 336. Do not archive old runs without stripping binaries first.


---

## Issue 29 — MANDATORY: extraction parameters must be consistent with the model, verified every run

Parasitic extraction (StarRC) and the SPICE model are separate inputs; a mismatch is silent (Issue 21: right model + V0.61 parasitics produced plausible but wrong numbers for two published datasets). Before EVERY run, and again in the report to the user, verify all of:

1. **TCAD grid release** in the SPF header (`grep -m1 TCAD_GRD_FILE $SPFDIR/PPG1_INV_X2_7TSL.spf`) is the extraction release the model's PDK specifies (Issue 21 table). Also check the same line in 2-3 other cells (e.g. `PPG1_AOI21_X1_1S0_7TSL.spf`, `PPG1_OAI22_X1_0S11_8TSL.spf`) - all must be the same file.
2. **Corner/variant in the TCAD name** is Typical (`_Typical_`, no `Cworst/Cbest/RC*`) unless the user asked for another corner.
3. **SPF date** (`*|DATE`) and `*|PROGRAM "StarRC"` recorded in the report; SPF set must be a single extraction run (dates within the same day/batch).
4. **Same-release cross-check:** the model's own PDK documentation/table names which PEX it uses (e.g. TPDK0.53 = V0.51 SPICE/LVS + V0.53 StarRC; RPDK0.43 = V0.430 SPICE + RPDK0.42 StarRC). If the pairing is not in the Issue 21 table, ask the user - never infer it from a folder name.
5. **`SPF_TCAD_EXPECT` is exported** to a substring unique to that release (`V0p53`, `V0p42`, `V0p61`); `run_ppg_sim.sh` aborts if the header does not contain it.
6. **Result sanity vs. a different-parasitic baseline:** if 7TSL_INV stage_delay @0.70V is identical (to 5 digits) to another model's published value, the SPFs were probably identical - compare with `cmp` against the other SPF set before publishing.
7. **Net-list side adders** (`cov_tune`, `rdext_tune`, `rsext_tune`, `.temp`) in `invfo3_base.sp` are the same for models being compared, or the difference is stated.

Record all values (TCAD path, date, SPF dir) in the final report and in the dataset's commit message.

**Validated values (2025-10):**
| Model | TCAD header | SPF date | 7TSL_INV @0.70V |
|---|---|---|---|
| TPDK0.53 | `prod/2HP/V0.53/StarRC/tcad/2HP_V0p53_Typical_16M.nxtgrd` | 2026-07-30 | 6.28300 ps (old wrong-SPF run: 6.16968) |
| RPDK0.43 | `PDKs/RPDK0.43/V43/PEX/StarRC/20M_6Mx_10Dx_2Kx_2Gx_LB/tcad/2HP_RPD_StarRC_20M_6Mx_10Dx_2Kx_2Gx_LB_V0p42_0.nxtgrd` | 2026-08-16/17 | 6.35451 ps (old wrong-SPF run: 6.14608) |


---

## Issue 30 — Validating a new model run: benign "failed" measures and the SPF `lle_npbn` effect on iddq

**False alarm to avoid:** `grep -il failed *.lis` matches ALL 336 `.lis` files of every run, including the published v0.6SB and v0.6SB2 runs. The measures `tdlyfr1`, `tdlyrf1` and `tmin` always print `failed` (they use `TD=500n` / `tfall650..trise799` windows that the single-stage netlist never reaches). They are NOT used by `stage_delay` (= `tdlyrr1/2*1e12`) or the five published metrics. A real failure is `stage_delay= failed` or a missing `stage_delay=` line (Issue 22 `.missing` file). Check with: `grep -L "stage_delay=" ...` (must be empty) and `grep "stage_delay= *failed"` (must be empty), not a bare `failed` grep.

**Validation checklist used for RPDK0.43 (2025-10), reuse for any model:**
1. 336/336 `.lis` have a numeric `stage_delay=`; 336/336 netlists have exactly one `.inc` from the intended sandbox and `.temp =25`.
2. For all 24 cells x 14 VDD: stage_delay and acreff strictly decrease with VDD; iddq, iddarail, acceff strictly increase; no non-positive values (RPDK0.43: zero violations).
3. 6TSL > 7TSL > 8TSL delay for every cell type (taller cell = faster), and NAND2 < NAND3, AOI/OAI ordering as in other models.
4. Ratio vs another model (v0.43/v0.53, median): delay 1.07, iddq 0.65, iddarail 0.93, acceff 1.00, acreff 1.08.

**Why RPDK0.43 iddq moved -17% (7TSL_INV @0.70V) and -15% on average when only the SPF changed:** same SPICE model, only the SPF differs between the old (tpdk0.6sb) and new (rpdk0.43) runs. Comparing the device lines of the SPFs: W, L, NF, and `lle_fse/fsw/pcrxn/pcrxs` are identical; the one device-parameter difference is `lle_npbn` / `lle_npbs` = **2.55e-08 in all 24 RPDK0.43 SPFs vs 5.1e-08 in tpdk0.53 and tpdk0.6sb** (RPDK0.43 also adds `M=1`, and hierarchical `XI_...` instance names). These layout-effect parameters feed the model's LLE stress equations, which scale leakage. Delay and ac metrics move less (+3% / +8% avg). The causal link to `lle_npbn` is inferred from this single differing parameter plus the same-model/different-SPF comparison; it was not isolated by a one-parameter simulation.
**Lesson (extends Issue 29):** compare not only the TCAD header but also the per-device parameter set (`lle_*`, `M`, `NF`, `W`, `L`) between SPF sets when explaining leakage differences. A leakage change from "parasitics only" is expected whenever the SPF carries different LLE parameters.


---

## Issue 31 — Netlist extraction reference (LVS/PEX scripts, SPF locations, chain layouts) — READ-ONLY findings, 2025-10

Source of paths: Sbajaj hand-off sheet (items 1 and 2) + inspection of the scripts. Nothing here was executed; extraction has NOT been run from this account yet.

### The two directory paths from the hand-off sheet
| # | Path | Contents |
|---|---|---|
| 1 | `/gpfs/projects/t/titan/dtco/usr/sbajaj/public/ppg_sims/spf_script_jason/` | Original LVS/PEX scripts from Jason + Sbajaj's TPDK/RPDK versions. Files: `runallpnr` (2.5K), `runallpnr.README`, `runlvspnr` (4.9K), `runpexpnr` (2.7K), folder `sb_versions/`. |
| 2 | `/gpfs/projects/t/titan/dtco/usr/sbajaj/public/for_Imran/SPF_files/{rpdk0.43,tpdk0.53}/2HP_Cronus/` | The single-stage extracted SPFs the sweep flow uses (96 `PPG1_*` files each; 24 cells needed). Already wired into the Issue 21 table. |
Other Sbajaj areas seen: `public/PDKs/{RPDK0.43/V43, RPDK0.5SB1}` (LVS deck + StarRC TCAD), `public/ppg_sims/{RC_partition,trial1,...}`, `verif_work/` (run dirs, e.g. `PPG_Macro_ROs`), `SPF_files/{tpdk0.52,tpdk0.53,tpdk0.6sb,tpdk0.6sb2,rpdk0.43,...}` (older copies).

### What each script does
| Script | Role |
|---|---|
| `runallpnr <lib> [-pex\|-lvs]` | Driver. Needs `cds.lib` (defining `<lib>`) in the current dir and a `verif_work/` dir. Loops over `<lib_dir>/*/` cells that have BOTH `schematic` and the chosen layout view (skips `ALL*`, `DRC*`, `*_2CLK`) and `bsub`s one job per cell to queue `titan` (job group limited to 10 running). No flag = LVS + PEX. |
| `runlvspnr [-pex] <lib> <cell>` | `oasisout` streams the layout to OASIS; for LVS it also netlists the schematic to CDL with `si` (auCdl) and runs `icv` LVS; with `-pex` it runs `icv -ex` (extract only) to make the database StarRC needs. Sources `sourceme_LVS` / `sourceme_PEX` from `/gsa/pokgsa/projects/p/pde/cte_tech/{2hp,1p4}/tools/cte/LVST/`. Uses `$TECHDIR`, `$BEOL_STACK`. |
| `runpexpnr <lib> <cell>` | Writes `star_cmd` (EXTRACTION: RC, 25 C, POWER_NETS VDD VSS, TCAD_GRD_FILE, MAPPING_FILE) and runs `StarXtract`; inserts `cell_info.txt` into the SPF `** COMMENTS`; copies `<cell>.spf` to `git_dir` and `rel_dir`. |
| `runallpnr.README` | Start a CTE xterm (no cteCds session needed but the CTE startup sets variables the scripts use, e.g. `CTEUSRHOME`); edit "USER SET VARIABLES" at the top of all three scripts first. |

### Which version produces which SPF set (diff of `sb_versions/` vs top level)
| Script version | LVS deck / ICV | StarRC TCAD | SPFs written to | layout view |
|---|---|---|---|---|
| top level (Jason) | `prod/2HP/V0.52/ICV`, stack 16M_6Mx_6Dx_2Kx_2Gx_LB | `prod/2HP/V0.52/StarRC/tcad/2HP_V0.5_16M_Typical.nxtgrd` | `$PWD/cmos2hp_stdcells/<lib>/SPF` | `layoutPlaced`, lib under `jasonstu/icl` |
| `sb_versions/runallpnr, runlvspnr, runpexpnr` (TPDK) | `prod/2HP/V0.52/ICV` (OPEN QUESTION: hand-off table says TPDK0.53 uses V0.51 LVS) | `prod/2HP/V0.53/StarRC/tcad/2HP_V0p53_Typical_16M.nxtgrd` + `2HP.mapfile` | `SPF_files/test/<lib>` | `layout`, lib under `1p4/IIMmintaka/usr/sbajaj/icl` |
| `sb_versions/*_rpdk` (RPDK) | `PDKs/RPDK0.43/V43` deck `2HP_RPD_ICVLVS_V0p43_0.rs`, stack 20M_6Mx_10Dx_2Kx_2Gx_LB, adds `-stc <cell>`, `*.rs` | `PDKs/RPDK0.43/V43/PEX/StarRC/20M_6Mx_10Dx_2Kx_2Gx_LB/tcad/2HP_RPD_StarRC_..._V0p42_0.nxtgrd` + its `.mapfile` | `SPF_files/rpdk0.43/<lib>` | same |
The RPDK TCAD file matches the header in the `rpdk0.43/2HP_Cronus` SPFs (Issue 29 check passes), which is how the script version is tied to the data.
Hardcoded in `sb_versions`: `lib_dir=.../1p4/IIMmintaka/usr/sbajaj/icl/${lib_name}/work/cds`, `bsub -oo /gpfs/.../sbajaj/verif_work/...`, `RUNDIR`, `git_dir`, `rel_dir`. `runlvspnr` still does `cp $CDLFILE ${CTEUSRHOME}/netlist` (needs CTEUSRHOME set). To use another library or output area, COPY the three `*_rpdk` scripts to our own dir and edit `lib_dir`, the `verif_work` paths and `rel_dir`; never edit Sbajaj's files.

### Chain (101-stage DUT) layouts and SPFs that already exist
`/gpfs/projects/t/titan/pdk/models/upl/2hp/cronus_dd1/{PPG_RO_A1_Ref_C45_FO3, PPG_RO_A13_PPG_Suite}/` hold `A01_Dxx_PPG_DUT.oas` / `A13_Dxx_PPG_DUT.oas` (+ `layoutWork/`) and `netlists/<ver>/`:
- `v0.51`: complete 7T SLVT set (A1_8 INV + A13_7..A13_12 NAND2/NAND3/NOR2 B/T), 35-50 MB each, TCAD `2HP_V0.5_16M_Typical` (V0.51 StarRC). READY for a 0.51 chain.
- `v0.6.SB`: complete, TCAD `V0p61_Typical` (used for published v0.6SB/SB2 chains).
- `v0.53`: only `Cbest/Cworst/RCbest/RCworst` corner dirs + raw `extract/` StarRC outputs; NO Typical SPF.
- No RPDK0.43 / Rapidus 20M chain layout exists there.

### Rapidus library offered for RPDK extraction: `/gpfs/projects/c/c18/mintaka/usr/shirina/icl/test_C18mintaka_PPG_ROs` (inspected 2025-10)
- 80 cell dirs under `work/cds/`; only 22 have BOTH `layout/layout.oa` and `schematic/sch.oa`: `{AOI22,NAND2,NAND3,NOR2,NOR3}_X1_5T_125H_RX15_{F01,F03}_SLVT_{B,T}_M2` and `INV_X2_5T_125H_RX15_{F01,F03}_SLVT_M2`. The other 58 (`*_SL_RX15`, `*_SL_RX18`, ...) lack one view.
- `NAND2_X1_5T_125H_RX15_F01_SLVT_B_M2` has both views (layout.oa 7.8 KB, sch.oa 14 KB, ICV vue/DRC result dirs present). It is a SINGLE CELL, not a ring. The library contains no DUT/RO/chain/ring cell (grep for RO/DUT/RING/CHAIN/ENA found nothing).
- `layout.oa.cdslck` shows an Edit Lock owned by `shirina` (ric011b, 2025-10-08): read/stream-out should work but never save in that lib.
- There is no `cds.lib` inside the library; `runallpnr` needs one in the run dir with `DEFINE test_C18mintaka_PPG_ROs /gpfs/projects/c/c18/mintaka/usr/shirina/icl/test_C18mintaka_PPG_ROs/work/cds`-style entry (verify the exact line format against a working `cds.lib` before use).
- Tools: this login shell has NONE of `oasisout si icv StarXtract virtuoso` on PATH and `CTEUSRHOME` is empty. They exist on AFS (`/afs/apd/func/vlsi/cte/tools/cds/IC/20.1.32/bin/{virtuoso,oasisout,si,strmout}`, `/afs/apd/func/vlsi/cte/tools/synopsys/icv`; a StarXtract at `/afs/apd/ant/cad_tools/synopsys9/W-2024.09-SP2/bin/StarXtract` returned Permission denied). Whether these run from this account/queue `titan` is UNVERIFIED.
- Cell family mismatch to resolve: the single-stage flow simulates `PPG1_*_{6,7,8}TSL` cells (2HP Cronus); this library is 5T/125H `RX15` cells (C18 mintaka). Which RPDK0.43 tech/stack they target is not stated anywhere I could read.

### Verdict / what is needed for chain sims with extracted parasitics
1. 0.51 chain: layouts + Typical V0.51 SPFs EXIST; blockers are only flow bugs (Issue 23, chain base netlist `/afs/apd.pok.ibm.com/ant/...` vs `/afs/apd/ant/...` path prefix and hardcoded cells/SPF paths; port-order check of `A01_D08_PPG_DUT ENA GND VDD OUT`; subdirs `2HP_V0p52V28/V32` unexplained).
2. 0.43 chain: the offered library only allows SINGLE-CELL extraction (equivalent to what `rpdk0.43/2HP_Cronus` already gives). A chain needs a whole-ring layout (enable NAND2 + 100 inverters + output buffer + dummies as ONE cell with ports ENA GND VDD OUT) in an RPDK-stack library plus its schematic; none exists. Ask the layout owner (shirina / Sbajaj) for it, then run the `*_rpdk` scripts on it, check the TCAD header = V0p42 (Issue 29) and all port orders (Issue 27), then adapt the chain flow.
3. 0.53 chain: needs a Typical V0.53 extraction (only corner dirs exist).

---

## Issue 32 — Rapidus C18mintaka Layout OASIS Export & ICV/StarRC PEX Extraction Flow

**Date:** 2026-10
**Cells extracted:**
- `NAND2_X1_5T_125H_RX15_F03_SLVT_B_M2` (FO3 layout variant, from `/gpfs/projects/c/c18/mintaka/usr/shirina/icl/test_C18mintaka_PPG_ROs/work/cds`) -> `layout/NAND2_X1_5T_125H_RX15_F03_SLVT_B_M2.spf` (**11 MB**, 22,929 resistors, 170,268 capacitors).
- `NAND2_X1_5T_125H_RX15_F01_SLVT_B_M2` (FO1 layout variant) -> `layout/NAND2_X1_5T_125H_RX15_F01_SLVT_B_M2.spf` (**5.1 MB**, 14,326 resistors, 90,423 capacitors).

**Working directory:** `/afs/apd.pok.ibm.com/u/imranyou/for_imran/layout/`
**Automated runner:** `layout/run_extract.sh <CELLNAME> [LIBNAME]`

### Flow & Tool Invocations

1. **Cadence OASIS Stream-Out (`oasisout`):**
   - Environment sourced from `/afs/apd/ant/cte_tech/1p8/C18mintaka/usr/imranyou/.cds_env_vars`
   - Generates `.oas` layout stream file with `-enableColoring`.

2. **Synopsys IC Validator (`icv`):**
   - **Tool version requirement:** `/gpfs/projects/t/tools/Synopsys/icvalidator/W-2024.09-SP4-1` (version >= 2023.12 required; older U-2022.12 fails with `#error This PXL runset was generated to run with ICV version 2023.12 and newer`).
   - Sourced `/gsa/pokgsa/projects/p/pde/cte_tech/1p4/tools/cte/LVST/sourceme_PEX`
   - Run mode: `-ex` (device extraction only, creates `run_details/` database for StarRC without requiring schematic CDL).
   - Note on `-ece` flag: Do NOT pass `-ece` to ICV during sub-block extraction, as DRC violations in sub-blocks without seal rings trigger `EXIT_COMPLETE_WERROR` (exit code 30) despite successful device extraction. Check for directory existence of `run_details/` instead.
   - LVS deck: `/gpfs/projects/t/titan/dtco/usr/sbajaj/public/PDKs/RPDK0.43/V43/LVS/2HP_RPD_ICVLVS_V0p43_0.rs`

3. **Synopsys StarRC (`StarXtract`):**
   - **Tool path:** `/gpfs/projects/t/tools/Synopsys/starrc/X-2025.06-SP2-1`
   - TCAD Grid: `/gpfs/projects/t/titan/dtco/usr/sbajaj/public/PDKs/RPDK0.43/V43/PEX/StarRC/20M_6Mx_10Dx_2Kx_2Gx_LB/tcad/2HP_RPD_StarRC_20M_6Mx_10Dx_2Kx_2Gx_LB_V0p42_0.nxtgrd`
   - Mapfile: `.../2HP_RPD_StarRC_20M_6Mx_10Dx_2Kx_2Gx_LB_V0p42_0.mapfile`
   - Command file: generated dynamically per cell with full reduction and power extract options.

4. **Directory Hygiene & Disk Space Management:**
   - Intermediate ICV/StarRC databases (`run_details/`, `star/`, `agds.gds`, `agds.sp`, `*.LAYOUT_ERRORS`, `*.RESULTS`, `*.net`, etc.) take 30+ MB per run and are automatically deleted at the end of `run_extract.sh`, retaining only `.oas`, `.spf`, and execution logs.

### 101-Stage Ring Macro Topology & Simulation Status

1. **Extracted Netlist Attributes (`NAND2_X1_5T_125H_RX15_F03_SLVT_B_M2.spf`):**
   - Contains 1,212 transistors (101 stages $\times$ 12 FETs/stage) + internal wiring RC network.
   - Total extracted size: 11 MB (22,929 resistors, 170,268 capacitors).

2. **SPF Port Interface & Bridging Resolution:**
   - **Root Cause of Initial Failure:** Sub-block extraction without schematic pin CDL cross-reference emitted `.SUBCKT NAND2_X1_5T_125H_RX15_F03_SLVT_B_M2` without port arguments, and internal nets were fractured with colon suffixes (e.g. `2:50388`, `3:5248`, `ENA_IN:56489`, `43:F27634`).
   - **Internal Net Mapping & Port Bridging (Validated in `layout/NAND2_X1_5T_125H_RX15_F03_SLVT_B_M2.spf`):**
     - Ground rail (`VSS`): Net `2` bridged via `R_PORT_VSS VSS 2:50388 1u`
     - Power rail (`VDD`): Net `3` bridged via `R_PORT_VDD VDD 3:5248 1u`
     - Enable input (`ENA`): Net `ENA_IN` bridged via `R_PORT_ENA ENA ENA_IN:56489 1u`
     - Ring output (`RO_OUT`): Net `43` bridged via `R_PORT_OUT RO_OUT 43:F27634 1u`
   - **Full VDD Sweep (0.50 V – 1.15 V, 14 points, SLVT, 25°C):**
     - Successfully simulated via `full_dut/run_ppg_dut.sh -c NAND2_X1_5T_125H_RX15_F03_SLVT_B_M2 -s layout/NAND2_X1_5T_125H_RX15_F03_SLVT_B_M2.spf -m v0.43 -v sweep`.
     - `stage_delay`: 26.46 ps @ 0.50 V → 14.61 ps @ 0.70 V → 9.45 ps @ 1.15 V (monotonic scaling).
     - `stage_freq`: 37.79 GHz @ 0.50 V → 68.44 GHz @ 0.70 V → 105.77 GHz @ 1.15 V.
     - Full results saved to `full_dut/results_dut_v0.43_NAND2_X1_5T_125H_RX15_F03_SLVT_B_M2.txt`.

## Issue 33 — Re-extracted F03 SPF: port-bridge node names are not stable between StarRC runs (found 2026-10-14; fix validated by a 0.70 V chain sim, see update below)

**Symptom:** `extraction/reext_F03/PEX/NAND2_X1_5T_125H_RX15_F03_SLVT_B_M2.spf` (StarRC re-run 12:31) has `.SUBCKT NAME` with NO ports and no `R_PORT_*` bridges. The old Issue 32 bridge nodes (`2:50388`, `3:5248`, `ENA_IN:56489`, `43:F27634`) do not exist in it (0 references; the net is now named `22`, not `ENA_IN`, and the output is net `4`, not `43`). Reusing the old bridge lines would leave the ports floating.
**Evidence:** LVS (`reext_F03/LVS/*.LVS_ERRORS`): 1206/1206 devices and 606 nets matched, 4/4 ports matched, but "4 schematic port nets equated to layout non-port nets": VDD!=3, RO_OUT=4, RO_ENA=22, VSS!=2 and "4 untexted layout ports". The Final result FAIL is therefore only port texting, not a topology mismatch.
**Fix applied (netlist only):** pick the most-referenced node of each LVS-mapped net (`hub()` = most frequent `<net>:<id>` token outside comments) and add `.SUBCKT ... ENA VSS VDD RO_OUT` plus 4 `R_PORT_* 1u` lines before `.ENDS`. Result: `extraction/reext_F03/NAND2_X1_5T_125H_RX15_F03_SLVT_B_M2_ported.spf` (VSS=2:61074 VDD=3:61690 RO_OUT=4:51923 ENA=22:53139). Dry run of `full_dut/run_ppg_dut.sh ... -d` generated and verified all 14 netlists.
**Status:** VALIDATED by the 0.70 V chain sim below. The working chain flow is `full_dut/run_ppg_dut.sh` (Runbook B at the top); Issues 23/25 only concern `collect_chain_and_push.sh` and the old hardcoded chain script. Previous run kept as `full_dut/run_dut_v0.43_F03_prereext/` and `results_dut_v0.43_F03_prereext.txt`.
**Rule:** after every StarRC re-run, re-derive the port nets from the LVS "equated" table; never copy bridge node names from an older SPF. Not a ppg_sim_lib.sh bug.
**Issue 33 update (2026-10-14) - 0.70 V result with the ported re-extracted SPF:** LSF job finished, 0 `failed` measures, v0.43 model pair, ring port order `XRO1 RO_ENA PSS PDD RO_OUT` matches `.SUBCKT ... ENA VSS VDD RO_OUT`. Results file `full_dut/results_dut_v0.43_F03_reext_0p7.txt`. Versus the published `5T_NAND2_F03` (index.html:948, ppg_results.html:883): stage_delay 14.20280 vs 14.61083 ps (-2.79%), ceff 2.03313 vs 1.96227 fF (+3.61%), acreff 6.98569 vs 7.44588 kOhm (-6.18%), iddq_stage 3.19155 vs 3.19102 nA (+0.02%). Re-extracted SPF is 8.77 MB vs 10.76 MB for the published one (different StarRC settings/run), so differences are parasitic-driven. PUBLISHED locally 2026-10-14 (user approved) in index.html and ppg_results.html; both verify scripts pass. Lesson: this was a chain run at ONE voltage (0.70 V), like the other models' chain rows - not a 14-point single-stage sweep; chain requests may ask for any VDD or a sweep. Lesson: run dir tag follows the literal `-v` string (`0.70` -> `0_70`).

**AFS-terminal launch for Runbook B (added 2026-10-14): `run_ppg_sim.sh --chain`** (same entry point as single-stage; delegates to `full_dut/run_ppg_dut.sh`).
```sh
cd /afs/apd.pok.ibm.com/u/imranyou/for_imran
ksh run_ppg_sim.sh --chain --cell NAND2_X1_5T_125H_RX15_F03_SLVT_B_M2 \
    --spf extraction/reext_F03/NAND2_X1_5T_125H_RX15_F03_SLVT_B_M2_ported.spf \
    -m v0.43 -v 0.70 -d          # dry run; drop -d to submit LSF (background it: ( ... > run.log 2>&1 & ); poll bjobs | grep DUT_)
```
Chain mode: `-v` default is 0.70 (not a sweep); accepts one value, a list `"0.6 0.7 0.8"`, or `sweep`; `-t`, `--stages`, `-o`, `-i/-l` as usual. Built-in guards: SPF must exist, first `.SUBCKT` must be `<cell> ENA VSS VDD RO_OUT`, exactly 4 `R_PORT_*` lines (else exit 1 before any job); prints the SPF TCAD header (check it matches the model). WARNING: a dry run or rerun deletes the existing `.lis` in `full_dut/run_dut_<model>_<cell>/<vdd_tag>/` - copy results first. Tested: unported SPF rejected (exit 1), missing `--cell` rejected, ported SPF dry run OK, single-stage `-h` unchanged. Pitfall fixed while adding it: a `$"` inside a ksh double-quoted grep pattern triggers `warning: $ not preceded by \` - close the quote before `$`.

## Issue 34 — `run_ppg_sim.sh --chain` now builds the SPF itself; same F03 cell failed LVS on a fresh re-run (2026-10-14)

**Chain mode without `--spf` (code written + stub-tested, NOT run end to end):**
```sh
ksh run_ppg_sim.sh --chain --cell <layout cell> [--lib test_C18mintaka_PPG_ROs] -m v0.43 [-v 0.70|"list"|sweep] [-d] [--re-extract]
```
`--cell` may also come from env `PPG_CELL`, `--lib` from `PPG_LIB`. Logic: (1) `--spf` given -> use it; (2) else reuse `extraction/ext_<cell>/<cell>_ported.spf`; (3) else read-only check that the cell has BOTH `layout/layout.oa` and `schematic/sch.oa` in the library defined in `extraction/cds.lib` (prints the 5T cells that qualify if not), then run `extraction/run_chain_extract.sh <cell> <lib>` (schematic hierarchy -> schCheck copy -> si/auCdl CDL -> oasisout -> ICV LVS -> StarRC V0p42 -> port bridging from the LVS net table), then `full_dut/run_ppg_dut.sh`. With `-d` and no SPF only the plan is printed, no tool is started. Guards, all exit 1 before any LSF job: missing cell/lib, extraction not producing `PORTED_SPF=`, `.SUBCKT` not `<cell> ENA VSS VDD RO_OUT`, not exactly 4 `R_PORT_*`, TCAD header not matching the model (`SPF_TCAD_EXPECT`, default `V0p42` for v0.43). `run_chain_extract.sh` additionally refuses non-ring cells (top `.SUBCKT` needs RO_ENA and RO_OUT, so INV_X2_* single gates are rejected), requires LVS unmatched instances/nets = 0, and checks the SPF TCAD header. Test hooks `PPG_EXTRACT_SCRIPT` / `PPG_DUT_SCRIPT` swap in stubs.
**Verification done without real tools (14 stub cases):** no --cell, unknown cell, cell lacking a view, unknown lib, plan-only dry run (no calls, no dirs created), extraction path + VDD list passed to the DUT script, failing extraction blocks the DUT script, explicit ported SPF skips extraction, `PPG_CELL` env, unported SPF rejected, wrong TCAD rejected, other model passes through, single-stage `-h` and bad-option handling unchanged. The script's awk port insertion reproduces the validated `reext_F03/..._ported.spf` byte for byte except the comment line, and the LVS-table parser + hub selection give the same nets/nodes (ENA 22:53139, VSS 2:61074, VDD 3:61690, RO_OUT 4:51923).
**Open problem found by the one real test run (should not have been run; user wanted code-only checks):** the full chain (oasisout, CDL, ICV LVS) was run once on `NAND2_X1_5T_125H_RX15_F03_SLVT_B_M2` and the LVS gate stopped it before StarRC: 1206/1206 devices matched but 303 schematic nets and 602 layout nets unmatched, 13 open layout nets, 1 shorted net (RO_OUT). The manual run of 2026-10-13 on the same cell had 0 unmatched nets. Compared and IDENTICAL: CDL (except timestamp), `.icv_cmd`, ICV settings/environment, `layout.oa` (cmp identical, not modified since), text count 21, instance counts 229/60. The OASIS differs only in pcell-generated names. Only candidate difference found: shared pcell library `/gpfs/projects/c/c18/mintaka/usr/shirina/icl/C18mintaka_SA_pcells/work/cds/genFill/layout/layout.oa` was edited 2026-10-14 13:14 (after the 10-13 good run) and `genFill` is used by this layout. This is a SUSPECTED cause, not confirmed. Consequence: a rebuilt extraction of F03 may not be reproducible today; the already-validated `extraction/reext_F03/..._ported.spf` (StarRC 10-14 12:31, built from the 10-13 good LVS outputs) remains the reference and is what was published. Ask the layout owner (shirina) whether `genFill` changed, and rerun the extraction only when the user asks for it.
**Rules:** never start real extraction/simulation when the user asked for code or flow checking; use `-d` and stubs. In ksh do not name a test function `r` (builtin alias for `hist`). When a freshly rebuilt extraction disagrees with an earlier good one, diff the inputs first (CDL, layout.oa, ICV command) and check mtimes of shared pcell libraries before blaming the script.

## Issue 35 — Chain-mode test status, library/tool facts and open items (recorded 2026-10-14, nothing run)

**Status of the new code (all local, NOT committed/pushed; SKILL.md lives outside the repo):** `run_ppg_sim.sh` (`ksh -n` clean, `--chain` mode), `extraction/run_chain_extract.sh` (new, `bash -n` clean), NOTES.md/SKILL.md updates. Pushed earlier (commit `49d5d7c`): F03 chain row (14.20280 ps @ 0.70 V) in `index.html` l.948 and `ppg_results.html` l.883, both verify scripts passed. Intended explicit `git add` set when the user approves (GITHUB GATE applies): `run_ppg_sim.sh NOTES.md extraction/run_chain_extract.sh`.

**NOT yet tested (do these only when the user asks for a real run):**
1. A complete real `run_chain_extract.sh` run. The only real attempt stopped at the LVS gate (Issue 34), so the StarRC step, the V0p42 gate and the port insertion have only been exercised via stubs/awk against the validated SPF.
2. A real LSF submission through `run_ppg_sim.sh --chain` (only `-d`, stubs and `ksh -n` so far; the underlying `full_dut/run_ppg_dut.sh` itself is proven by the 0.70 V F03 run).
3. A chain at a VDD other than 0.70 V or a chain sweep, and how to register it on the site (`chain_meta.vdd` is a single string; probably needs its own dataset id). Ask the user before restructuring.

**Library / tool facts learned:**
- Shared Cadence library `test_C18mintaka_PPG_ROs` (defined in `extraction/cds.lib`). Only 22 cells have BOTH layout and schematic views: the 5T family `{AOI22,NAND2,NAND3,NOR2,NOR3}_X1_5T_125H_RX15_{F01,F03}_SLVT_{B,T}_M2` and `INV_X2_5T_125H_RX15_{F01,F03}_SLVT_M2`. These are single gates, not rings; only `NAND2_X1_5T_125H_RX15_F03_SLVT_B_M2` has the `RO_ENA`/`RO_OUT` ring ports, so `--chain` accepts only that cell today (others are rejected by the ring check, not by a bug).
- `oasisout`, `si`, `icv`, `StarXtract`, `virtuoso` are NOT on the login PATH. `extraction/env_cds.sh` loads the Cadence ones; the scripts source the ICV/StarRC setup themselves.
- A fresh StarRC SPF has no ports and no `R_PORT_*` bridges; node names change per run (Issue 33). Old F03 manual-run reference outputs live in `extraction/reext_F03/` (`LVS/`, `PEX/`, `..._ported.spf`, `lib_PPG_ROs/`).
- ksh: `$"` inside a double-quoted grep pattern warns (close the quote before `$`); do not name a function `r` (alias of `hist`); `run_ppg_sim.sh -c` already means collect-only, so chain options are long-form only (`--chain --cell --spf --lib --stages --re-extract`).
- Dry runs and reruns of `run_ppg_dut.sh` delete the existing `.lis` in `full_dut/run_dut_<model>_<cell>/<vdd_tag>/`: back it up first.

**Open items / next steps:**
- Ask the layout owner (shirina) whether the pcell library `genFill` (`/gpfs/projects/c/c18/mintaka/usr/shirina/icl/C18mintaka_SA_pcells/work/cds/genFill/layout/layout.oa`, edited 2026-10-14 13:14) changed. SUSPECTED cause of the fresh-LVS failure, unconfirmed (Issue 34). Do not re-run F03 extraction until the user asks.
- The validated `extraction/reext_F03/..._ported.spf` is the F03 reference; use it with `--spf` for any F03 chain run.
- Rule reminder: when the user asks only for code/flow checks, use `ksh -n`/`bash -n`, stubs and `-d`; never start extraction, LVS, StarRC, HSPICE or LSF.

---

## Issue 36 — Workspace cleanup: archive/ directory (2026-10-14)

**Action:** Moved 13 stale/superseded items to `archive/` to keep the workspace root clean.

**Files moved to `archive/`:**
- `run_v0p6SB2_slvt_vdd_sweep.log` — 54 MB stale stdout log
- `PPG_delaychain_menu_VDD_sweep_v0p6SB_slvt_new`, `..._ulvt_new`, `PPG_delaychain_menu_sweep_v0p6SB_ulvt_new` — legacy hardcoded sweep scripts, superseded by `ppg_run.sh`
- `slvt_monitor.sh` — hardcoded monitor for deleted `run_vdd_slvt/` directory, broken
- `clean_hsp_files` — old cleanup script, superseded by Issue 13 runbook
- `collect_chain.log` — stale broken-run log
- `archive_v0p6SB_ulvt/`, `scripts/` — old archives with superseded scripts
- `runLvsPex`, `setup.icv`, `star_cmd`, `star_setup` — extraction-only tools, extraction complete

**Rule:** The four `run_vdd_*/` directories (1.4 GB total, 336 `.sp.lis` each) must NEVER be deleted — they are the only copies of all simulation results. All binaries (`*.dp0`, `*.tr0`, etc.) were already deleted in the Issue 13 cleanup.

---

## Issue 37 — `ppg_run.sh` chain mode called wrong script; fixed to use `run_ppg_dut.sh` (2026-10-14)

**Symptom:** `ppg_run.sh` chain mode called `full_dut/PPGRO_DUT_7TINVNANDNOR_menu_sweep_v0p6SB2_slvt` (old hardcoded script) then `collect_chain_and_push.sh` (broken, Issue 23). No interactive prompts for cell name or SPF path. Model paths were always asked interactively even for known models (v0.43/v0.53/v0.6SB/v0.6SB2).

**Fix:**
1. Step 2 (model parameters): added auto-resolve for all 4 known models — no INC/LIB prompts needed.
2. Step 6 (chain mode): replaced hardcoded "7T cells only" skip with interactive prompts for:
   - Cell name (default `NAND2_X1_5T_125H_RX15_F03_SLVT_B_M2`)
   - SPF path (default `extraction/reext_F03/..._ported.spf`), with relative-path resolution and existence check
   - Stages (default `101`)
3. Confirmation summary: shows chain-specific inputs when mode = chain.
4. RUN block: calls `full_dut/run_ppg_dut.sh` with all collected flags (`-c`, `-s`, `-m`, `-i`, `-l`, `-v`, `-t`, `-n`, `-o`). Removed `PPGRO_DUT_*` and `collect_chain_and_push.sh` calls.
5. `run_ppg_sim.sh` moved to `archive/` — `ppg_run.sh` is now the single interactive entry point.

**Rule:** Always use `ksh ppg_run.sh` for interactive runs. Chain mode defaults work for the 5T F03 cell with any of the 4 known models.

---

## Issue 38 — Chain base netlist hostname path mismatch: v0.53/v0.6SB blocks missing from `full_dut/PPG_ROM_base.sp` (2026-10-14)

**Symptom:** `verify_model` error: "No active design_include.inc" when running chain sim with TPDK0.53. Dry run exits 1 immediately after `patch_netlist`.

**Root cause:** `full_dut/PPG_ROM_base.sp` (previously named `PPG_ROM_cronus_base_v0p6SB2.sp`) had the v0.51 prod block at lines 51–52 using `/afs/apd.pok.ibm.com/ant/...` (with hostname). `MODEL_INC` for TPDK0.53 resolves to `/afs/apd/ant/...` (without hostname). `patch_netlist` does an exact substring match — it never found the block to uncomment. Also, the v0.6SB block (`Spice-260724-sandbox`) was entirely absent.

**Comparison:**
- `invfo3_base.sp` (single-stage) had the correct `/afs/apd/ant/...` paths at lines 115–116 → single-stage worked
- `full_dut/PPG_ROM_base.sp` only had `/afs/apd.pok.ibm.com/ant/...` → chain failed

**Fix:** Added two new commented blocks to `full_dut/PPG_ROM_base.sp` before the active v0.6SB2 block:
```
* TPDK0.53 model (v0.53 Titan PDK uses V0.51 LVS/SPICE, prod release Jan 2026)
*.inc '/afs/apd/ant/research/prod/2HP/V0.51/Spice/design_include.inc'
*.lib /afs/apd/ant/research/prod/2HP/V0.51/Spice/fixed_corner.lib TT

* v0.6SB model (Spice-260724-sandbox)
*.inc '/afs/apd/ant/research/test/2HP/v0.53/Spice-260724-sandbox/design_include.inc'
*.lib /afs/apd/ant/research/test/2HP/v0.53/Spice-260724-sandbox/fixed_corner.lib TT
```

**Verified:** Dry run with `-m v0.53` now passes. Patched netlist shows exactly one active `.inc`/`.lib` pair from `prod/2HP/V0.51/Spice/`.

**Rule:** Whenever adding a new model block to either base netlist (`invfo3_base.sp` or `full_dut/PPG_ROM_base.sp`), add it to BOTH files and use the `/afs/apd/ant/...` path format (without hostname). Never use `/afs/apd.pok.ibm.com/ant/...`.

---

## Issue 39 — Script renames for model/cell agnosticism (2026-10-14)

**Problem:** Three script/netlist filenames contained hardcoded model or cell names, making it confusing to use them for other models.

**Renames performed:**

| Old name | New name | References updated |
|---|---|---|
| `run_v0p6SB2_slvt_vdd_sweep.sh` | `run_vdd_sweep.sh` | None (nothing called it by name) |
| `full_dut/run_dut_f03.sh` | `full_dut/run_dut.sh` | Internal `BASESP` path |
| `full_dut/PPG_ROM_cronus_base_v0p6SB2.sp` | `full_dut/PPG_ROM_base.sp` | `run_ppg_dut.sh` (comment + default), `run_dut.sh` |

**Rule:** Script filenames must be model/cell agnostic. Result `.txt` files and run directories may (and should) contain model/cell names for provenance. The `run_hsp.sh` files inside run directories are generated artifacts — their name is fixed as `run_hsp.sh` by `ppg_sim_lib.sh` and must not change.

**Regression:** `ksh -n` syntax check passed on all 3 renamed scripts. Dry run with v0.53 + F03 SPF confirmed `PPG_ROM_base.sp` is found and patched correctly.

---

## Issue 40 — Adding chain data to the website for a new model or cell (procedure, 2026-10-14)

**When:** A new full DUT chain sim completes successfully (exit 0, numeric metrics, 0 `failed`).

**How to add chain data to the website (hand-edit, no script):**

1. Confirm the result file: `cat full_dut/results_dut_<model>_<cell>.txt` — verify numeric values.
2. Confirm 0 `failed`: `grep -c "failed" full_dut/run_dut_<model>_<cell>/<vdd_tag>/invfo3_mod.sp.lis`
3. Open `index.html` and `ppg_results.html`. Find the target dataset by `id` (e.g. `v0p53_SLVT_TT`).
4. Replace the placeholder comment:
   ```javascript
   // chain_meta and chain_cells omitted — chain sims not yet run for this model
   ```
   with:
   ```javascript
   chain_meta: {
     vt:'5T SLVT (C18mintaka)', stages:101, vdd:'0.70 V', corner:'TT', temp:'25 °C',
     simulator:'HSPICE T-2022.06-SP2', model:'<dataset name>',
     scalable_metrics:['stage_delay','ceff','iddq'],
   },
   chain_cells: [
     {label:'<cell_label>', stage_delay:<val>, ceff:<val>, acreff:<val>, iddq:<val>},
   ],
   ```
   Where `<cell_label>` = short name (e.g. `5T_NAND2_F03`), values from the results file.
   `chain_meta.model` MUST match `dataset.model` exactly.
5. Do the same edit in BOTH `index.html` and `ppg_results.html`.
6. Run: `node verify_dataset_consistency.js index.html` and `node verify_dataset_consistency.js ppg_results.html` — both must show `✅ All consistency validations PASSED`.
7. `git add index.html ppg_results.html` (never `git add .`)
8. `git commit -m "Add <model> <cell> chain data (<vdd>V) to <dataset_id>"`
9. Token push (see GitHub push procedure above).
10. `curl` the live site to confirm `<cell_label>` appears.
11. Remind user to hard-refresh (Ctrl+Shift+R, Issue 18).

**Adding a second chain cell to an existing dataset:** append another `{label:..., ...}` row to `chain_cells` in both files. Re-run consistency checks. Re-push.

**Adding chain data for a brand-new model** (no dataset yet): run the single-stage sweep first, register with `add_dataset_to_html.py`, then follow this procedure for chain data.

**Published TPDK0.53 chain data (added 2026-10-14):**
| Model / cell | VDD | stage_delay ps | ceff fF | acreff kOhm | iddq_stage nA |
|---|---|---|---|---|---|
| TPDK0.53 `5T_NAND2_F03` | 0.70 V | 13.80820 | 2.06062 | 6.70100 | 3.66357 |
(SPF: RPDK0.43 `V0p42` parasitics, same layout as RPDK0.43 chain — intentional model-only comparison)

---

## Issue 41 — All result .txt files moved to results/ directory (2026-10-14)

**Change:** Created `results/` directory at workspace root. All simulation result text files moved there.

**Files now in `results/`:**
- `PPGRO_chain_menu14_*.txt` — single-stage VDD sweep results (all 4 models + early legacy files)
- `chain_results_*.txt` — old chain collection results (legacy, from broken `collect_chain_and_push.sh`)
- `results_dut_*.txt` — full DUT chain simulation results

**Scripts updated to write to `results/` by default:**
- `ppg_run.sh` — single-stage: `results/PPGRO_chain_menu14_<MODEL>_<VT>.txt`; chain: `results/results_dut_<MODEL>_<CELL>.txt`
- `full_dut/run_ppg_dut.sh` — default `RESULTS` path changed from `full_dut/results_dut_*` to `results/results_dut_*`; also adds `mkdir -p results/`
- `run_vdd_sweep.sh` — `OUTPUT` default updated to `results/PPGRO_chain_menu14_<MODEL>_<VT>.txt`

**Rule:** All future result files must go to `results/`. Override with `-o <path>` in `run_ppg_dut.sh` or `OUTPUT=<path>` env var if a custom location is needed.

---

## Issue 42 — Simulation output directories moved to rundirs/ (2026-10-14)

**Change:** Created `rundirs/` at workspace root. All simulation run directories moved there.

**Moved:**
- `run_vdd_v0.43_slvt/`, `run_vdd_v0.53_slvt/`, `run_vdd_v0p6SB_slvt/`, `run_vdd_v0p6SB2_slvt/` → `rundirs/`
- `full_dut/run_dut_*/`, `full_dut/run/` → `rundirs/full_dut/`

**Scripts updated:**
- `archive/run_ppg_sim.sh` — `RUNDIR` → `rundirs/run_vdd_<MODEL>_<VT>/`
- `full_dut/run_ppg_dut.sh` — `RUNBASE` → `rundirs/full_dut/run_dut_<MODEL>_<CELL>/`; adds `mkdir -p rundirs/full_dut`
- `ppg_run.sh` — troubleshooting comment paths updated

**Workspace layout going forward:**
```
rundirs/
  run_vdd_<MODEL>_<VT>/         ← single-stage sweep run dirs (one per model/vt)
    <vdd_tag>/<cell>/            ← per-VDD per-cell dirs with invfo3_mod.sp, .lis, run_hsp.sh
  full_dut/
    run_dut_<MODEL>_<CELL>/      ← chain run dirs
      <vdd_tag>/                 ← per-VDD with invfo3_mod.sp, .lis, run_hsp.sh
results/                         ← all result .txt files (Issue 41)
```

**Rule:** Never move or rename an active `rundirs/run_vdd_*/` directory — the `.sp.lis` files inside are the only copies of all simulation results. Regression tests reference `rundirs/run_vdd_v0.6SB_slvt/` and `rundirs/run_vdd_v0p6SB2_slvt/`.

---

## Issue 43 — Git repo cleaned up: website assets only (commit 8b94574, 2026-10-14)

**Problem:** The git repo had thousands of wrongly-tracked files (~1.4 GB): all of `rundirs/` (1,344 `.sp.lis` files), `archive/`, `scripts/`, simulation scripts (`run_ppg_sim.sh`, `ppg_sim_lib.sh`, `ppg_run.sh`, `invfo3_base.sp`, etc.), and stale legacy files.

**Fix:**
1. `git rm --cached -r` to strip all non-website files from the index (44 files)
2. Created `.gitignore` to prevent any re-addition of scripts/netlists/rundirs
3. Committed and pushed as `8b94574`

**What git now tracks (complete list):**
- `.gitignore`, `.nojekyll`, `.bob/custom_modes.yaml`
- `NOTES.md`
- `index.html`, `ppg_results.html`
- `verify_dataset_consistency.js`
- `results/` — 10 result `.txt` files

**`.gitignore` exclusions:** `rundirs/`, `run_vdd_*/`, `full_dut/`, `archive/`, `scripts/`, `extraction/`, `layout/`, `*.sh`, `*.sp`, `*.spf`, `*.py`, `*.lis`, `*.dp0`, `*.tr0`, `*.mt0`, `*.pa0`, `*.st0`, PPGRO_chain_menu14* at root, hsp_2022_new, invfo3_mod.sp, etc.

**Rule:** The GitHub repo is a GitHub Pages dashboard ONLY. Never `git add` simulation scripts, netlists, or run directories. Always stage files explicitly by name. Run `node verify_dataset_consistency.js` on both HTML files before every push.

**Live site verified:** `curl` returned 6 `registerDataset` calls on both `index.html` and `ppg_results.html` after push — all model datasets intact.
