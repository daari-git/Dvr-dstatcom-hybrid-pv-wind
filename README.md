# DVR and D-STATCOM with Hybrid PV-Wind Distributed Generation

Coordinated control of a Dynamic Voltage Restorer (DVR) and a Distribution
Static Compensator (D-STATCOM) for power quality improvement in a distribution
feeder with both solar PV and wind generation, using optimisation and machine
learning. Modelled in MATLAB/Simulink on the IEEE 13-bus test feeder.

## Research gap

Ten papers have been reviewed. Two of them (Goud and Rao, 2021; Yadav et al.,
2024) already combine a series and a shunt compensator with PV, wind and a
battery, as a unified power quality conditioner (UPQC) whose controller gains
are tuned by a metaheuristic. Combining both compensator types with both
sources is therefore not new in itself. What those and the other papers leave
open:

- **Test system.** The UPQC studies use a single source feeding one load. None
  uses a standard unbalanced feeder with the devices and the plants at
  different nodes.
- **Disturbances.** They test balanced sags, swells and harmonics. None tests
  unsymmetrical faults, which give a sag and a swell at once.
- **Generation during the fault.** None reports whether the PV and wind plants
  ride through the fault or how they change what the series device must
  supply.
- **Separate devices.** A UPQC shares one DC link. A DVR and a D-STATCOM as
  separate devices, as compared by Kamarposhti et al. (2023) with wind only,
  have not been studied with PV and wind together.
- **Control.** Optimisation is used to tune the gains of one controller.
  Learning-based control has been applied to one device with one source
  (Ahmed and Bayoumi, 2026; Benatallah et al., 2026), not to deciding how two
  devices share the compensation.

This work addresses a separate DVR and D-STATCOM on the IEEE 13-bus feeder
with PV and wind plants, under unsymmetrical faults, with metaheuristic tuning
as the baseline and an ML layer deciding how the devices share the
compensation.

## Workflow

```mermaid
flowchart TD
    A[1. Literature review and research gap] --> B[2. Benchmark feeder<br/>IEEE 13-bus validated against published voltages]
    B --> C[3. Base case<br/>faults, sags, swells, non-linear load, no compensation]
    C --> D[4. D-STATCOM alone<br/>PI control]
    C --> E[5. DVR alone<br/>PI control]
    D --> F[6. Add PV and wind plants<br/>real irradiance and wind profiles]
    E --> F
    F --> G[7. Offline optimisation<br/>placement, sizing, PI gains]
    G --> H[8. Dataset generation<br/>scripted simulation runs]
    H --> I[9. ML coordinator<br/>classify disturbance, predict duration, share compensation]
    I --> J[10. Comparison<br/>fixed PI vs optimised PI vs optimised PI + ML]
    J --> K[11. Results and thesis writing]
```

| Step | Task | Output | Status |
|---|---|---|---|
| 1 | Literature review and research gap | Gap statement, reference list | In progress (10 papers, more to come) |
| 2 | Validate IEEE 13-bus benchmark model | Node voltages within 0.01 pu of benchmark | Done |
| 3 | Base case with faults and non-linear load | Uncompensated sag, THD and unbalance at the sensitive load bus | Done |
| 4 | D-STATCOM alone with PI control | Voltage regulation, THD, reactive power | Done |
| 5 | DVR alone with PI control | Restored load voltage, injected voltage and energy | Done |
| 6 | Add PV and wind plants | Feeder with hybrid DG under varying irradiance and wind | Done |
| 7 | Combined model and offline optimisation | Device location, rating and PI gains | In progress: combined model built; PSO and grey wolf results below; a five-method comparison (PSO, grey wolf, bat, whale, differential evolution, three seeds each) and the placement and rating study are running |
| 8 | Dataset generation | Labelled disturbance cases from scripted runs | To do |
| 9 | ML coordinator | Trained model, accuracy and inference time | To do |
| 10 | Comparison of the three control cases | Tables and waveforms for all scenarios | To do |
| 11 | Writing | Thesis and paper | To do |

### Test scenarios

- Balanced and unbalanced voltage sags and swells
- Single-phase and three-phase faults
- Non-linear load (harmonics)
- Step and real-profile changes in irradiance and wind speed

### Performance metrics

- Load voltage restoration and response time
- Total harmonic distortion (IEEE 519)
- Voltage unbalance
- Injected kVA and storage energy
- Low-voltage ride-through compliance (IEEE 1547-2018)
- ML accuracy and inference time (target: within a quarter to half cycle)

