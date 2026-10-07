function T = compare_models(mode)
% Compares the five model configurations under the same faults: the voltage
% at the protected load (node 634) with no device, with the PV and wind
% plants, with the D-STATCOM, with the DVR, and with everything together.
%   compare_models          uses the saved results (default, immediate)
%   compare_models('run')   simulates one three-phase fault on all five
%                           models (about 4 minutes) and also shows how the
%                           voltage develops in time
% Also prints the comparison of the optimisation methods, if it has been run.

if nargin < 1, mode = 'saved'; end
root = fileparts(fileparts(mfilename('fullpath')));
res = fullfile(root, 'results');
cfg = {'No compensation', 'PV and wind only', 'D-STATCOM only', 'DVR only', 'All together'};
col = [150 150 145; 237 161 0; 235 104 52; 42 120 214; 27 175 122] / 255;
ink = [0.25 0.25 0.25];

if strcmp(mode, 'run')
    [V, vr, t, tOn, tOff] = simulate_all(root);
    faults = {'Three-phase-to-ground fault'};
else
    V = saved(res);                       % faults x configurations x phases
    faults = {'Three-phase-to-ground fault', 'Single line-to-ground fault (A)'};
end

%% Table
rows = {};
for f = 1:numel(faults)
    for c = 1:numel(cfg)
        v = squeeze(V(f, c, :))';
        rows(end+1, :) = {faults{f}, cfg{c}, v(1), v(2), v(3), min(v), max(v), ...
            verdict(v)}; %#ok<AGROW>
    end
end
T = cell2table(rows, 'VariableNames', {'fault', 'configuration', 'Va_pu', 'Vb_pu', 'Vc_pu', ...
    'lowest_pu', 'highest_pu', 'within_0p9_to_1p1'});
fprintf('\nVoltage at the protected load (node 634) during the fault\n');
disp(T);

%% Bar chart: lowest phase voltage per configuration
fig = figure('Color', 'w', 'Name', 'Comparison of the models', 'NumberTitle', 'off', ...
    'Position', [80 80 1000 460 + 300*strcmp(mode, 'run')]);
if strcmp(mode, 'run'), tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
else, tl = tiledlayout(fig, 1, 1, 'Padding', 'compact'); end
title(tl, 'Only the configurations with a DVR keep the load above 0.9 pu', ...
    'FontWeight', 'bold', 'Color', ink);
ax = nexttile(tl); hold(ax, 'on');
low = min(V, [], 3);                      % faults x configurations
nf = numel(faults); nc = numel(cfg); wbar = 0.15;
for c = 1:nc
    x = (1:nf) + (c - (nc + 1)/2)*wbar*1.1;
    bar(ax, x, low(:, c), wbar, 'FaceColor', col(c, :), 'EdgeColor', 'none');
    text(ax, x, low(:, c) + 0.03, compose('%.2f', low(:, c)), ...
        'HorizontalAlignment', 'center', 'Color', ink, 'FontSize', 9);
end
yline(ax, 0.9, ':', '0.9 pu sag limit', 'Color', ink, ...
    'LabelHorizontalAlignment', 'left', 'HandleVisibility', 'off');
xticks(ax, 1:nf); xticklabels(ax, faults); xlim(ax, [0.5 nf + 0.5]); ylim(ax, [0 1.2]);
ylabel(ax, 'Lowest phase voltage in the fault (pu)');
legend(ax, cfg, 'Location', 'eastoutside', 'Box', 'off');
style(ax, ink);

if strcmp(mode, 'run')
    ax = nexttile(tl); hold(ax, 'on');
    for c = 1:nc, plot(ax, t, vr(:, c), 'Color', col(c, :), 'LineWidth', 2); end
    yline(ax, 0.9, ':', 'Color', ink, 'HandleVisibility', 'off');
    xlim(ax, [tOn - 0.1, tOff + 0.1]); ylim(ax, [0 1.2]);
    xlabel(ax, 'Time (s)'); ylabel(ax, 'Lowest phase RMS voltage (pu)');
    legend(ax, cfg, 'Location', 'eastoutside', 'Box', 'off');
    style(ax, ink);
end

%% Optimisation methods, if available
f = fullfile(res, 'optim_comparison.csv');
if exist(f, 'file')
    fprintf('Optimisation of the PI gains: cost with each method (lower is better)\n');
    disp(readtable(f));
end
end

