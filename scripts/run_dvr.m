function T = run_dvr()
% Runs the DVR scenarios on IEEE13_dvr.slx and writes
% results/dvr_summary.csv plus one figure per scenario.
% Run build_basecase and build_dvr first.

mdl  = 'IEEE13_dvr';
root = fileparts(fileparts(mfilename('fullpath')));
outd = fullfile(root, 'results');
if ~exist(outd, 'dir'), mkdir(outd); end
load_system(fullfile(root, [mdl '.slx']));

f0 = 60; vbase = 480/sqrt(3);
tDvr = 0.6; tOn = 0.8; tOff = 1.0; tStop = 1.2;
% name, fault phases, ground
scen = {
    'fault_LLLG',   'ABC', 'on'
    'fault_LG_A',   'A',   'on'
    'fault_LL_BC',  'BC',  'off'
    'fault_LLG_BC', 'BC',  'on'
    };
wins = {'before', 0.5; 'dvr_on', 0.7; 'during_fault', 0.9};

set_param([mdl '/DVR Enable'], 'Time', num2str(tDvr));
set_param([mdl '/NL Breaker'], 'SwitchTimes', '[100]');
rows = {};
for s = 1:size(scen, 1)
    [name, fph, gnd] = scen{s, :};
    set_param([mdl '/Fault 680'], 'FaultA', onoff(any(fph == 'A')), ...
        'FaultB', onoff(any(fph == 'B')), 'FaultC', onoff(any(fph == 'C')), ...
        'GroundFault', gnd, 'SwitchTimes', sprintf('[%g %g]', tOn, tOff));

    out = sim(mdl, 'StopTime', num2str(tStop));
    fprintf('%-13s simulated\n', name);

    dbg = out.get('log_dvr'); d = squeeze(dbg.Data); if size(d, 1) == 8, d = d'; end
    td = dbg.Time; flt = td >= tOn & td <= tOff;
    eFault = (d(find(td >= tOff, 1), 2) - d(find(td >= tOn, 1), 2)) / 1e3;   % kJ
    for w = 1:size(wins, 1)
        t0 = wins{w, 2};
        vs = pq_analyse(out.get('log_Vs634'), t0, f0, vbase);
        vl = pq_analyse(out.get('log_V634'),  t0, f0, vbase);
        vi = pq_analyse(out.get('log_Vinj'),  t0, f0, vbase);
        inw = td >= t0 & td < t0 + 3/f0;
        rows(end+1, :) = {name, wins{w, 1}, vs.pu(1), vs.pu(2), vs.pu(3), ...
            vl.pu(1), vl.pu(2), vl.pu(3), vl.unb, max(vl.thd), ...
            vi.pu(1), vi.pu(2), vi.pu(3), mean(d(inw, 1))/1e3, ...
            max(d(flt, 1))/1e3, eFault}; %#ok<AGROW>
    end
    plot_scenario(out, name, vbase, tOn, tOff, outd);
end

T = cell2table(rows, 'VariableNames', {'scenario', 'window', ...
    'Vs_a_pu', 'Vs_b_pu', 'Vs_c_pu', 'Vl_a_pu', 'Vl_b_pu', 'Vl_c_pu', ...
    'Vl_unb_pct', 'Vl_THD_max_pct', 'Vinj_a_pu', 'Vinj_b_pu', 'Vinj_c_pu', ...
    'Pinj_mean_kW', 'Pinj_peak_fault_kW', 'Einj_fault_kJ'});
writetable(T, fullfile(outd, 'dvr_summary.csv'));
disp(T);
close_system(mdl, 0);
end

function plot_scenario(out, name, vbase, tOn, tOff, outd)
col = [42 120 214; 235 104 52; 27 175 122] / 255;          % phases A, B, C
ink = [0.25 0.25 0.25];
sig = {'log_Vs634', 'log_Vinj', 'log_V634'};
lab = {'Supply voltage (pu)', 'Injected voltage (pu)', 'Load voltage (pu)'};

fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 900 760]);
tl = tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, sprintf('DVR at node 634: %s at node 680', strrep(name, '_', ' ')), ...
    'FontWeight', 'bold', 'Color', ink);
for k = 1:3
    ts = out.get(sig{k}); t = ts.Time;
    win = t >= tOn - 0.05 & t <= tOff + 0.07;
    y = squeeze(ts.Data) / (vbase*sqrt(2));
    if size(y, 1) ~= numel(t), y = y.'; end
    ax = nexttile; hold(ax, 'on');
    for p = 1:3, plot(ax, t(win), y(win, p), 'Color', col(p, :), 'LineWidth', 1); end
    ylabel(ax, lab{k}); ylim(ax, [-1.5 1.5]);
    grid(ax, 'on'); box(ax, 'off');
    ax.GridColor = [0.85 0.85 0.85]; ax.GridAlpha = 1;
    ax.XColor = ink; ax.YColor = ink; ax.FontSize = 10;
    legend(ax, {'Phase A', 'Phase B', 'Phase C'}, 'Location', 'eastoutside', 'Box', 'off');
end
xlabel(ax, 'Time (s)');
exportgraphics(fig, fullfile(outd, ['dvr_' name '.png']), 'Resolution', 200);
close(fig);
end

function s = onoff(tf)
if tf, s = 'on'; else, s = 'off'; end
end
