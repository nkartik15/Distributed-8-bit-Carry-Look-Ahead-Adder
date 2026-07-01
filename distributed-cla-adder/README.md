# Distributed Carry-Lookahead Adder (8-bit)

An 8-bit adder built from a **distributed Carry-Lookahead Adder (CLA)** architecture:
8 bit-level `gp_cell` generate/propagate blocks feed a `carry_lookahead_network` that
computes all internal carries in parallel, avoiding a ripple-carry delay chain.

- **RTL**: `cla.v` (`gp_cell`, `carry_lookahead_network`, `distributed_cla_adder`)
- **Testbench**: `cla_tb.v` — directed 10-case testbench (`tb_distributed_cla_adder`)
- **Simulator**: Cadence Xcelium/NCsim (`ncvlog` → `ncelab` → `ncsim`), viewed in SimVision
- **Synthesis**: Cadence Genus 21.14, `tsmc18` technology library, `slow` corner

## Repository layout

```
.
├── cla.v                   # RTL (not included by design — see note below)
├── cla_tb.v                # Testbench (not included by design — see note below)
├── docs/
│   ├── schematics/          # Genus-generated gate-level schematics
│   └── screenshots/         # Tool-flow screenshots (sim run, waveform, synth reports)
├── sim/                     # NCsim/Xcelium compile-elaborate-simulate logs
│   ├── ncvlog.log
│   ├── ncelab.log
│   └── ncsim.log
├── synth/                   # Genus synthesis script + full log
│   ├── genus.cmd
│   └── genus.log
├── formal_verification/     # RTL-vs-gate logical equivalence check (LEC) flow
│   ├── rtl_to_fv_map.do      # top-level LEC dofile (golden RTL vs revised netlist)
│   ├── fv_map_map.do         # port mapping between RTL and gate netlist
│   └── read_libs.tcl         # liberty library setup for LEC
└── reports/
    └── synthesis_summary.md # Extracted area/power/timing highlights
```

> **Note:** `cla.v` and `cla_tb.v` are the design source files — add them to the repo
> root yourself (see instructions below). Everything else in this repo was generated
> by the tool flow and is organized here for reference/reproducibility.

## Results summary

- **Functional verification**: 10/10 directed testcases pass in NCsim (`sim/ncsim.log`)
- **Synthesis**: 32 cells, 665.28 µm² total area, `tsmc18` slow corner
  (`synth/genus.log`, `reports/synthesis_summary.md`)
- **Timing**: worst unconstrained path `b[0] → sum[7]`, 2230 ps data path delay
- **Power**: ~25.5 µW total (68% internal, 32% switching) — vectorless estimate

## Formal verification (RTL vs. gate-level LEC)

Genus's built-in equivalence-checking flow confirms the synthesized netlist is
logically identical to `cla.v`:

```bash
lec -xl -nogui -Dofile formal_verification/rtl_to_fv_map.do
```

Regenerated binary snapshots of the netlist (`*_v.gz`) and the tool's internal
state dump (`*_fv.json`) are intentionally excluded from version control
(see `.gitignore`) — they're recreated automatically on every synthesis run
and aren't reviewable source content, unlike the `.do`/`.tcl` flow scripts.

## Reproducing the flow

```bash
# Simulation (Cadence Xcelium)
ncvlog cla.v
ncelab tb_distributed_cla_adder -mess
ncsim tb_distributed_cla_adder -mess -run

# Synthesis (Cadence Genus)
genus -f synth/genus.cmd
```

## License

Add a license of your choice (e.g. MIT) before making the repo public.
