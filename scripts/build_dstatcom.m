function build_dstatcom()
% Builds IEEE13_dstatcom.slx from IEEE13_basecase.slx.
% Adds a D-STATCOM (averaged voltage source converter with coupling filter)
% between the transformer and node 634, its controller, and logging.
% Run build_basecase first.

src = 'IEEE13_basecase';
dst = 'IEEE13_dstatcom';
here = fileparts(mfilename('fullpath'));
root = fileparts(here);

if bdIsLoaded(dst), close_system(dst, 0); end
if bdIsLoaded(src), close_system(src, 0); end
load_system(fullfile(root, [src '.slx']));
save_system(src, fullfile(root, [dst '.slx']));   % loaded model is now dst

libs = {'spsControlledVoltageSourceLib', 'spsThreePhaseSeriesRLCBranchLib', ...
    'spsThreePhaseVIMeasurementLib', 'spsThreePhaseBreakerLib', ...
    'spsSeriesRLCBranchLib', 'spsGroundLib'};
for k = 1:numel(libs), load_system(libs{k}); end

x0 = 1500; y0 = 640;      % top-left of the D-STATCOM area, above node 634

%% Source-side current: measured by the existing block after the transformer
set_param([dst '/XFXFM1'], 'CurrentMeasurement', 'yes', ...
    'SetLabelI', 'on', 'LabelI', 'Is634');

%% Power circuit: sources -> filter -> current measurement -> breaker -> node
flt = [dst '/DST Filter'];
mea = [dst '/DST Current'];
brk = [dst '/DST Breaker'];
add_block('spsThreePhaseSeriesRLCBranchLib/Three-Phase Series RLC Branch', flt, ...
    'Position', [x0+330 y0 x0+390 y0+70], ...
    'BranchType', 'RL', 'Resistance', '5e-3', 'Inductance', '0.2e-3');
add_block('spsThreePhaseVIMeasurementLib/Three-Phase V-I Measurement', mea, ...
    'Position', [x0+440 y0 x0+465 y0+70], ...
    'VoltageMeasurement', 'no', 'CurrentMeasurement', 'yes', ...
    'SetLabelI', 'on', 'LabelI', 'Idst');
add_block('spsThreePhaseBreakerLib/Three-Phase Breaker', brk, ...
    'Position', [x0+520 y0 x0+575 y0+70], ...
    'InitialState', 'open', 'SwitchA', 'on', 'SwitchB', 'on', 'SwitchC', 'on', ...
    'SwitchTimes', '[100]');
add_block('spsSeriesRLCBranchLib/Series RLC Branch', [dst '/DST Neutral R'], ...
    'Position', [x0+120 y0+150 x0+170 y0+180], ...
    'BranchType', 'R', 'Resistance', '1e6');
add_block('spsGroundLib/Ground', [dst '/DST Ground'], ...
    'Position', [x0+60 y0+185 x0+85 y0+210]);

pflt = get_param(flt, 'PortHandles');
pmea = get_param(mea, 'PortHandles');
pbrk = get_param(brk, 'PortHandles');
p634 = get_param([dst '/634'], 'PortHandles');
pnr  = get_param([dst '/DST Neutral R'], 'PortHandles');
pgnd = get_param([dst '/DST Ground'], 'PortHandles');
ph = 'ABC';
for k = 1:3
    cvs = sprintf('%s/DST Source %s', dst, ph(k));
    y = y0 - 10 + 35*(k-1);
    add_block('spsControlledVoltageSourceLib/Controlled Voltage Source', cvs, ...
        'Position', [x0+220 y x0+250 y+25], 'Initialize', 'off');
    pc = get_param(cvs, 'PortHandles');
    add_line(dst, pc.RConn(1), pflt.LConn(k), 'autorouting', 'on');   % + terminal
    add_line(dst, pc.LConn(1), pnr.RConn(1), 'autorouting', 'on');    % - to neutral
    add_line(dst, pflt.RConn(k), pmea.LConn(k), 'autorouting', 'on');
    add_line(dst, pmea.RConn(k), pbrk.LConn(k), 'autorouting', 'on');
    add_line(dst, pbrk.RConn(k), p634.LConn(k), 'autorouting', 'on');
