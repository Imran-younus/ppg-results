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

## 8. HTML dashboard dataset synchronization — avoid cross-model single vs chain delta distortion

**Symptom:** On the HTML comparison page (Page ③ Single Stage vs Chain Comparison), selecting model `v0.6SB` showed an inflated delta (+17.5% to +20.6% delay, +11.8% to +19.1% ACReff) compared to `v0.6SB2` (~8.6% delay, ~3.7% ACReff).

**Root cause:** In `index.html`, the single-stage VDD sweep arrays registered under `v0p6SB_SLVT_TT` were inadvertently populated with `v0.6SB2` simulation data (`7TSL_INV`: 6.339 ps @ 0.7V) instead of the actual `v0.6SB` simulation data (`7TSL_INV`: 6.856 ps @ 0.7V from `PPGRO_chain_menu14_v0p6SB_slvt.txt`). Comparing the faster `v0.6SB2` single-stage numbers against slower `v0.6SB` chain numbers created an artificial cross-model delta mismatch.

**Fix:**
1. Populated `index.html` with the verified `v0.6SB` single-stage sweep simulation arrays (matching `ppg_results.html` and `PPGRO_chain_menu14_v0p6SB_slvt.txt`).
2. Updated dynamic comparison legend notes and takeaways to compute exact live deltas (~6.6% delay, ~2.7% Ceff, ~3.8% ACReff) across both models.
3. Kept `index.html` and `ppg_results.html` 100% synchronized.

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
