function build_demo()
% Builds IEEE13_demo.slx: a copy of the combined model (IEEE13_full.slx)
% prepared for a live demonstration in Simulink. A single line-to-ground
% fault is already set up and three Scope blocks open when Run is pressed:
%   RMS voltages  supply and load RMS voltage per phase: the sag and the
%                 swell on the supply, a flat line at the load
%   Voltages      supply voltage, voltage injected by the DVR, load voltage
%   Currents      source current, load current, D-STATCOM current
% Timeline: PV and wind connect at 0.2 s, rectifier load at 0.3 s, DVR and
% D-STATCOM at 0.4 s, fault at node 680 from 0.6 s to 0.8 s, stop at 1.0 s.

src = 'IEEE13_full';
dst = 'IEEE13_demo';
root = fileparts(fileparts(mfilename('fullpath')));

if bdIsLoaded(dst), close_system(dst, 0); end
if bdIsLoaded(src), close_system(src, 0); end
load_system(fullfile(root, [src '.slx']));
save_system(src, fullfile(root, [dst '.slx']));   % loaded model is now dst

%% Scenario
set_param([dst '/Fault 680'], 'FaultA', 'on', 'FaultB', 'off', 'FaultC', 'off', ...
    'GroundFault', 'on', 'SwitchTimes', '[0.6 0.8]');
set_param([dst '/NL Breaker'], 'SwitchTimes', '[0.3]');
set_param([dst '/D-STATCOM/DST Breaker'], 'SwitchTimes', '[0.4]');
set_param([dst '/D-STATCOM/DST Enable'], 'Time', '0.4');
set_param([dst '/D-STATCOM/DST Mode'], 'Value', '1');
set_param([dst '/DVR/DVR Enable'], 'Time', '0.4');
set_param(dst, 'StopTime', '1.0');

%% Scopes
x0 = 2400; y0 = 250; vpk = '480*sqrt(2/3)';
ph = get_param([dst '/Log DVR vinj'], 'PortHandles');
vinj = get_param(get_param(ph.Inport(1), 'Line'), 'SrcPortHandle');

sc = [dst '/Voltages'];
add_block('simulink/Sinks/Scope', sc, 'Position', [x0+220 y0 x0+270 y0+110], 'NumInputPorts', '3');
tags = {'XFXFM1', '', 'V634'};
for k = 1:3
    y = y0 + 8 + 36*(k-1);
    g = sprintf('%s/Demo pu %d', dst, k);
    add_block('simulink/Math Operations/Gain', g, 'Position', [x0+120 y x0+160 y+24], ...
        'Gain', ['1/(' vpk ')']);
    if isempty(tags{k})
        gp = get_param(g, 'PortHandles');
        add_line(dst, vinj, gp.Inport(1), 'autorouting', 'on');
    else
        f = sprintf('%s/Demo From %s', dst, tags{k});
        add_block('simulink/Signal Routing/From', f, 'Position', [x0 y x0+70 y+24], 'GotoTag', tags{k});
        add_line(dst, sprintf('Demo From %s/1', tags{k}), sprintf('Demo pu %d/1', k));
    end
    add_line(dst, sprintf('Demo pu %d/1', k), sprintf('Voltages/%d', k));
end
scope_setup(sc, {'Supply voltage (pu)', 'Voltage injected by the DVR (pu)', 'Load voltage (pu)'}, ...
    [-1.5 1.5], [40 60 760 820], '0.5');

sc = [dst '/Currents'];
add_block('simulink/Sinks/Scope', sc, 'Position', [x0+220 y0+160 x0+270 y0+270], 'NumInputPorts', '3');
tags = {'Is634', 'I634', 'Idst'};
for k = 1:3
    y = y0 + 168 + 36*(k-1);
    f = sprintf('%s/Demo From %s', dst, tags{k});
    add_block('simulink/Signal Routing/From', f, 'Position', [x0 y x0+70 y+24], 'GotoTag', tags{k});
    add_line(dst, sprintf('Demo From %s/1', tags{k}), sprintf('Currents/%d', k), 'autorouting', 'on');
end
scope_setup(sc, {'Source current (A)', 'Load current (A)', 'D-STATCOM current (A)'}, ...
    [-1500 1500], [820 60 760 820], '0.5');

%% RMS voltages: one-cycle rms of each phase, per unit
rms = [dst '/Demo RMS'];
add_block('simulink/User-Defined Functions/MATLAB Function', rms, ...
    'Position', [x0+90 y0+330 x0+190 y0+400]);
chart = find(sfroot, '-isa', 'Stateflow.EMChart', 'Path', rms);
chart.Script = strjoin({
    'function [supply, load] = demo_rms(vs, vl)'
    '% One-cycle rms of each phase of the supply and load voltage, per unit'
    '%#codegen'
    'N = 333; vb = 480/sqrt(3);'
    'persistent buf acc idx'
    'if isempty(buf), buf = zeros(N, 6); acc = zeros(1, 6); idx = 1; end'
    'x = [vs(:); vl(:)]''.^2;'
    'acc = acc + x - buf(idx, :); buf(idx, :) = x; idx = mod(idx, N) + 1;'
    'r = sqrt(max(acc, 0)/N) / vb;'
    'supply = r(1:3)''; load = r(4:6)'';'
    'end'}, newline);
chart.ChartUpdate = 'DISCRETE';
chart.SampleTime = '50e-6';
tags = {'XFXFM1', 'V634'};
for k = 1:2
    f = sprintf('%s/Demo RMS From %s', dst, tags{k});
    add_block('simulink/Signal Routing/From', f, ...
        'Position', [x0 y0+335+30*(k-1) x0+70 y0+355+30*(k-1)], 'GotoTag', tags{k});
    add_line(dst, sprintf('Demo RMS From %s/1', tags{k}), sprintf('Demo RMS/%d', k), 'autorouting', 'on');
end
sc = [dst '/RMS voltages'];
add_block('simulink/Sinks/Scope', sc, 'Position', [x0+220 y0+320 x0+270 y0+410], 'NumInputPorts', '2');
add_line(dst, 'Demo RMS/1', 'RMS voltages/1', 'autorouting', 'on');
add_line(dst, 'Demo RMS/2', 'RMS voltages/2', 'autorouting', 'on');
scope_setup(sc, {'Supply RMS voltage per phase (pu)', 'Load RMS voltage per phase (pu)'}, ...
    [0 1.3], [300 120 900 640], '1');

save_system(dst);
close_system(dst, 0);
fprintf('Built %s\n', fullfile(root, [dst '.slx']));
end

function scope_setup(blk, titles, ylim, pos, span)
% span is the time shown, in seconds. The waveform scopes show 0.5 s at a
% time and wrap, so the fault fills the second screen (0.5 s to 1.0 s).
c = get_param(blk, 'ScopeConfiguration');
n = numel(titles);
c.LayoutDimensions = [n 1];
c.OpenAtSimulationStart = true;
c.TimeSpan = span;
c.TimeSpanOverrunAction = 'Wrap';
c.Position = pos;
for k = 1:n
    c.ActiveDisplay = k;
    c.Title = titles{k};
    c.YLimits = ylim;
    c.ShowGrid = true;
end
end
