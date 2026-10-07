function show_results(mode)
% Shows every result of steps 3 to 6 in one window with a tab per figure,
% and prints the main tables.
%   show_results          shows the saved results at once (default)
%   show_results('run')   first simulates everything again (about 10
%                         minutes), then shows the new results
% Steps: 3 base case, 4 D-STATCOM, 5 DVR, 6 PV and wind plants.

if nargin < 1, mode = 'saved'; end
root = fileparts(fileparts(mfilename('fullpath')));
res = fullfile(root, 'results');

if strcmp(mode, 'run')
    steps = {'base case', @run_basecase; 'D-STATCOM', @run_dstatcom; ...
             'DVR', @run_dvr; 'PV and wind', @run_dg};
    for k = 1:size(steps, 1)
        fprintf('\n===== Simulating step %d of 4: %s =====\n', k, steps{k, 1});
        evalc('steps{k, 2}()');           % run quietly; tables are printed below
    end
end

%% Tables
T = readtable(fullfile(res, 'basecase_summary.csv'));
T = T(T.bus == 634, :);
fprintf('\nSTEP 3  Base case, no compensation: node 634 voltage during the disturbance\n');
disp(table(string(T.scenario), T.Va_pu, T.Vb_pu, T.Vc_pu, T.VUF_pct, T.THDv_max_pct, ...
    'VariableNames', {'scenario', 'Va_pu', 'Vb_pu', 'Vc_pu', 'unbalance_pct', 'voltage_THD_pct'}));

T = readtable(fullfile(res, 'dstatcom_summary.csv'));
C = T(strcmp(T.scenario, 'compensation'), :);
fprintf('STEP 4  D-STATCOM: load compensation, source side of node 634\n');
disp(table(string(C.window), C.PF, C.Q_kvar, C.THDi_max_pct, C.Iunb_pct, C.Is_rms_A, ...
    'VariableNames', {'case', 'power_factor', 'Q_from_source_kvar', 'current_THD_pct', ...
    'current_unbalance_pct', 'source_current_A'}));
F = T(strcmp(T.window, 'during_fault'), :);
fprintf('STEP 4  D-STATCOM: node 634 voltage during faults\n');
disp(table(string(F.scenario), F.Va_pu, F.Vb_pu, F.Vc_pu, F.Idst_rms_A, ...
    'VariableNames', {'scenario', 'Va_pu', 'Vb_pu', 'Vc_pu', 'dstatcom_current_A'}));

T = readtable(fullfile(res, 'dvr_summary.csv'));
F = T(strcmp(T.window, 'during_fault'), :);
fprintf('STEP 5  DVR: supply and load voltage during faults\n');
disp(table(string(F.scenario), [F.Vs_a_pu F.Vs_b_pu F.Vs_c_pu], [F.Vl_a_pu F.Vl_b_pu F.Vl_c_pu], ...
    F.Pinj_mean_kW, F.Einj_fault_kJ, 'VariableNames', ...
    {'scenario', 'supply_abc_pu', 'load_abc_pu', 'DVR_power_kW', 'DVR_energy_kJ'}));

T = readtable(fullfile(res, 'dg_summary.csv'));
fprintf('STEP 6  PV and wind plants, no compensation\n');
disp(table(string(T.scenario), string(T.window), [T.V634_a_pu T.V634_b_pu T.V634_c_pu], ...
    T.Ppv_kW, T.Pwind_kW, T.Wind_ceased, 'VariableNames', ...
    {'scenario', 'window', 'node634_abc_pu', 'PV_kW', 'wind_kW', 'wind_stopped'}));

%% Figures, one tab each
figs = {
    '3  Three-phase fault',         'basecase_fault_LLLG.png'
    '3  Single-phase fault',       'basecase_fault_LG_A.png'
    '3  Rectifier load',           'basecase_nonlinear_load.png'
    '4  D-STATCOM on',   'dstatcom_compensation.png'
    '4  D-STATCOM, fault',     'dstatcom_fault_LLLG.png'
    '5  DVR, three-phase',   'dvr_fault_LLLG.png'
    '5  DVR, single-phase',  'dvr_fault_LG_A.png'
    '6  Sun and wind change',      'dg_variation.png'
    '6  Plants, fault',        'dg_fault_LLLG.png'
    };
fig = figure('Color', 'w', 'Name', 'Results of steps 3 to 6', 'NumberTitle', 'off', ...
    'Position', [60 40 1150 820]);
tg = uitabgroup(fig);
for k = 1:size(figs, 1)
    f = fullfile(res, figs{k, 2});
    if ~exist(f, 'file'), continue; end
    tab = uitab(tg, 'Title', figs{k, 1}, 'BackgroundColor', 'w');
    ax = axes(tab, 'Position', [0.01 0.01 0.98 0.98]);
    image(ax, imread(f)); axis(ax, 'image'); axis(ax, 'off');
end
fprintf('The figures are in the window "Results of steps 3 to 6": one tab per figure, numbered by step.\n');
end
