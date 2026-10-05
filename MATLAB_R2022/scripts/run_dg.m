function T = run_dg()
% Runs the DG scenarios on IEEE13_dg.slx (PV and wind, no compensation) and
% writes results/dg_summary.csv plus one figure per scenario.
% Run build_basecase and build_dg first.

mdl  = 'IEEE13_dg';
root = fileparts(fileparts(mfilename('fullpath')));
outd = fullfile(root, 'results');
if ~exist(outd, 'dir'), mkdir(outd); end
load_system(fullfile(root, [mdl '.slx']));

f0 = 60; vb634 = 480/sqrt(3); vb675 = 4160/sqrt(3);
tOn = 1.0; tOff = 1.2;
% name, fault phases, irradiance profile, wind profile, stop time, windows
flat = {'[0 100]', '[1000 1000]', '[12 12]'};
scen = {
    'variation',  '',    '[0 1.0 1.1 100]', '[1000 1000 300 300]', '[12 12 9 9]', 1.8, ...
        {'dg_full', 0.9; 'dg_reduced', 1.7}
    'fault_LLLG', 'ABC', flat{:}, 1.5, {'before', 0.9; 'during_fault', 1.1; 'after', 1.4}
    'fault_LG_A', 'A',   flat{:}, 1.5, {'before', 0.9; 'during_fault', 1.1; 'after', 1.4}
    };

set_param([mdl '/NL Breaker'], 'SwitchTimes', '[100]');
rows = {};
for s = 1:size(scen, 1)
    [name, fph, bp, g, v, tStop, wins] = scen{s, :};
    set_param([mdl '/PV Plant/PV Resource'], 'BreakpointsForDimension1', bp, 'Table', g);
    set_param([mdl '/Wind Plant/Wind Resource'], 'BreakpointsForDimension1', bp, 'Table', v);
    flt = [mdl '/Fault 680'];
    if isempty(fph)
        set_param(flt, 'SwitchTimes', '[100 100.1]');
    else
        set_param(flt, 'FaultA', onoff(any(fph == 'A')), 'FaultB', onoff(any(fph == 'B')), ...
            'FaultC', onoff(any(fph == 'C')), 'GroundFault', 'on', ...
            'SwitchTimes', sprintf('[%g %g]', tOn, tOff));
    end

    out = sim(mdl, 'StopTime', num2str(tStop));
    fprintf('%-11s simulated\n', name);

    [tp, pv] = dbgdata(out.get('log_pv'));
    [~, wd]  = dbgdata(out.get('log_wind'));
    for w = 1:size(wins, 1)
        t0 = wins{w, 2};
        a = pq_analyse(out.get('log_V634'), t0, f0, vb634);
        b = pq_analyse(out.get('log_V675'), t0, f0, vb675);
        k = tp >= t0 & tp < t0 + 3/f0;
        rows(end+1, :) = {name, wins{w, 1}, a.pu(1), a.pu(2), a.pu(3), ...
            b.pu(1), b.pu(2), b.pu(3), ...
            mean(pv(k, 2)), mean(pv(k, 3)), max(pv(k, 8)), ...
            mean(wd(k, 2)), mean(wd(k, 3)), max(wd(k, 8)), ...
            max(pv(:, 4)), max(wd(:, 4))}; %#ok<AGROW>
    end
    plot_scenario(out, name, vb634, vb675, f0, tStop, outd);
end

T = cell2table(rows, 'VariableNames', {'scenario', 'window', ...
    'V634_a_pu', 'V634_b_pu', 'V634_c_pu', 'V675_a_pu', 'V675_b_pu', 'V675_c_pu', ...
    'Ppv_kW', 'Qpv_kvar', 'PV_ceased', 'Pwind_kW', 'Qwind_kvar', 'Wind_ceased', ...
    'Vdc_pv_max_V', 'Vdc_wind_max_V'});
writetable(T, fullfile(outd, 'dg_summary.csv'));
disp(T);
close_system(mdl, 0);
end

function [t, x] = dbgdata(ts)
t = ts.Time; x = squeeze(ts.Data);
if size(x, 1) ~= numel(t), x = x.'; end
end

function plot_scenario(out, name, vb634, vb675, f0, tStop, outd)
col = [42 120 214; 235 104 52; 27 175 122] / 255;          % phases A, B, C
cpl = [237 161 0; 74 58 167] / 255;                        % PV, wind
ink = [0.25 0.25 0.25];
[tp, pv] = dbgdata(out.get('log_pv'));
[~, wd]  = dbgdata(out.get('log_wind'));
win = tp >= 0.7 & tp <= tStop;

fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 900 760]);
tl = tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, sprintf('PV and wind plants, no compensation: %s', strrep(name, '_', ' ')), ...
    'FontWeight', 'bold', 'Color', ink);

ax = nexttile; hold(ax, 'on');
plot(ax, tp(win), pv(win, 2), 'Color', cpl(1, :), 'LineWidth', 2);
plot(ax, tp(win), wd(win, 2), 'Color', cpl(2, :), 'LineWidth', 2);
ylabel(ax, 'Active power (kW)'); style(ax, ink);
legend(ax, {'PV plant', 'Wind plant'}, 'Location', 'eastoutside', 'Box', 'off');

sig = {'log_V634', 'log_V675'}; vb = [vb634 vb675];
lab = {'Node 634 RMS voltage (pu)', 'Node 675 RMS voltage (pu)'};
for k = 1:2
    ts = out.get(sig{k}); t = ts.Time;
    n = round(1/f0/(t(2) - t(1)));
    vr = sqrt(movmean((squeeze(ts.Data)/vb(k)).^2, [n-1 0], 1));   % sliding rms, pu
    w = t >= 0.7 & t <= tStop;
    ax = nexttile; hold(ax, 'on');
    for p = 1:3, plot(ax, t(w), vr(w, p), 'Color', col(p, :), 'LineWidth', 2); end
    ylabel(ax, lab{k}); style(ax, ink);
    if ~strcmp(name, 'variation'), ylim(ax, [0 1.3]); end
    legend(ax, {'Phase A', 'Phase B', 'Phase C'}, 'Location', 'eastoutside', 'Box', 'off');
end
xlabel(ax, 'Time (s)');
exportgraphics(fig, fullfile(outd, ['dg_' name '.png']), 'Resolution', 200);
close(fig);
end

function style(ax, ink)
grid(ax, 'on'); box(ax, 'off');
ax.GridColor = [0.85 0.85 0.85]; ax.GridAlpha = 1;
ax.XColor = ink; ax.YColor = ink; ax.FontSize = 10;
end

function s = onoff(tf)
if tf, s = 'on'; else, s = 'off'; end
end