## Base-case results (no compensation)

Fault at node 680 from 0.8 s to 1.0 s (fault resistance 0.01 ohm). Voltages are
fundamental RMS at node 634, the 480 V load behind the transformer, measured
during the disturbance.

| Scenario | Va (pu) | Vb (pu) | Vc (pu) | Unbalance (%) | Voltage THD (%) |
|---|---|---|---|---|---|
| Normal operation | 0.995 | 1.020 | 0.996 | 0.6 | 0.0 |
| Three-phase-to-ground fault | 0.607 | 0.634 | 0.620 | 2.9 | 0.0 |
| Single line-to-ground fault (A) | 0.613 | 1.104 | 1.097 | 8.9 | 0.0 |
| Line-to-line fault (B-C) | 0.983 | 0.730 | 0.740 | 24.1 | 0.0 |
| Double line-to-ground fault (B-C) | 1.102 | 0.619 | 0.617 | 21.8 | 0.0 |
| Non-linear load (100 kW rectifier at 634) | 0.991 | 1.017 | 0.993 | 0.6 | 2.0 |

Faults give sags down to about 0.61 pu, and ground faults also give swells of
about 1.10 pu on the healthy phases. Full results for nodes 632, 634 and 671
are in `results/basecase_summary.csv`.

![Three-phase fault, node 634 voltage](results/basecase_fault_LLLG.png)

To reproduce, in MATLAB from the repository root:

```matlab
addpath('scripts'); build_basecase; run_basecase;
```

## D-STATCOM results (PI control, no DVR)

A 500 kVA D-STATCOM is connected at node 634 (480 V) and switched on at 0.6 s.
Control is in the synchronous reference frame: a PLL, PI regulators for the
DC-link voltage, the AC voltage and the two current components. The converter
is an averaged model (no switching), with the DC link represented by its power
balance.

**Load compensation** (unbalanced load plus 100 kW rectifier), measured on the
source side of node 634:

| Quantity | Without D-STATCOM | With D-STATCOM |
|---|---|---|
| Power factor | 0.860 | 1.000 |
| Reactive power from source (kvar) | 295.8 | -0.5 |
| Source current THD, worst phase (%) | 5.1 | 2.7 |
| Source current unbalance (%) | 7.1 | 0.7 |
| Mean source current (A rms) | 698 | 621 |
| Voltage THD at 634, worst phase (%) | 2.0 | 1.6 |

The DC-link voltage stays between 975 V and 1008 V around its 1000 V reference.

![D-STATCOM load compensation](results/dstatcom_compensation.png)

**Voltage support during faults** (voltage regulation mode, fault at node 680):

| Fault | Phase | Without D-STATCOM (pu) | With D-STATCOM (pu) |
|---|---|---|---|
| Three-phase-to-ground | A / B / C | 0.607 / 0.634 / 0.620 | 0.631 / 0.659 / 0.642 |
| Single line-to-ground (A) | A / B / C | 0.613 / 1.104 / 1.097 | 0.636 / 1.133 / 1.123 |

At its current limit (about 600 A rms) the D-STATCOM raises the sagged voltage
by only about 0.02 pu, and in the single-phase fault it also raises the swell
on the healthy phases. A shunt device of this rating cannot restore a deep sag
caused by an upstream fault, which is the case for adding the series DVR in
step 5.

Full results are in `results/dstatcom_summary.csv`. To reproduce:

```matlab
addpath('scripts'); build_basecase; build_dstatcom; run_dstatcom;
```

## DVR results (PI control, no D-STATCOM)

A DVR is connected in series between the transformer and node 634 and
enabled at 0.6 s. It injects the difference between a 1.0 pu reference and the
measured supply voltage (feed-forward), with PI regulators in the synchronous
reference frame trimming the load voltage. The injection limit is 0.5 pu per
phase. The converter is an averaged model (no switching) with ideal energy
storage; the series impedance stands for a 5 % injection transformer.

Load voltage at node 634 during the fault, phases A / B / C:

