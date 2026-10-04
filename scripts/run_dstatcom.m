function T = run_dstatcom()
% Runs the D-STATCOM scenarios on IEEE13_dstatcom.slx and writes
% results/dstatcom_summary.csv plus one figure per scenario.
% Run build_basecase and build_dstatcom first.

mdl  = 'IEEE13_dstatcom';
root = fileparts(fileparts(mfilename('fullpath')));
outd = fullfile(root, 'results');
if ~exist(outd, 'dir'), mkdir(outd); end
load_system(fullfile(root, [mdl '.slx']));

f0 = 60; vbase = 480/sqrt(3);
tNL = 0.3; tDst = 0.6; tOn = 0.8; tOff = 1.0;
% name, mode, non-linear load, fault phases A B C, ground, stop time,
% analysis windows (label, start time)
scen = {
    'compensation', 1, true,  '',    1.0, {'before', 0.5; 'dstatcom_on', 0.9}
    'fault_LLLG',   2, false, 'ABC', 1.2, {'before', 0.5; 'dstatcom_on', 0.7; 'during_fault', 0.9}
    'fault_LG_A',   2, false, 'A',   1.2, {'before', 0.5; 'dstatcom_on', 0.7; 'during_fault', 0.9}
    };

rows = {};
for s = 1:size(scen, 1)
    [name, mode, nl, fph, tStop, wins] = scen{s, :};
    set_param([mdl '/DST Mode'], 'Value', num2str(mode));
    set_param([mdl '/DST Enable'], 'Time', num2str(tDst));
    set_param([mdl '/DST Breaker'], 'SwitchTimes', sprintf('[%g]', tDst));
    set_param([mdl '/NL Breaker'], 'SwitchTimes', sprintf('[%g]', tern(nl, tNL, 100)));
    flt = [mdl '/Fault 680'];
    if isempty(fph)
        set_param(flt, 'SwitchTimes', '[100 100.1]');
    else
        set_param(flt, 'FaultA', onoff(any(fph == 'A')), 'FaultB', onoff(any(fph == 'B')), ...
            'FaultC', onoff(any(fph == 'C')), 'GroundFault', 'on', ...
            'SwitchTimes', sprintf('[%g %g]', tOn, tOff));
    end

    out = sim(mdl, 'StopTime', num2str(tStop));
    fprintf('%-13s simulated\n', name);

    dbg = out.get('log_dst'); vdc = squeeze(dbg.Data);
    if size(vdc, 1) == 8, vdc = vdc'; end
    vdc = vdc(:, 1); on = dbg.Time > tDst;
    for w = 1:size(wins, 1)
        t0 = wins{w, 2};
        v  = pq_analyse(out.get('log_V634'),  t0, f0, vbase);
        is = pq_analyse(out.get('log_Is634'), t0, f0, 1);
        ic = pq_analyse(out.get('log_Idst'),  t0, f0, 1);
        S  = sum(v.ph .* conj(is.ph));               % source-side complex power
        Sc = sum(v.ph .* conj(ic.ph));               % injected by the D-STATCOM
        rows(end+1, :) = {name, wins{w, 1}, v.pu(1), v.pu(2), v.pu(3), ...
            v.unb, max(v.thd), mean(abs(is.ph)), max(is.thd), is.unb, ...
            real(S)/1e3, imag(S)/1e3, real(S)/abs(S), ...
            mean(abs(ic.ph)), imag(Sc)/1e3, min(vdc(on)), max(vdc(on))}; %#ok<AGROW>
    end
    plot_scenario(out, name, vbase, f0, tDst, tOn, tOff, outd);
end

T = cell2table(rows, 'VariableNames', {'scenario', 'window', ...
    'Va_pu', 'Vb_pu', 'Vc_pu', 'Vunb_pct', 'THDv_max_pct', ...
    'Is_rms_A', 'THDi_max_pct', 'Iunb_pct', 'P_kW', 'Q_kvar', 'PF', ...
    'Idst_rms_A', 'Qdst_kvar', 'Vdc_min_V', 'Vdc_max_V'});
writetable(T, fullfile(outd, 'dstatcom_summary.csv'));
disp(T);
close_system(mdl, 0);
end

function plot_scenario(out, name, vbase, f0, tDst, tOn, tOff, outd)
col = [42 120 214; 235 104 52; 27 175 122] / 255;          % phases A, B, C
ink = [0.25 0.25 0.25];
lab = {'Phase A', 'Phase B', 'Phase C'};
is = out.get('log_Is634'); ic = out.get('log_Idst'); v = out.get('log_V634');
dbg = out.get('log_dst'); d = squeeze(dbg.Data); if size(d, 1) == 8, d = d'; end
t = is.Time;

fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 900 760]);
tl = tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

if strcmp(name, 'compensation')
    title(tl, 'D-STATCOM switched on at 0.6 s: rectifier and unbalanced load at node 634', ...
        'FontWeight', 'bold', 'Color', ink);
    win = t >= tDst - 0.05 & t <= tDst + 0.10;
    ax = nexttile; lines(ax, t(win), squeeze(is.Data(win, :)), col, 1, lab);
    ylabel(ax, 'Source current (A)'); style(ax, ink);
    ax = nexttile; lines(ax, t(win), squeeze(ic.Data(win, :)), col, 1, lab);
    ylabel(ax, 'D-STATCOM current (A)'); style(ax, ink);
else
    title(tl, sprintf('D-STATCOM in voltage regulation: %s at node 680', strrep(name, '_', ' ')), ...
        'FontWeight', 'bold', 'Color', ink);
    win = t >= tDst - 0.05 & t <= tOff + 0.12;
    n = round(1/f0/(t(2) - t(1)));
    x = squeeze(v.Data) / vbase;
    vr = sqrt(movmean(x.^2, [n-1 0], 1));                  % sliding one-cycle rms, pu
    ax = nexttile; lines(ax, t(win), vr(win, :), col, 2, lab);
    yline(ax, 0.9, ':', '0.9 pu sag limit', 'Color', ink, ...
        'LabelHorizontalAlignment', 'left', 'HandleVisibility', 'off');
    ylabel(ax, 'Node 634 RMS voltage (pu)'); ylim(ax, [0 1.25]); style(ax, ink);
    ax = nexttile; lines(ax, t(win), squeeze(ic.Data(win, :)), col, 1, lab);
    ylabel(ax, 'D-STATCOM current (A)'); style(ax, ink);
end
ax = nexttile; hold(ax, 'on');
plot(ax, dbg.Time(win), d(win, 1), 'Color', ink, 'LineWidth', 2);
ylabel(ax, 'DC-link voltage (V)'); xlabel(ax, 'Time (s)'); style(ax, ink);

exportgraphics(fig, fullfile(outd, ['dstatcom_' name '.png']), 'Resolution', 200);
close(fig);
end

function lines(ax, t, y, col, lw, lab)
hold(ax, 'on');
for k = 1:3, plot(ax, t, y(:, k), 'Color', col(k, :), 'LineWidth', lw); end
legend(ax, lab, 'Location', 'eastoutside', 'Box', 'off');
end

function style(ax, ink)
grid(ax, 'on'); box(ax, 'off');
ax.GridColor = [0.85 0.85 0.85]; ax.GridAlpha = 1;
ax.XColor = ink; ax.YColor = ink; ax.FontSize = 10;
end

function s = onoff(tf)
if tf, s = 'on'; else, s = 'off'; end
end

function y = tern(c, a, b)
if c, y = a; else, y = b; end
end