end
add_line(dst, pnr.LConn(1), pgnd.LConn(1), 'autorouting', 'on');

%% Controller
ctl = [dst '/DST Controller'];
add_block('simulink/User-Defined Functions/MATLAB Function', ctl, ...
    'Position', [x0-150 y0-20 x0+10 y0+110]);
chart = find(sfroot, '-isa', 'Stateflow.EMChart', 'Path', ctl);
chart.Script = fileread(fullfile(here, 'dstatcom_controller.m'));
chart.ChartUpdate = 'DISCRETE';
chart.SampleTime = '50e-6';

tags = {'V634', 'I634', 'Idst'};
for k = 1:3
    y = y0 - 15 + 26*(k-1);
    frm = sprintf('%s/DST From %s', dst, tags{k});
    add_block('simulink/Signal Routing/From', frm, ...
        'Position', [x0-260 y x0-200 y+18], 'GotoTag', tags{k});
    add_line(dst, sprintf('DST From %s/1', tags{k}), sprintf('DST Controller/%d', k), ...
        'autorouting', 'on');
end
add_block('simulink/Sources/Step', [dst '/DST Enable'], ...
    'Position', [x0-260 y0+65 x0-230 y0+85], ...
    'Time', '100', 'Before', '0', 'After', '1', 'SampleTime', '50e-6');
add_block('simulink/Sources/Constant', [dst '/DST Mode'], ...
    'Position', [x0-260 y0+95 x0-230 y0+115], 'Value', '1', 'SampleTime', '50e-6');
add_line(dst, 'DST Enable/1', 'DST Controller/4', 'autorouting', 'on');
add_line(dst, 'DST Mode/1', 'DST Controller/5', 'autorouting', 'on');

% One-sample delay breaks the algebraic loop between network and controller
add_block('simulink/Discrete/Unit Delay', [dst '/DST Delay'], ...
    'Position', [x0+50 y0+5 x0+80 y0+35], 'InitialCondition', '0');
add_block('simulink/Signal Routing/Demux', [dst '/DST Demux'], ...
    'Position', [x0+120 y0-10 x0+125 y0+60], 'Outputs', '3');
add_line(dst, 'DST Controller/1', 'DST Delay/1', 'autorouting', 'on');
add_line(dst, 'DST Delay/1', 'DST Demux/1', 'autorouting', 'on');
for k = 1:3
    add_line(dst, sprintf('DST Demux/%d', k), sprintf('DST Source %s/1', ph(k)), ...
        'autorouting', 'on');
end

%% Logging
add_block('simulink/Sinks/To Workspace', [dst '/Log DST dbg'], ...
    'Position', [x0+50 y0+75 x0+130 y0+99], 'VariableName', 'log_dst', ...
    'SaveFormat', 'Timeseries', 'MaxDataPoints', 'inf', 'SampleTime', '-1');
add_line(dst, 'DST Controller/2', 'Log DST dbg/1', 'autorouting', 'on');
tags = {'Is634', 'Idst'};
for k = 1:numel(tags)
    y = 300 + 60*(k+3);
    frm = sprintf('%s/Log From %s', dst, tags{k});
    tow = sprintf('%s/Log %s', dst, tags{k});
    add_block('simulink/Signal Routing/From', frm, ...
        'Position', [2000 y 2060 y+24], 'GotoTag', tags{k});
    add_block('simulink/Sinks/To Workspace', tow, ...
        'Position', [2120 y 2200 y+24], 'VariableName', ['log_' tags{k}], ...
        'SaveFormat', 'Timeseries', 'MaxDataPoints', 'inf', 'SampleTime', '-1');
    add_line(dst, sprintf('Log From %s/1', tags{k}), sprintf('Log %s/1', tags{k}));
end

group_blocks(dst, 'DST', 'D-STATCOM');

save_system(dst);
close_system(dst, 0);
fprintf('Built %s\n', fullfile(root, [dst '.slx']));
end
