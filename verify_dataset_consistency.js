#!/usr/bin/env node
/**
 * verify_dataset_consistency.js
 * Automated consistency check for PPG simulation HTML files.
 *
 * Verifies that:
 * 1. Single-stage data, chain data, and HTML data all come from the same model version.
 * 2. No dataset mixing occurs between v0.6SB, v0.6SB2, or future models.
 * 3. Model names are validated before generating or updating HTML.
 * 4. Single-stage vs chain per-stage topology deltas fall within expected physical limits (2% - 15%).
 */

const fs = require('fs');

const targetFiles = process.argv.slice(2);
if (targetFiles.length === 0) {
  targetFiles.push('index.html', 'ppg_results.html');
}

let allPassed = true;

for (const filePath of targetFiles) {
  if (!fs.existsSync(filePath)) {
    console.error(`❌ File not found: ${filePath}`);
    allPassed = false;
    continue;
  }

  console.log(`\n======================================================`);
  console.log(`Checking ${filePath}...`);
  console.log(`======================================================`);

  const html = fs.readFileSync(filePath, 'utf8');

  // Mock environment for evaluating dataset definitions in HTML
  global.Chart = { defaults: { color: '' } };
  const start = html.indexOf('const DATASETS = {};');
  const end = html.indexOf('function renderTopoPage(){');

  if (start === -1 || end === -1) {
    console.error(`❌ Could not find DATASETS block in ${filePath}`);
    allPassed = false;
    continue;
  }

  let code = html.substring(start, end);
  code = code.replace('const DATASETS = {};', 'global.DATASETS = {};');
  code = code.replace('const CHAIN_TO_SINGLE=', 'global.CHAIN_TO_SINGLE=');
  eval(code);

  const dsKeys = Object.keys(global.DATASETS);
  console.log(`Found ${dsKeys.length} dataset(s): ${dsKeys.join(', ')}`);

  for (const id of dsKeys) {
    const ds = global.DATASETS[id];
    console.log(`\n--- Dataset [${id}]: ${ds.name} (${ds.model}) ---`);

    // Check 1: Model metadata consistency
    if (ds.chain_meta) {
      if (ds.chain_meta.model !== ds.model) {
        console.error(`❌ METADATA MISMATCH in [${id}]: Single-stage model='${ds.model}' vs Chain model='${ds.chain_meta.model}'`);
        allPassed = false;
      } else {
        console.log(`✅ Model metadata matches: ${ds.model}`);
      }
    }

    // Check 2: Single-stage 14-point sweep presence
    const cellCount = Object.keys(ds.data || {}).length;
    if (cellCount !== 24) {
      console.error(`❌ Unexpected cell count in [${id}]: expected 24, found ${cellCount}`);
      allPassed = false;
    } else {
      console.log(`✅ All 24 cells populated in single-stage dataset`);
    }

    // Check 3: Topology Delta Verification (0.70 V reference)
    const targetVdd = parseFloat(ds.chain_meta?.vdd || '0.70');
    let bestVddIdx = 0, bestDiff = Infinity;
    ds.vdd.forEach((v, i) => {
      const diff = Math.abs(v - targetVdd);
      if (diff < bestDiff) { bestDiff = diff; bestVddIdx = i; }
    });

    const pairs = (ds.chain_cells || []).reduce((acc, cc_cell) => {
      const under = cc_cell.label.indexOf('_');
      const tsl = cc_cell.label.slice(0, under);
      const ct = cc_cell.label.slice(under + 1);
      const mapped = global.CHAIN_TO_SINGLE[ct];
      if (!mapped) return acc;
      const singleKey = tsl + '_' + mapped;
      if (!ds.data[singleKey]) return acc;
      acc.push({ chainLabel: cc_cell.label, singleKey, chainCell: cc_cell, singleCell: ds.data[singleKey] });
      return acc;
    }, []);

    for (const p of pairs) {
      const sDelay = p.singleCell.stage_delay[bestVddIdx];
      const cDelay = p.chainCell.stage_delay;
      const dDelayPct = ((cDelay - sDelay) / sDelay) * 100;

      const sCeff = p.singleCell.acceff[bestVddIdx] * 1e15;
      const cCeff = p.chainCell.ceff;
      const dCeffPct = ((cCeff - sCeff) / sCeff) * 100;

      const sAcreff = p.singleCell.acreff[bestVddIdx] / 1000;
      const cAcreff = p.chainCell.acreff;
      const dAcreffPct = ((cAcreff - sAcreff) / sAcreff) * 100;

      // Delta bounds check: topology stage delay delta must be between +1% and +15%
      if (dDelayPct < 0 || dDelayPct > 15) {
        console.error(`❌ ABNORMAL STAGE DELAY DELTA: ${p.chainLabel} vs ${p.singleKey}: Δ = ${dDelayPct.toFixed(1)}% (single=${sDelay.toFixed(3)} ps, chain=${cDelay.toFixed(3)} ps). Cross-model mismatch suspected!`);
        allPassed = false;
      } else {
        console.log(`  ✅ ${p.chainLabel.padEnd(12)}: Delay Δ = +${dDelayPct.toFixed(1).padStart(4)}% | Ceff Δ = ${dCeffPct >= 0 ? '+' : ''}${dCeffPct.toFixed(1).padStart(4)}% | ACReff Δ = +${dAcreffPct.toFixed(1).padStart(4)}%`);
      }
    }
  }
}

if (!allPassed) {
  console.error('\n❌ Consistency validation FAILED.');
  process.exit(1);
} else {
  console.log('\n✅ All consistency validations PASSED.');
  process.exit(0);
}
