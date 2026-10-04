# DVR and D-STATCOM with Hybrid PV-Wind Distributed Generation

Research on coordinated control of a Dynamic Voltage Restorer (DVR) and a
Distribution Static Compensator (D-STATCOM) in a distribution feeder with both
solar PV and wind generation.

## Status

- [x] Literature collected (first eight papers)
- [x] IEEE 13-bus benchmark model checked against published node voltages (within 0.01 pu)
- [ ] Base case: fault and uncompensated sag at the sensitive load bus
- [ ] D-STATCOM alone, DVR alone (PI control)
- [ ] PV and wind plants added
- [ ] Coordinated operation, optimisation and ML layer

## Contents

| File | Description |
|---|---|
| `IEEE13bus_v2019b_Discrete.slx` | IEEE 13-node test feeder, discrete, 60 Hz, 4.16 kV, Ts = 50 µs |
| `LICENSE-IEEE13-model.txt` | MIT licence of the IEEE 13 model (Arun Suresh, UNC Charlotte) |

Tested with MATLAB R2024b and Simscape Electrical (Specialized Power Systems).

## References

1. M. A. Kamarposhti, I. Colak, P. Thounthong, K. Eguchi, "Modeling and Simulation of DVR and D-STATCOM in Presence of Wind Energy System," *Computers, Materials & Continua*, vol. 74, no. 2, 2023. doi:10.32604/cmc.2023.034082
2. J. S. Naick et al., "Performance Analysis of DVR and STATCOM for Power Quality Improvement in Grid-Connected Solar Systems," *IJMTST*, vol. 11, no. 9, pp. 184-193, 2025. doi:10.5281/zenodo.18124614
3. T. O. Prakash, P. S. Puhan, A. Bag, K. Sumanth, "Battery and SMES-Based Dynamic Voltage Restorer Performance Verification Under Various Load Conditions in a Grid-Connected PV-Wind System," in *Sustainable Energy and Technological Advancements*, Springer, 2023. doi:10.1007/978-981-99-4175-9_18
4. M. A. Ahmed, M. A. Bayoumi, "A novel deep learning-based control for voltage sag prediction and DVR-LVRT coordination in grid-connected wind turbine systems," *Ain Shams Engineering Journal*, vol. 17, 103882, 2026.
5. Y. Benatallah, A. Benali, M. Dahane, S. Benali, "Real time fuzzy energy management of hybrid storage systems in DC microgrids with dynamic voltage restorer assisted power quality enhancement," *IJPEDS*, vol. 17, no. 3, pp. 2197-2209, 2026. doi:10.11591/ijpeds.v17.i3.pp2197-2209
6. R. K. Varma, S. A. Rahman, T. Vanderheide, "New Control of PV Solar Farm as STATCOM (PV-STATCOM) for Increasing Grid Power Transmission Limits During Night and Day," *IEEE Trans. Power Delivery*, vol. 30, no. 2, pp. 755-763, 2015.
7. S. Ranjan et al., "Maiden Voltage Control Analysis of Hybrid Power System With Dynamic Voltage Restorer," *IEEE Access*, vol. 9, 2021. doi:10.1109/ACCESS.2021.3071815
8. R. K. Sah, H. Bhusal, N. K. Mahato, B. Tamang, "Impacts of Photovoltaic Penetration on Transient Stability of Power System," *Proc. 11th IOE Graduate Conference*, 2022.