| Fault at node 680 | Supply side (pu) | Load side with DVR (pu) | Injected (pu) | Mean power (kW) | Energy in 0.2 s (kJ) |
|---|---|---|---|---|---|
| Three-phase-to-ground | 0.594 / 0.627 / 0.610 | 0.996 / 1.003 / 1.001 | 0.439 / 0.414 / 0.421 | 156.0 | 31.3 |
| Single line-to-ground (A) | 0.598 / 1.112 / 1.099 | 0.996 / 1.003 / 1.001 | 0.436 / 0.199 / 0.110 | 41.8 | 8.4 |
| Line-to-line (B-C) | 0.982 / 0.727 / 0.732 | 0.995 / 1.009 / 0.996 | 0.058 / 0.405 / 0.347 | 74.1 | 14.7 |
| Double line-to-ground (B-C) | 1.107 / 0.608 / 0.607 | 0.995 / 1.006 / 0.999 | 0.086 / 0.431 / 0.422 | 77.6 | 15.4 |

The DVR holds the load within 1 % of nominal in all four faults, including the
swells on the healthy phases, and keeps the load-voltage unbalance below 0.7 %.
The D-STATCOM alone reached only 0.63 pu in the same three-phase fault.

When the DVR is idle its series impedance lowers the load voltage by about
0.03 pu (0.959 / 0.991 / 0.968 pu); once enabled it restores 0.997 / 1.002 /
1.002 pu in normal operation.

![DVR, single line-to-ground fault](results/dvr_fault_LG_A.png)

Full results are in `results/dvr_summary.csv`. To reproduce:

```matlab
addpath('scripts'); build_basecase; build_dvr; run_dvr;
```

## PV and wind plants (no compensation)

Two inverter-interfaced plants are added to the base-case feeder and connect
at 0.2 s:

| Plant | Rating | Node | Source model |
|---|---|---|---|
| PV | 400 kW, 450 kVA | 634 (480 V) | Array I-V curve, perturb-and-observe MPPT |
| Wind | 500 kW, 550 kVA | 675 (4.16 kV) | Full-converter turbine: Cp(lambda) aerodynamics, one-mass rotor, optimal-torque MPPT, DC chopper |

Both use the same grid-side control: PLL, DC-link voltage PI, current PI loops,
unity power factor, a 1.1 pu current limit, and momentary cessation when the
voltage falls below 0.5 pu (resuming above 0.6 pu). The converters are averaged
models. Together the plants supply about a quarter of the feeder load.

**Resource variation** (irradiance 1000 to 300 W/m2 and wind 12 to 9 m/s, both
ramped between 1.0 s and 1.1 s):

| Quantity | Full output | Reduced output |
|---|---|---|
| PV power (kW) | 393 | 122 |
| Wind power (kW) | 495 | 249 (still falling at 1.8 s) |
| Node 634 voltage, A / B / C (pu) | 1.003 / 1.026 / 1.004 | 0.993 / 1.018 / 0.995 |
| Node 675 voltage, A / B / C (pu) | 0.989 / 1.045 / 0.979 | 0.984 / 1.042 / 0.975 |

Losing about 520 kW of generation moves the voltages by about 0.01 pu, so on
this feeder the DG variation alone is a mild disturbance.

![PV and wind output variation](results/dg_variation.png)

**Faults at node 680** (1.0 s to 1.2 s), voltages are phases A / B / C:

| Fault | Node 634 (pu) | Node 675 (pu) | PV during fault | Wind during fault |
|---|---|---|---|---|
| Three-phase-to-ground | 0.618 / 0.641 / 0.629 | 0.207 / 0.219 / 0.211 | 311 kW, current-limited | 0 kW, ceased |
| Single line-to-ground (A) | 0.622 / 1.109 / 1.107 | 0.213 / 1.229 / 1.194 | 386 kW | 494 kW |

In the three-phase fault the wind plant stops injecting because its node falls
to 0.21 pu, and the PV plant stays connected at its current limit. Both return
to full output after the fault. The DG raises the sag at node 634 only from
0.607 pu to 0.618 pu, so the load still needs the DVR.

The irradiance and wind changes are compressed into a fraction of a second,
and the turbine inertia constant is shortened to 0.5 s, so that they fit a
simulation of one to two seconds. Measured profiles lasting minutes are not
practical at a 50 microsecond step.

Full results are in `results/dg_summary.csv`. To reproduce:

```matlab
addpath('scripts'); build_basecase; build_dg; run_dg;
```

## Combined model: DVR, D-STATCOM, PV and wind together

`IEEE13_full.slx` puts all four devices on the feeder. The D-STATCOM and the PV
plant are on the load side of the DVR, and the rectifier load is on. Devices
switch on at 0.4 s and the fault runs from 0.8 s to 1.0 s. Results below use
the hand-tuned PI gains.

