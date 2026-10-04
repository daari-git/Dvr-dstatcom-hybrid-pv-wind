# DVR and D-STATCOM with Hybrid PV-Wind Distributed Generation

Coordinated control of a Dynamic Voltage Restorer (DVR) and a Distribution
Static Compensator (D-STATCOM) for power quality improvement in a distribution
feeder with both solar PV and wind generation, using optimisation and machine
learning. Modelled in MATLAB/Simulink on the IEEE 13-bus test feeder.

## Research gap

Existing studies cover only part of the problem:

- DVR and D-STATCOM are compared with a single source (wind only or solar only), not with PV and wind together.
- Where PV and wind are combined, only a DVR is used, with conventional PQ-theory and hysteresis control.
- Intelligent control (fuzzy, deep learning) is applied to one device with one source, not to the coordination of both devices.

This work addresses the coordinated operation of both devices with both
sources, with an optimisation and ML layer deciding how they share the
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
| 1 | Literature review and research gap | Gap statement, reference list | In progress (8 papers, more to come) |
| 2 | Validate IEEE 13-bus benchmark model | Node voltages within 0.01 pu of benchmark | Done |
| 3 | Base case with faults and non-linear load | Uncompensated sag, THD and unbalance at the sensitive load bus | Done |
| 4 | D-STATCOM alone with PI control | Voltage regulation, THD, reactive power | Done |
| 5 | DVR alone with PI control | Restored load voltage, injected voltage and energy | To do |
| 6 | Add PV and wind plants | Feeder with hybrid DG under varying irradiance and wind | To do |
| 7 | Offline optimisation (PSO or grey wolf) | Device location, rating and PI gains | To do |
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

## Contents

| File | Description |
|---|---|
| `IEEE13bus_v2019b_Discrete.slx` | IEEE 13-node test feeder, discrete, 60 Hz, 4.16 kV, Ts = 50 µs |
| `IEEE13_basecase.slx` | IEEE 13 feeder with a fault at node 680, a switchable rectifier load at node 634, and waveform logging |
| `scripts/build_basecase.m` | Builds `IEEE13_basecase.slx` from the IEEE 13 model |
| `scripts/run_basecase.m` | Runs the base-case scenarios and writes the summary and figures |
| `IEEE13_dstatcom.slx` | Base-case model plus the D-STATCOM at node 634 and its controller |
| `scripts/build_dstatcom.m` | Builds `IEEE13_dstatcom.slx` from the base-case model |
| `scripts/dstatcom_controller.m` | D-STATCOM control code (copied into the model's MATLAB Function block) |
| `scripts/run_dstatcom.m` | Runs the D-STATCOM scenarios and writes the summary and figures |
| `scripts/pq_analyse.m` | Fundamental phasors, THD and unbalance of a three-phase signal |
| `results/` | Summary tables and one figure per scenario |
| `LICENSE` | MIT licence for this project |
| `LICENSE-IEEE13-model.txt` | MIT licence of the IEEE 13 model (Arun Suresh, UNC Charlotte) |

## Requirements

- MATLAB R2024b (the model was saved in R2019b and opens in later releases)
- Simulink and Simscape Electrical (Specialized Power Systems)
- Later steps: Global Optimization Toolbox, Deep Learning Toolbox

## License

This project is released under the MIT License, Copyright (c) 2026 Subash
Khanal. See `LICENSE`.

The IEEE 13-bus Simulink model is third-party work by Arun Suresh (University
of North Carolina at Charlotte), also under the MIT License. Its original
notice is kept in `LICENSE-IEEE13-model.txt`.

## References

1. M. A. Kamarposhti, I. Colak, P. Thounthong, K. Eguchi, "Modeling and Simulation of DVR and D-STATCOM in Presence of Wind Energy System," *Computers, Materials & Continua*, vol. 74, no. 2, 2023. doi:10.32604/cmc.2023.034082
2. J. S. Naick et al., "Performance Analysis of DVR and STATCOM for Power Quality Improvement in Grid-Connected Solar Systems," *IJMTST*, vol. 11, no. 9, pp. 184-193, 2025. doi:10.5281/zenodo.18124614
3. T. O. Prakash, P. S. Puhan, A. Bag, K. Sumanth, "Battery and SMES-Based Dynamic Voltage Restorer Performance Verification Under Various Load Conditions in a Grid-Connected PV-Wind System," in *Sustainable Energy and Technological Advancements*, Springer, 2023. doi:10.1007/978-981-99-4175-9_18
4. M. A. Ahmed, M. A. Bayoumi, "A novel deep learning-based control for voltage sag prediction and DVR-LVRT coordination in grid-connected wind turbine systems," *Ain Shams Engineering Journal*, vol. 17, 103882, 2026.
5. Y. Benatallah, A. Benali, M. Dahane, S. Benali, "Real time fuzzy energy management of hybrid storage systems in DC microgrids with dynamic voltage restorer assisted power quality enhancement," *IJPEDS*, vol. 17, no. 3, pp. 2197-2209, 2026. doi:10.11591/ijpeds.v17.i3.pp2197-2209
6. R. K. Varma, S. A. Rahman, T. Vanderheide, "New Control of PV Solar Farm as STATCOM (PV-STATCOM) for Increasing Grid Power Transmission Limits During Night and Day," *IEEE Trans. Power Delivery*, vol. 30, no. 2, pp. 755-763, 2015.
7. S. Ranjan et al., "Maiden Voltage Control Analysis of Hybrid Power System With Dynamic Voltage Restorer," *IEEE Access*, vol. 9, 2021. doi:10.1109/ACCESS.2021.3071815
8. R. K. Sah, H. Bhusal, N. K. Mahato, B. Tamang, "Impacts of Photovoltaic Penetration on Transient Stability of Power System," *Proc. 11th IOE Graduate Conference*, 2022.