function V = saved(res)
% Collects node 634 voltage during the fault from the saved summary tables
V = nan(2, 5, 3); sc = {'fault_LLLG', 'fault_LG_A'};
B = readtable(fullfile(res, 'basecase_summary.csv'));
G = readtable(fullfile(res, 'dg_summary.csv'));
S = readtable(fullfile(res, 'dstatcom_summary.csv'));
D = readtable(fullfile(res, 'dvr_summary.csv'));
for f = 1:2
    r = B(strcmp(B.scenario, sc{f}) & B.bus == 634, :);
    V(f, 1, :) = [r.Va_pu r.Vb_pu r.Vc_pu];
    r = G(strcmp(G.scenario, sc{f}) & strcmp(G.window, 'during_fault'), :);
    V(f, 2, :) = [r.V634_a_pu r.V634_b_pu r.V634_c_pu];
    r = S(strcmp(S.scenario, sc{f}) & strcmp(S.window, 'during_fault'), :);
    V(f, 3, :) = [r.Va_pu r.Vb_pu r.Vc_pu];
    r = D(strcmp(D.scenario, sc{f}) & strcmp(D.window, 'during_fault'), :);
    V(f, 4, :) = [r.Vl_a_pu r.Vl_b_pu r.Vl_c_pu];
end
ff = fullfile(res, 'full_summary.csv');
if exist(ff, 'file')
    F = readtable(ff);
    for f = 1:2
        r = F(strcmp(F.gains, 'hand_tuned') & strcmp(F.scenario, sc{f}), :);
        V(f, 5, :) = [r.Vl_a_pu r.Vl_b_pu r.Vl_c_pu];
    end
end
end

function [V, vr, t, tOn, tOff] = simulate_all(root)
% One three-phase-to-ground fault at node 680 on each of the five models
tDev = 0.4; tOn = 0.8; tOff = 1.0; tStop = 1.15; vb = 480/sqrt(3); f0 = 60;
sw = sprintf('[%g %g]', tOn, tOff);
V = nan(1, 5, 3); out = cell(1, 5);
w = warning('off', 'all'); restore = onCleanup(@() warning(w));   % quiet solver messages
names = {'IEEE13_basecase', 'IEEE13_dg', 'IEEE13_dstatcom', 'IEEE13_dvr', 'IEEE13_full'};
for c = 1:5
    m = names{c};
    fprintf('Simulating model %d of 5: %s ...\n', c, m);
    load_system(fullfile(root, [m '.slx']));
    if c < 5
        set_param([m '/Fault 680'], 'FaultA', 'on', 'FaultB', 'on', 'FaultC', 'on', ...
            'GroundFault', 'on', 'SwitchTimes', sw);
        set_param([m '/NL Breaker'], 'SwitchTimes', '[100]');
    end
    switch c
        case 3
            set_param([m '/D-STATCOM/DST Mode'], 'Value', '2');
            set_param([m '/D-STATCOM/DST Enable'], 'Time', num2str(tDev));
            set_param([m '/D-STATCOM/DST Breaker'], 'SwitchTimes', sprintf('[%g]', tDev));
        case 4
            set_param([m '/DVR/DVR Enable'], 'Time', num2str(tDev));
    end
    if c == 5
        tl = struct('tNL', 100, 'tDev', tDev, 'tOn', tOn, 'tOff', tOff, 'tStop', tStop);
        out{c} = sim(full_input('ABC', 'on', tl, [1500; 1; 15; 5; 500; 850], [0.2; 200; 0.5]));
    else
        out{c} = sim(m, 'StopTime', num2str(tStop));
    end
    close_system(m, 0);
    r = pq_analyse(out{c}.get('log_V634'), tOn + 0.1, f0, vb);
    V(1, c, :) = r.pu;
end
ts = out{1}.get('log_V634'); t = ts.Time;
n = round(1/f0/(t(2) - t(1))); vr = zeros(numel(t), 5);
for c = 1:5
    x = squeeze(out{c}.get('log_V634').Data) / vb;
    vr(:, c) = min(sqrt(movmean(x.^2, [n-1 0], 1)), [], 2);
end
end

function s = verdict(v)
if all(v >= 0.9 & v <= 1.1), s = "yes"; else, s = "no"; end
end

function style(ax, ink)
grid(ax, 'on'); box(ax, 'off');
ax.GridColor = [0.85 0.85 0.85]; ax.GridAlpha = 1;
ax.XColor = ink; ax.YColor = ink; ax.FontSize = 10;
end
