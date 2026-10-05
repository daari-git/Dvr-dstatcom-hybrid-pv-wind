# MATLAB R2022 version

The models in the main folder are saved in MATLAB R2024b, and an older MATLAB
cannot open them. This folder holds the same models saved in R2022a format,
which R2022a and R2022b can open, together with everything needed to run them.

## Contents

| File | Description |
|---|---|
| `IEEE13bus_v2019b_Discrete.slx` | Original benchmark feeder (R2019b format) |
| `IEEE13_basecase.slx` | Step 3: faults and rectifier load, no compensation |
| `IEEE13_dstatcom.slx` | Step 4: D-STATCOM |
| `IEEE13_dvr.slx` | Step 5: DVR |
| `IEEE13_dg.slx` | Step 6: PV and wind plants |
| `IEEE13_full.slx` | Step 7: DVR, D-STATCOM, PV and wind together |
| `scripts/` | The same scripts as the main folder |
| `results/optim_*_best.csv` | Optimised gains, read by `run_full` |

## How to run

Use this folder on its own. Do not mix it with the R2024b models.

1. Open MATLAB R2022a or R2022b.
2. Make this folder the current folder and add the scripts:

   ```matlab
   cd 'path\to\MATLAB_R2022'
   addpath('scripts')
   ```

3. Run any step. Graphs and tables are written to `results/` in this folder.

   ```matlab
   run_basecase     % step 3, about 3 minutes
   run_dstatcom     % step 4
   run_dvr          % step 5
   run_dg           % step 6
   run_full         % step 7, 12 simulations
   ```

The `run_...` commands are all that is needed. The `build_...` commands
recreate a model from the benchmark feeder; use them only to change a model.

## Requirements

- Simulink and Simscape Electrical (Specialized Power Systems).
- `run_full` and `optimise_gains` run their simulations in parallel with the
  Parallel Computing Toolbox, and one after another without it.
- `optimise_gains('pso')` needs the Global Optimization Toolbox;
  `optimise_gains('gwo')` does not.

## What has and has not been checked

The models were exported from R2024b with Simulink's own export function, and
the exported files give exactly the same results as the originals when run in
R2024b. They have not been run in R2022 itself, because that release is not
installed on the machine that made them. If something fails in R2022, the
exact error message is what is needed to fix it.

## Keeping this folder up to date

Run `export_r2022` from the main folder in R2024b after the models or scripts
change. It rewrites the models and scripts in this folder.
