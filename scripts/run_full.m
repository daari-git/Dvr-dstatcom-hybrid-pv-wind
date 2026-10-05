function T = run_full()
% Runs the four fault scenarios on IEEE13_full.slx (DVR, D-STATCOM, PV and
% wind together) with the hand-tuned gains and with each set of gains found
% by optimise_gains ('pso', 'gwo'). Writes results/full_summary.csv and one
% figure per fault, drawn for the gain set with the lowest mean cost.
% Run build_basecase and build_full first.

root = fileparts(fileparts(mfilename('fullpath')));
outd = fullfile(root, 'results');
if ~exist(outd, 'dir'), mkdir(outd); end

tl = struct('tNL', 0.3, 'tDev', 0.4, 'tOn', 0.8, 'tOff', 1.0, 'tStop', 1.2, ...
    'tSteady', 0.7, 'tFault', 0.9);
scen = {'fault_LLLG', 'ABC', 'on'; 'fault_LG_A', 'A', 'on'; ...
        'fault_LL_BC', 'BC', 'off'; 'fault_LLG_BC', 'BC', 'on'};
sets = {'hand_tuned', [1500; 1; 15; 5; 500], [0.2; 200]};
meth = {'pso', 'gwo'};
for k = 1:numel(meth)
    f = fullfile(outd, sprintf('optim_%s_best.csv', meth{k}));
    if exist(f, 'file')
        x = readmatrix(f);
        sets(end+1, :) = {meth{k}, [x(1); x(2); x(3); 5; 500], [x(4); x(5)]}; %#ok<AGROW>
    end
end

in = Simulink.SimulationInput.empty; tag = {};
for g = 1:size(sets, 1)
    for s = 1:size(scen, 1)
        in(end+1) = full_input(scen{s, 2}, scen{s, 3}, tl, sets{g, 2}, sets{g, 3}); %#ok<AGROW>
        tag(end+1, :) = {sets{g, 1}, scen{s, 1}}; %#ok<AGROW>
    end
end
out = parsim(in, 'ShowProgress', 'off', 'SetupFcn', @() addpath(root, fullfile(root, 'scripts')));

rows = {};
for k = 1:numel(out)
    m = full_metrics(out(k), tl);
    rows(end+1, :) = {tag{k, 1}, tag{k, 2}, m.Vs_fault(1), m.Vs_fault(2), m.Vs_fault(3), ...
        m.Vl_fault(1), m.Vl_fault(2), m.Vl_fault(3), m.Vunb_fault, m.eV, ...
        m.PF, m.Q_kvar, m.THDi, m.TDD, m.Iunb, m.I2, m.THDv, m.VdcDev, m.Pdvr_kW, m.Edvr_kJ, ...
        m.Ppv_kW, m.Pwind_kW, m.wind_ceased, m.J}; %#ok<AGROW>
end
J = cell2mat(rows(:, end));
[~, g] = min(arrayfun(@(i) mean(J(strcmp(tag(:, 1), sets{i, 1}))), 1:size(sets, 1)));
for k = find(strcmp(tag(:, 1), sets{g, 1}))'
    plot_scenario(out(k), tag{k, 2}, tag{k, 1}, tl, outd);
end
T = cell2table(rows, 'VariableNames', {'gains', 'scenario', ...
    'Vs_a_pu', 'Vs_b_pu', 'Vs_c_pu', 'Vl_a_pu', 'Vl_b_pu', 'Vl_c_pu', 'Vl_unb_pct', ...
    'Vl_error_pct', 'PF', 'Q_kvar', 'THDi_max_pct', 'TDD_pct', 'Iunb_pct', ...
    'I2_pct_of_rated', 'THDv_max_pct', ...
    'Vdc_dev_pct', 'Pdvr_kW', 'Edvr_kJ', 'Ppv_kW', 'Pwind_kW', 'wind_ceased', 'cost'});
writetable(T, fullfile(outd, 'full_summary.csv'));
disp(T);
end

function plot_scenario(out, name, gains, tl, outd)
col = [42 120 214; 235 104 52; 27 175 122] / 255;          % phases A, B, C
cpl = [237 161 0; 74 58 167] / 255;                        % PV, wind
ink = [0.25 0.25 0.25];
vb = 480/sqrt(3);
lab = {'Phase A', 'Phase B', 'Phase C'};

fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 900 980]);
tlo = tiledlayout(fig, 4, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tlo, sprintf('DVR, D-STATCOM, PV and wind together (%s gains): %s', ...
    strrep(gains, '_', ' '), strrep(name, '_', ' ')), 'FontWeight', 'bold', 'Color', ink);

sig = {'log_Vs634', 'log_V634'}; yl = {'Supply voltage (pu)', 'Load voltage (pu)'};
for k = 1:2
    ts = out.get(sig{k}); t = ts.Time; w = t >= tl.tOn - 0.05 & t <= tl.tOff + 0.07;
    y = squeeze(ts.Data) / (vb*sqrt(2));
    ax = nexttile; hold(ax, 'on');
    for p = 1:3, plot(ax, t(w), y(w, p), 'Color', col(p, :), 'LineWidth', 1); end
    ylabel(ax, yl{k}); ylim(ax, [-1.5 1.5]); style(ax, ink);
    legend(ax, lab, 'Location', 'eastoutside', 'Box', 'off');
end

ts = out.get('log_Is634'); t = ts.Time; w = t >= tl.tOn - 0.05 & t <= tl.tOff + 0.07;
y = squeeze(ts.Data);
ax = nexttile; hold(ax, 'on');
for p = 1:3, plot(ax, t(w), y(w, p), 'Color', col(p, :), 'LineWidth', 1); end
ylabel(ax, 'Source current (A)'); style(ax, ink);
legend(ax, lab, 'Location', 'eastoutside', 'Box', 'off');

pv = out.get('log_pv'); wd = out.get('log_wind');
a = squeeze(pv.Data); if size(a, 1) == 8, a = a.'; end
b = squeeze(wd.Data); if size(b, 1) == 8, b = b.'; end
t = pv.Time; w = t >= tl.tOn - 0.05 & t <= tl.tOff + 0.07;
ax = nexttile; hold(ax, 'on');
plot(ax, t(w), a(w, 2), 'Color', cpl(1, :), 'LineWidth', 2);
plot(ax, t(w), b(w, 2), 'Color', cpl(2, :), 'LineWidth', 2);
ylabel(ax, 'Active power (kW)'); xlabel(ax, 'Time (s)'); style(ax, ink);
legend(ax, {'PV plant', 'Wind plant'}, 'Location', 'eastoutside', 'Box', 'off');

exportgraphics(fig, fullfile(outd, ['full_' name '.png']), 'Resolution', 200);
close(fig);
end

function style(ax, ink)
grid(ax, 'on'); box(ax, 'off');
ax.GridColor = [0.85 0.85 0.85]; ax.GridAlpha = 1;
ax.XColor = ink; ax.YColor = ink; ax.FontSize = 10;
end
