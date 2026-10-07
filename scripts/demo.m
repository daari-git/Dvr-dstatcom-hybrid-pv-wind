function demo(fault, model)
% Live demonstration: simulates one fault without and with compensation and
% shows the result in a figure window.
%   fault  'LLLG' three-phase-to-ground, 'LG' single line-to-ground (default),
%          'LL' line-to-line, 'LLG' double line-to-ground
%   model  'dvr' (default) the DVR alone, or 'full' the DVR, D-STATCOM, PV
%          and wind together
% Examples:  demo            demo('LLLG')            demo('LG', 'full')
% Takes about one minute. It does not change any model or result file.

if nargin < 1, fault = 'LG'; end
if nargin < 2, model = 'dvr'; end
root = fileparts(fileparts(mfilename('fullpath')));
types = struct('LLLG', {{'ABC', 'on'}}, 'LG', {{'A', 'on'}}, 'LL', {{'BC', 'off'}}, 'LLG', {{'BC', 'on'}});
names = struct('LLLG', 'three-phase-to-ground', 'LG', 'single line-to-ground', ...
    'LL', 'line-to-line', 'LLG', 'double line-to-ground');
ph = types.(fault){1}; gnd = types.(fault){2};
tOn = 0.6; tOff = 0.8; tStop = 1.0; tDev = 0.4;
oo = @(c) char(string(any(ph == c)).replace("true", "on").replace("false", "off"));

% Without compensation
fprintf('Simulating the %s fault without compensation ...\n', names.(fault));
m0 = 'IEEE13_basecase'; load_system(fullfile(root, [m0 '.slx']));
set_fault(m0, oo, gnd, tOn, tOff);
set_param([m0 '/NL Breaker'], 'SwitchTimes', '[100]');
out0 = sim(m0, 'StopTime', num2str(tStop));
close_system(m0, 0);

% With compensation
if strcmp(model, 'full')
    fprintf('Simulating it with the DVR, D-STATCOM, PV and wind ...\n');
    tl = struct('tNL', 100, 'tDev', tDev, 'tOn', tOn, 'tOff', tOff, 'tStop', tStop);
    load_system(fullfile(root, 'IEEE13_full.slx'));
    out1 = sim(full_input(ph, gnd, tl, [1500; 1; 15; 5; 500; 850], [0.2; 200; 0.5]));
    close_system('IEEE13_full', 0);
    what = 'DVR, D-STATCOM, PV and wind';
else
    fprintf('Simulating it with the DVR ...\n');
    m1 = 'IEEE13_dvr'; load_system(fullfile(root, [m1 '.slx']));
    set_fault(m1, oo, gnd, tOn, tOff);
    set_param([m1 '/NL Breaker'], 'SwitchTimes', '[100]');
    set_param([m1 '/DVR/DVR Enable'], 'Time', num2str(tDev));
    out1 = sim(m1, 'StopTime', num2str(tStop));
    close_system(m1, 0);
    what = 'DVR';
end

% Figure: load voltage without, injected voltage, load voltage with
col = [42 120 214; 235 104 52; 27 175 122] / 255; ink = [0.25 0.25 0.25];
vb = 480/sqrt(3)*sqrt(2);
sig = {out0.get('log_V634'), out1.get('log_Vinj'), out1.get('log_V634')};
lab = {'Load voltage, no compensation (pu)', 'Voltage injected by the DVR (pu)', ...
    sprintf('Load voltage with the %s (pu)', what)};
fig = figure('Color', 'w', 'Name', 'Demonstration', 'NumberTitle', 'off', ...
    'Position', [80 60 1000 780]);
tlo = tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tlo, sprintf('Node 634, %s fault at node 680 from %.1f s to %.1f s', ...
    names.(fault), tOn, tOff), 'FontWeight', 'bold', 'Color', ink);
for k = 1:3
    t = sig{k}.Time; y = squeeze(sig{k}.Data) / vb;
    if size(y, 1) ~= numel(t), y = y.'; end
    w = t >= tOn - 0.05 & t <= tOff + 0.07;
    ax = nexttile; hold(ax, 'on');
    for p = 1:3, plot(ax, t(w), y(w, p), 'Color', col(p, :), 'LineWidth', 1); end
    ylabel(ax, lab{k}); ylim(ax, [-1.5 1.5]);
    grid(ax, 'on'); box(ax, 'off'); ax.GridColor = [0.85 0.85 0.85]; ax.GridAlpha = 1;
    ax.XColor = ink; ax.YColor = ink;
    legend(ax, {'Phase A', 'Phase B', 'Phase C'}, 'Location', 'eastoutside', 'Box', 'off');
end
xlabel(ax, 'Time (s)');

% Numbers to read out
a = pq_analyse(out0.get('log_V634'), tOn + 0.1, 60, 480/sqrt(3));
b = pq_analyse(out1.get('log_V634'), tOn + 0.1, 60, 480/sqrt(3));
fprintf('\nLoad voltage during the fault, phases A / B / C (pu)\n');
fprintf('  without compensation: %.3f / %.3f / %.3f\n', a.pu);
fprintf('  with the %s: %.3f / %.3f / %.3f\n', what, b.pu);
end

function set_fault(m, oo, gnd, tOn, tOff)
set_param([m '/Fault 680'], 'FaultA', oo('A'), 'FaultB', oo('B'), 'FaultC', oo('C'), ...
    'GroundFault', gnd, 'SwitchTimes', sprintf('[%g %g]', tOn, tOff));
end