| Fault at node 680 | Supply side A / B / C (pu) | Load side A / B / C (pu) | DVR power (kW) | DVR energy (kJ) | Wind plant |
|---|---|---|---|---|---|
| Three-phase-to-ground | 0.616 / 0.645 / 0.627 | 0.997 / 1.005 / 0.998 | 44.5 | 8.9 | ceased |
| Single line-to-ground (A) | 0.620 / 1.132 / 1.119 | 0.998 / 1.005 / 0.997 | 15.1 | 3.0 | 494 kW |
| Line-to-line (B-C) | 1.008 / 0.747 / 0.749 | 0.996 / 1.012 / 0.992 | 21.6 | 4.3 | 366 kW |
| Double line-to-ground (B-C) | 1.133 / 0.626 / 0.625 | 0.997 / 1.008 / 0.995 | 17.6 | 3.5 | 333 kW |

- The load stays within about 1 % of nominal in every fault and the source
  power factor is 1.000.
- With the PV plant behind it, the DVR needs 44.5 kW in the three-phase fault
  instead of 156 kW when it works alone, about 70 % less, because the PV plant
  supplies most of the load locally.
- The wind plant at node 675 is outside the DVR's protection and still stops
  injecting in the three-phase fault.
- Source current THD reads 19 % because the PV plant leaves only a small
  source current. Measured against the 500 kVA transformer rating the
  distortion is 3.0 %, so both figures are reported.
- Load voltage THD is 3.6 %, higher than with either device alone.

![Combined model, single line-to-ground fault](results/full_fault_LG_A.png)

(The figure is drawn with the grey wolf gains, the set with the lowest mean cost.)

## Optimisation of the PI gains

### Five-method comparison (in progress)

Five optimisers are being compared on the same problem: particle swarm, grey
wolf, bat, whale and differential evolution. Each uses 8 agents, 6 iterations
(56 simulations) and, for a given seed, the same starting population. Three
seeds are run per method so that the ranking rests on a mean, not on one run.

Status at 07 October 2026, 00:23: 5 of 15 runs finished. The table is partial and the
order may change as the remaining runs complete. The hand-tuned cost is
8.632; lower is better.

| Method | Seed 1 | Seed 2 | Seed 3 | Mean so far | Reduction from hand-tuned |
|---|---|---|---|---|---|
| Grey wolf | 8.213 | running or queued | running or queued | 8.213 | 4.9 % |
| Bat | 8.237 | running or queued | running or queued | 8.237 | 4.6 % |
| Differential evolution | 8.246 | running or queued | running or queued | 8.246 | 4.5 % |
| Whale | 8.255 | running or queued | running or queued | 8.255 | 4.4 % |
| Particle swarm | 8.261 | running or queued | running or queued | 8.261 | 4.3 % |

The finished runs are within about 1 % of each other, so no method can be
called best yet. The placement and rating study and the test of each method's
gains on all four faults follow when the runs finish.

Two optimisers tune five gains on the combined model: particle swarm (PSO) and
the grey wolf optimiser (GWO). Both use 8 agents, 6 iterations (56 simulations)
and the same starting population, which includes the hand-tuned gains. Each
candidate is scored on one simulation with a single line-to-ground fault. The
cost is

`4 x load-voltage error + voltage THD + current distortion + negative-sequence current + 100 x (1 - power factor) + 0.2 x DC-link deviation`

with every term in percent and the two current terms taken against the
transformer rating.

| Gain | Hand-tuned | PSO | GWO | Search range |
|---|---|---|---|---|
| D-STATCOM current-loop bandwidth (Hz) | 1500 | 1755 | 1570 | 500 to 2500 |
| D-STATCOM DC-link Kp (A/V) | 1.0 | 2.35 | 2.35 | 0.2 to 5 |
| D-STATCOM DC-link Ki (A/V/s) | 15 | 105 | 27 | 2 to 200 |
| DVR load-voltage Kp | 0.2 | 0.90 | 0.90 | 0 to 0.9 |
| DVR load-voltage Ki | 200 | 20 | 319 | 20 to 2000 |
| Cost on the tuning fault | 8.632 | 8.261 | 8.213 | |
| Reduction from hand-tuned | | 4.3 % | 4.9 % | |

Each gain set was then tested on all four fault types:

