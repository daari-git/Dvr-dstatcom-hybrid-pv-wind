function T = run_basecase()
% Runs the uncompensated base-case scenarios on IEEE13_basecase.slx and
% writes results/basecase_summary.csv plus one figure per scenario.
% Run build_basecase first.

mdl  = 'IEEE13_basecase';
root = fileparts(fileparts(mfilename('fullpath')));
outd = fullfile(root, 'results');
if ~exist(outd, 'dir'), mkdir(outd); end
load_system(fullfile(root, [mdl '.slx']));

tOn = 0.8; tOff = 1.0; tStop = 1.3;      % disturbance window, s
f0 = 60;
% name, phases A B C, ground, fault active, non-linear load active
scen = {
    'normal',         'on',  'on',  'on',  'on',  false, false
    'fault_LLLG',     'on',  'on',  'on',  'on',  true,  false
    'fault_LG_A',     'on',  'off', 'off', 'on',  true,  false
    'fault_LL_BC',    'off', 'on',  'on',  'off', true,  false
    'fault_LLG_BC',   'off', 'on',  'on',  'on',  true,  false
    'nonlinear_load', 'on',  'on',  'on',  'on',  false, true
    };
bus   = {'V634', 'V632', 'V671'};
vbase = [480/sqrt(3), 4160/sqrt(3), 4160/sqrt(3)];   % phase-to-ground rms

rows = {};
for s = 1:size(scen, 1)
    name = scen{s, 1};
    flt = [mdl '/Fault 680'];
    set_param(flt, 'FaultA', scen{s, 2}, 'FaultB', scen{s, 3}, ...
        'FaultC', scen{s, 4}, 'GroundFault', scen{s, 5});
    if scen{s, 6}
        set_param(flt, 'SwitchTimes', sprintf('[%g %g]', tOn, tOff));
    else
        set_param(flt, 'SwitchTimes', '[100 100.1]');
    end
    if scen{s, 7}
        set_param([mdl '/NL Breaker'], 'SwitchTimes', sprintf('[%g]', tOn));
    else
        set_param([mdl '/NL Breaker'], 'SwitchTimes', '[100]');
    end

    out = sim(mdl, 'StopTime', num2str(tStop));
    fprintf('%-15s simulated\n', name);

    for b = 1:numel(bus)
        ts  = out.get(['log_' bus{b}]);
        pre = analyse(ts, tOn - 0.10, f0, vbase(b));
        dur = analyse(ts, tOn + 0.10, f0, vbase(b));
        rows(end+1, :) = {name, bus{b}(2:end), ...
            pre.vpu(1), pre.vpu(2), pre.vpu(3), ...
            dur.vpu(1), dur.vpu(2), dur.vpu(3), ...
            min(dur.vpu), max(dur.vpu), dur.vuf, max(dur.thd), NaN}; %#ok<AGROW>
    end
    i634 = analyse(out.get('log_I634'), tOn + 0.10, f0, 1);
    rows{end-2, 13} = max(i634.thd);          % current THD belongs to bus 634

    plot_scenario(out.get('log_V634'), vbase(1), f0, tOn, tOff, name, outd);
end

T = cell2table(rows, 'VariableNames', {'scenario', 'bus', ...
    'pre_Va_pu', 'pre_Vb_pu', 'pre_Vc_pu', 'Va_pu', 'Vb_pu', 'Vc_pu', ...
    'Vmin_pu', 'Vmax_pu', 'VUF_pct', 'THDv_max_pct', 'THDi_max_pct'});
writetable(T, fullfile(outd, 'basecase_summary.csv'));
disp(T);
close_system(mdl, 0);
end

function r = analyse(ts, t0, f0, vbase)
% Fundamental phasors, unbalance and THD over three cycles starting at t0.
t = ts.Time; x = squeeze(ts.Data);
Ts = t(2) - t(1);
n  = round(3/f0/Ts);                       % three cycles: integer sample count
i0 = find(t >= t0, 1);
X  = fft(x(i0:i0+n-1, :)) / n * 2;         % peak amplitude per bin
k1 = 3 + 1;                                % fundamental bin (three cycles)
ph = X(k1, :) / sqrt(2);                   % rms phasors
h  = 2:50;
r.vpu = abs(ph) / vbase;
r.thd = 100 * sqrt(sum(abs(X(3*h + 1, :)).^2, 1)) ./ abs(X(k1, :));
a  = exp(1j*2*pi/3);
v1 = (ph(1) + a*ph(2) + a^2*ph(3)) / 3;
v2 = (ph(1) + a^2*ph(2) + a*ph(3)) / 3;
r.vuf = 100 * abs(v2) / abs(v1);
end

function plot_scenario(ts, vbase, f0, tOn, tOff, name, outd)
t = ts.Time; v = squeeze(ts.Data) / (vbase*sqrt(2));       % pu of peak
Ts = t(2) - t(1);
n  = round(1/f0/Ts);
vr = sqrt(2 * movmean(v.^2, [n-1 0], 1));                  % sliding one-cycle rms, pu
col = [42 120 214; 235 104 52; 27 175 122] / 255;          % phases A, B, C
ink = [0.25 0.25 0.25];
if contains(name, 'nonlinear')
    win = t >= tOn - 0.03 & t <= tOn + 0.07;               % few cycles: show distortion
else
    win = t >= tOn - 0.08 & t <= tOff + 0.12;
end

fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 900 560]);
tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, sprintf('Node 634 voltage, no compensation: %s', strrep(name, '_', ' ')), ...
    'FontWeight', 'bold', 'Color', ink);

ax = nexttile; hold(ax, 'on');
for k = 1:3, plot(ax, t(win), v(win, k), 'Color', col(k, :), 'LineWidth', 1); end
ylabel(ax, 'Voltage (pu of peak)'); style(ax, ink);
legend(ax, {'Phase A', 'Phase B', 'Phase C'}, 'Location', 'eastoutside', 'Box', 'off');

ax = nexttile; hold(ax, 'on');
for k = 1:3, plot(ax, t(win), vr(win, k), 'Color', col(k, :), 'LineWidth', 2); end
yline(ax, 0.9, ':', '0.9 pu sag limit', 'Color', ink, 'LabelHorizontalAlignment', 'left');
ylabel(ax, 'RMS voltage (pu)'); xlabel(ax, 'Time (s)'); style(ax, ink);
ylim(ax, [0 max(1.2, 1.05*max(vr(win, :), [], 'all'))]);
legend(ax, {'Phase A', 'Phase B', 'Phase C'}, 'Location', 'eastoutside', 'Box', 'off');

exportgraphics(fig, fullfile(outd, ['basecase_' name '.png']), 'Resolution', 200);
close(fig);
end

function style(ax, ink)
grid(ax, 'on'); box(ax, 'off');
ax.GridColor = [0.85 0.85 0.85]; ax.GridAlpha = 1;
ax.XColor = ink; ax.YColor = ink; ax.FontSize = 10;
end
