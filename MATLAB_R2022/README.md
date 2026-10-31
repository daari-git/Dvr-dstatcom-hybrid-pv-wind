# MATLAB R2022 version

The models in the main folder are saved in MATLAB R2024b, and an older MATLAB
cannot open them. This folder holds the same models saved in R2022a format,
which R2022a and R2022b can open, together with everything needed to run them.

## Contents

| File | Description |
|---|---|
| `Simulink_model/IEEE13_DVR_DSTATCOM_PV_Wind.slx` | The one model to show: every step run from the Run button |
| `Simulink_model/How_to_run.pdf` | Guide to running it and changing its settings |
| `IEEE13bus_v2019b_Discrete.slx` | Original benchmark feeder (R2019b format) |
| `IEEE13_basecase.slx` | Step 3: faults and rectifier load, no compensation |
| `IEEE13_dstatcom.slx` | Step 4: D-STATCOM |
| `IEEE13_dvr.slx` | Step 5: DVR |
| `IEEE13_dg.slx` | Step 6: PV and wind plants |
| `IEEE13_full.slx` | Step 7: DVR, D-STATCOM, PV and wind together |
| `IEEE13_full_supply.slx` | Step 7: the same with the D-STATCOM on the supply side of the DVR |
| `scripts/` | The same scripts as the main folder |
| `results/` | Saved tables and figures, shown by `show_results` and `compare_models` |

## How to run

Use this folder on its own. Do not mix it with the R2024b models.

1. Open MATLAB R2022a or R2022b.
2. Make this folder the current folder and add the scripts:

   ```matlab
   cd 'path\to\MATLAB_R2022'
   addpath('scripts')
   ```

3. To run in Simulink without any script, open
   `Simulink_model/IEEE13_DVR_DSTATCOM_PV_Wind.slx` and press **Run**. It needs
   no other file. The settings are inside the `Settings` block: a 1/0 block
   for each device (all 0 is the base case of step 3, all 1 the combined case
   of step 7), switch-on times, gains, and sun and wind against time. The fault
   is set in `Fault 680` on the main page. Five scopes open and fill in as it
   runs (under a minute), and the displays inside the `Results` block show the
   lowest and highest voltages, the DVR power and energy, and the power factor,
   THD and unbalance. The note in the model explains each setting. To compare runs, open the Data
   Inspector (Simulation tab). The step models have the same results panel.
   `Simulink_model/How_to_run.pdf` explains every setting.

4. To show the saved results instead, two commands are enough:

   ```matlab
   show_results       % everything from steps 3 to 6: tables and figures
   compare_models     % all model configurations side by side
   ```

   Both show the saved results at once. To simulate live instead, use
   `show_results('run')` (about 10 minutes) or `compare_models('run')` (about
   5 minutes).

5. To run one step on its own (graphs and tables are written to `results/`):

   ```matlab
   run_basecase     % step 3, about 3 minutes
   run_dstatcom     % step 4
   run_dvr          % step 5
   run_dg           % step 6
   run_full         % step 7, several simulations
   ```

Use these commands only. The `build_...` commands recreate a model from the
benchmark feeder, and some of the code they use is still being developed.

## Requirements

- Simulink and Simscape Electrical (Specialized Power Systems).
- `run_full` and `optimise_gains` run their simulations in parallel with the
  Parallel Computing Toolbox, and one after another without it.
- `optimise_gains('pso')` needs the Global Optimization Toolbox;
  `optimise_gains('gwo')` does not.

## What has and has not been checked

The models were exported from R2024b with Simulink's own export function.
`show_results` and `compare_models`, including the live `'run'` mode, were
tested from this folder in R2024b. They have not been run in R2022 itself, because that release is not
installed on the machine that made them. If something fails in R2022, the
exact error message is what is needed to fix it.

## Keeping this folder up to date

Run `export_r2022` from the main folder in R2024b after the models or scripts
change. It rewrites the models and scripts in this folder.