| Quantity | Hand-tuned | PSO | GWO |
|---|---|---|---|
| Cost, four faults | 8.59 / 8.60 / 9.11 / 8.83 | 8.10 / 8.21 / 8.38 / 8.14 | 8.06 / 8.17 / 8.38 / 8.13 |
| Load voltage THD (%) | 3.55 | 3.01 | 2.88 |
| Negative-sequence source current (% of rating) | 0.74 | 0.65 | 0.71 |
| Source current distortion (% of rating) | 3.02 | 3.05 | 3.14 |
| Load voltage unbalance during fault, four faults (%) | 0.04 / 0.34 / 0.77 / 0.68 | 0.03 / 0.22 / 0.49 / 0.44 | 0.02 / 0.21 / 0.48 / 0.43 |
| DC-link deviation (%) | 1.4 | 1.7 | 1.4 |

![Optimisation convergence](results/optim_convergence.png)

- Both optimisers improve on the hand-tuned gains by a small amount: 4 to 5 %
  on the fault used for tuning and 5 to 8 % on the four test faults.
- GWO finishes 0.6 % below PSO. With one run each and 56 simulations, that
  difference is too small to rank the two methods; repeated runs with
  different seeds would be needed.
- The two agree on the D-STATCOM DC-link Kp (2.35) and push the DVR Kp to the
  top of its range, but disagree on both integral gains. The cost is not
  sensitive to those, so they should not be read as optima.
- The hand-tuned gains were already close to the best the PI structure can do
  here. The remaining limits are structural (harmonic tracking of the current
  loop, and the wind plant outside the DVR) rather than a matter of tuning.

An earlier PSO run without the voltage THD term lowered its cost by 17 % but
raised load voltage THD from 3.55 % to 4.68 %, so the term was added and the
runs repeated. Device location and rating have not been optimised.

To reproduce (each optimisation takes about 10 minutes on four cores and needs
the Parallel Computing Toolbox; PSO also needs the Global Optimization
Toolbox):

```matlab
addpath('scripts'); build_basecase; build_full;
optimise_gains('pso'); optimise_gains('gwo'); run_full;
```

## Contents

