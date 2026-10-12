#!/usr/bin/env python3
"""
add_dataset_to_html.py - register / refresh a single-stage VDD-sweep dataset
in index.html and ppg_results.html from a PPGRO_chain_menu14_*.txt results file.

Usage:
  python3 add_dataset_to_html.py --results PPGRO_chain_menu14_v0.53_slvt.txt \
      --id v0p53_SLVT_TT --name "TPDK0.53 (Spice-V0.51-prod)" [--replace]

  --replace : dataset id already exists -> only its rr(...) data lines are rewritten
              (the registerDataset block, name and model are left untouched).

Rules enforced (SKILL.md Issues 8, 17, 21):
  * refuses results files containing '-' or 'failed' (incomplete sims)
  * requires exactly 24 cells x 5 metrics x 14 VDD points
  * never writes chain_meta / chain_cells (chain sims are separate)
  * name must contain a sandbox / release label in parentheses
Does NOT git add / commit / push.
"""
import argparse, re, sys

CELLS = [f"{t}TSL_{c}" for t in (6, 7, 8) for c in
         ("INV", "NAND2B", "NOR2B", "NAND3B", "AOI21", "AOI22", "OAI21", "OAI22")]
METRICS = [("", "stage_delay"), ("_iddq", "iddq"), ("_iddarail_qcorr", "iddarail"),
           ("_acceffrail_qcorr", "acceff"), ("_acreffrail_qcorr", "acreff")]
VDDS = "[0.5,0.55,0.6,0.65,0.7,0.75,0.8,0.85,0.9,0.95,1.0,1.05,1.1,1.15]"
ANCHOR = "// ACTIVE DATASET STATE"


def load_results(path):
    rows = {}
    for line in open(path):
        f = line.rstrip("\n").split("\t")
        if len(f) < 2:
            continue
        rows[f[0]] = f[1:]
    out = []
    for cell in CELLS:
        for suffix, metric in METRICS:
            key = cell + suffix
            if key not in rows:
                sys.exit(f"ERROR: row missing in results file: {key}")
            vals = rows[key]
            if len(vals) != 14:
                sys.exit(f"ERROR: {key} has {len(vals)} values, expected 14")
            for v in vals:
                try:
                    float(v)
                except ValueError:
                    sys.exit(f"ERROR: non-numeric value '{v}' in {key} - sims incomplete, do not publish")
            out.append(f"rr('{{ID}}','{cell}','{metric}',[{','.join(vals)}]);")
    return out


def register_block(ds_id, name):
    cells = ",".join(f"'{c}'" for c in CELLS)
    c6, c7, c8 = (",".join(f"'{c}'" for c in CELLS[i:i + 8]) for i in (0, 8, 16))
    return f"""// -- Register dataset: {name} --
registerDataset({{
  id:        '{ds_id}',
  name:      '{name}',
  model:     '{name}',
  vt:        'SLVT',
  corner:    'TT',
  temp:      '25 \u00b0C',
  simulator: 'HSPICE T-2022.06-SP2',
  vdd_range: '0.5 V \u2013 1.15 V',
  tsl_order: ['6TSL','7TSL','8TSL'],
  baseline_tsl: '6TSL',
  vdd: {VDDS},
  cells: [{c6},
          {c7},
          {c8}],
  // chain_meta and chain_cells omitted - chain sims not yet run for this model
}});

"""


def patch(path, ds_id, name, rr_lines, replace):
    html = open(path, encoding="utf-8").read()
    lines = [l.replace("{ID}", ds_id) for l in rr_lines]
    exists = f"id:        '{ds_id}'" in html
    if exists and not replace:
        sys.exit(f"ERROR: {ds_id} already in {path}; use --replace to refresh its data")
    if not exists and replace:
        sys.exit(f"ERROR: {ds_id} not in {path}; drop --replace to add it")
    if exists:
        pat = re.compile(r"^rr\('" + re.escape(ds_id) + r"'.*\n", re.M)
        m = pat.search(html)
        html = pat.sub("", html)
        html = html[:m.start()] + "\n".join(lines) + "\n" + html[m.start():]
    else:
        a = html.find(ANCHOR)
        if a < 0:
            sys.exit(f"ERROR: anchor '{ANCHOR}' not found in {path}")
        a = html.rfind("\n", 0, html.rfind("\n", 0, a)) + 1  # start of the line before anchor comment
        html = html[:a] + register_block(ds_id, name) + "\n".join(lines) + "\n\n\n" + html[a:]
    open(path, "w", encoding="utf-8").write(html)
    print(f"{path}: {'refreshed' if exists else 'added'} {ds_id} ({len(lines)} rr lines)")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--results", required=True)
    ap.add_argument("--id", required=True)
    ap.add_argument("--name", required=True)
    ap.add_argument("--replace", action="store_true")
    ap.add_argument("--files", nargs="+", default=["index.html", "ppg_results.html"])
    a = ap.parse_args()
    if not re.search(r"\(.+\)", a.name):
        sys.exit("ERROR: --name must include a sandbox/release label in parentheses (Issue 8)")
    rr = load_results(a.results)
    for f in a.files:
        patch(f, a.id, a.name, rr, a.replace)
    print("Next: node verify_dataset_consistency.js index.html && node verify_dataset_consistency.js ppg_results.html")


if __name__ == "__main__":
    main()
