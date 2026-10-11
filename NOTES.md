# PPG Simulation Flow — Known Issues & Fixes

This file exists so that bugs already diagnosed and fixed are not re-investigated
from scratch in new sessions.  Update this whenever a new root cause is found.

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