| File | Description |
|---|---|
| `IEEE13bus_v2019b_Discrete.slx` | IEEE 13-node test feeder, discrete, 60 Hz, 4.16 kV, Ts = 50 µs |
| `IEEE13_basecase.slx` | IEEE 13 feeder with a fault at node 680, a switchable rectifier load at node 634, and waveform logging |
| `scripts/build_basecase.m` | Builds `IEEE13_basecase.slx` from the IEEE 13 model |
| `scripts/run_basecase.m` | Runs the base-case scenarios and writes the summary and figures |
| `IEEE13_dstatcom.slx` | Base-case model plus the D-STATCOM at node 634 and its controller |
| `scripts/build_dstatcom.m` | Builds `IEEE13_dstatcom.slx` |
| `scripts/dstatcom_controller.m` | D-STATCOM control code (copied into the model's MATLAB Function block) |
| `scripts/run_dstatcom.m` | Runs the D-STATCOM scenarios and writes the summary and figures |
| `IEEE13_dvr.slx` | Base-case model plus the series DVR at node 634 and its controller |
| `scripts/build_dvr.m` | Builds `IEEE13_dvr.slx` |
| `scripts/dvr_controller.m` | DVR control code (copied into the model's MATLAB Function block) |
| `scripts/run_dvr.m` | Runs the DVR scenarios and writes the summary and figures |
| `IEEE13_dg.slx` | Base-case model plus the PV plant at node 634 and the wind plant at node 675 |
| `IEEE13_full.slx` | Base-case model plus the DVR, the D-STATCOM, the PV plant and the wind plant |
| `scripts/build_full.m`, `scripts/run_full.m` | Build the combined model; run its four faults with the hand-tuned, PSO and GWO gains |
| `scripts/optimise_gains.m` | Particle swarm and grey wolf optimisation of the PI gains |
| `scripts/full_input.m`, `scripts/full_metrics.m` | One simulation setup of the combined model, and its performance measures and cost |
| `scripts/add_dvr.m`, `scripts/add_dstatcom.m` | Add the DVR or the D-STATCOM to a model built from the base case |
| `scripts/log_source_current.m` | Logs the source-side current at node 634 |
| `scripts/add_dg.m` | Adds the two plants to a model built from the base case |
| `scripts/build_dg.m` | Builds `IEEE13_dg.slx` |
| `scripts/dg_controller.m` | PV and wind plant models and inverter control (copied into the MATLAB Function blocks) |
| `scripts/run_dg.m` | Runs the DG scenarios and writes the summary and figures |
| `scripts/group_blocks.m` | Groups a device's blocks into one subsystem (`D-STATCOM`, `DVR`, `PV Plant`, `Wind Plant`) |
| `MATLAB_R2022/` | The models in R2022a format with the scripts, for MATLAB R2022a or R2022b |
| `scripts/export_r2022.m` | Refreshes the `MATLAB_R2022` folder |
| `scripts/pq_analyse.m` | Fundamental phasors, THD and unbalance of a three-phase signal |
| `results/` | Summary tables and one figure per scenario |

## Older MATLAB releases

The models at the top level are saved in R2024b. The `MATLAB_R2022` folder
holds the same models saved in R2022a format, with a copy of the scripts and
its own instructions, for MATLAB R2022a or R2022b. Run `export_r2022` to
refresh it after the models or scripts change.

## Requirements

- MATLAB R2024b (the model was saved in R2019b and opens in later releases)
- Simulink and Simscape Electrical (Specialized Power Systems)
- Step 7: Global Optimization Toolbox and Parallel Computing Toolbox
- Later steps: Deep Learning Toolbox

## Acknowledgement

The IEEE 13-bus Simulink model (`IEEE13bus_v2019b_Discrete.slx`) is the work of
Arun Suresh and Dr. Sukumar Kamalasadan, University of North Carolina at
Charlotte, released under the MIT License (Copyright (c) 2023 Arun Suresh).

## References

1. M. A. Kamarposhti, I. Colak, P. Thounthong, K. Eguchi, "Modeling and Simulation of DVR and D-STATCOM in Presence of Wind Energy System," *Computers, Materials & Continua*, vol. 74, no. 2, 2023. doi:10.32604/cmc.2023.034082
2. J. S. Naick et al., "Performance Analysis of DVR and STATCOM for Power Quality Improvement in Grid-Connected Solar Systems," *IJMTST*, vol. 11, no. 9, pp. 184-193, 2025. doi:10.5281/zenodo.18124614
3. T. O. Prakash, P. S. Puhan, A. Bag, K. Sumanth, "Battery and SMES-Based Dynamic Voltage Restorer Performance Verification Under Various Load Conditions in a Grid-Connected PV-Wind System," in *Sustainable Energy and Technological Advancements*, Springer, 2023. doi:10.1007/978-981-99-4175-9_18
4. M. A. Ahmed, M. A. Bayoumi, "A novel deep learning-based control for voltage sag prediction and DVR-LVRT coordination in grid-connected wind turbine systems," *Ain Shams Engineering Journal*, vol. 17, 103882, 2026.
5. Y. Benatallah, A. Benali, M. Dahane, S. Benali, "Real time fuzzy energy management of hybrid storage systems in DC microgrids with dynamic voltage restorer assisted power quality enhancement," *IJPEDS*, vol. 17, no. 3, pp. 2197-2209, 2026. doi:10.11591/ijpeds.v17.i3.pp2197-2209
6. R. K. Varma, S. A. Rahman, T. Vanderheide, "New Control of PV Solar Farm as STATCOM (PV-STATCOM) for Increasing Grid Power Transmission Limits During Night and Day," *IEEE Trans. Power Delivery*, vol. 30, no. 2, pp. 755-763, 2015.
7. S. Ranjan et al., "Maiden Voltage Control Analysis of Hybrid Power System With Dynamic Voltage Restorer," *IEEE Access*, vol. 9, 2021. doi:10.1109/ACCESS.2021.3071815
8. R. K. Sah, H. Bhusal, N. K. Mahato, B. Tamang, "Impacts of Photovoltaic Penetration on Transient Stability of Power System," *Proc. 11th IOE Graduate Conference*, 2022.
9. B. S. Goud, B. L. Rao, "Power Quality Enhancement in Grid-Connected PV/Wind/Battery Using UPQC: Atom Search Optimization," *Journal of Electrical Engineering & Technology*, vol. 16, pp. 821-835, 2021. doi:10.1007/s42835-020-00644-x
10. S. K. Yadav, K. B. Yadav, A. Priyadarshi, "Performance analysis of three-phase solar PV, BESS, and Wind integrated UPQC for power quality improvement," *Computers and Electrical Engineering*, vol. 116, 109230, 2024. doi:10.1016/j.compeleceng.2024.109230
11. S. Mirjalili, S. M. Mirjalili, A. Lewis, "Grey Wolf Optimizer," *Advances in Engineering Software*, vol. 69, pp. 46-61, 2014. (Method reference, cited from memory; not among the reviewed PDFs.)
