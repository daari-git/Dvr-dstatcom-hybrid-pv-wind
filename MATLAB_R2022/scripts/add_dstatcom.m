function add_dstatcom(mdl)
% Adds the D-STATCOM (averaged voltage source converter with coupling
% filter) at node 634 of a loaded model built from the IEEE 13-bus base
% case, with its controller and logging, grouped into the 'D-STATCOM'
% subsystem. If a DVR is present it must be added first: the D-STATCOM then
% sits on the load side of the DVR.

here = fileparts(mfilename('fullpath'));
libs = {'spsControlledVoltageSourceLib', 'spsThreePhaseSeriesRLCBranchLib', ...
    'spsThreePhaseVIMeasurementLib', 'spsThreePhaseBreakerLib', ...
    'spsSeriesRLCBranchLib', 'spsGroundLib'};
for k = 1:numel(libs), load_system(libs{k}); end

x0 = 1500; y0 = 640;      % top-left of the D-STATCOM area, above node 634

log_source_current(mdl);

%% Power circuit: sources -> filter -> current measurement -> breaker -> node
flt = [mdl '/DST Filter'];
mea = [mdl '/DST Current'];
brk = [mdl '/DST Breaker'];
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
add_block('spsSeriesRLCBranchLib/Series RLC Branch', [mdl '/DST Neutral R'], ...
    'Position', [x0+120 y0+150 x0+170 y0+180], ...
    'BranchType', 'R', 'Resistance', '1e6');
add_block('spsGroundLib/Ground', [mdl '/DST Ground'], ...
    'Position', [x0+60 y0+185 x0+85 y0+210]);

pflt = get_param(flt, 'PortHandles');
pmea = get_param(mea, 'PortHandles');
pbrk = get_param(brk, 'PortHandles');
p634 = get_param([mdl '/634'], 'PortHandles');
pnr  = get_param([mdl '/DST Neutral R'], 'PortHandles');
pgnd = get_param([mdl '/DST Ground'], 'PortHandles');
ph = 'ABC';
for k = 1:3
    cvs = sprintf('%s/DST Source %s', mdl, ph(k));
    y = y0 - 10 + 35*(k-1);
    add_block('spsControlledVoltageSourceLib/Controlled Voltage Source', cvs, ...
        'Position', [x0+220 y x0+250 y+25], 'Initialize', 'off');
    pc = get_param(cvs, 'PortHandles');
    add_line(mdl, pc.RConn(1), pflt.LConn(k), 'autorouting', 'on');   % + terminal
    add_line(mdl, pc.LConn(1), pnr.RConn(1), 'autorouting', 'on');    % - to neutral
    add_line(mdl, pflt.RConn(k), pmea.LConn(k), 'autorouting', 'on');
    add_line(mdl, pmea.RConn(k), pbrk.LConn(k), 'autorouting', 'on');
    add_line(mdl, pbrk.RConn(k), p634.LConn(k), 'autorouting', 'on');
end
add_line(mdl, pnr.LConn(1), pgnd.LConn(1), 'autorouting', 'on');

%% Controller
ctl = [mdl '/DST Controller'];
add_block('simulink/User-Defined Functions/MATLAB Function', ctl, ...
    'Position', [x0-150 y0-20 x0+10 y0+130]);
chart = find(sfroot, '-isa', 'Stateflow.EMChart', 'Path', ctl);
chart.Script = fileread(fullfile(here, 'dstatcom_controller.m'));
chart.ChartUpdate = 'DISCRETE';
chart.SampleTime = '50e-6';

tags = {'V634', 'I634', 'Idst'};
for k = 1:3
    y = y0 - 15 + 26*(k-1);
    frm = sprintf('%s/DST From %s', mdl, tags{k});
    add_block('simulink/Signal Routing/From', frm, ...
        'Position', [x0-260 y x0-200 y+18], 'GotoTag', tags{k});
    add_line(mdl, sprintf('DST From %s/1', tags{k}), sprintf('DST Controller/%d', k), ...
        'autorouting', 'on');
end
add_block('simulink/Sources/Step', [mdl '/DST Enable'], ...
    'Position', [x0-260 y0+65 x0-230 y0+85], ...
    'Time', '100', 'Before', '0', 'After', '1', 'SampleTime', '50e-6');
add_block('simulink/Sources/Constant', [mdl '/DST Mode'], ...
    'Position', [x0-260 y0+95 x0-230 y0+115], 'Value', '1', 'SampleTime', '50e-6');
% Gains: [current-loop bandwidth (Hz); KpDc; KiDc; KpV; KiV]
add_block('simulink/Sources/Constant', [mdl '/DST Gains'], ...
    'Position', [x0-330 y0+125 x0-230 y0+145], 'Value', '[1500; 1; 15; 5; 500]', ...
    'SampleTime', '50e-6');
add_line(mdl, 'DST Enable/1', 'DST Controller/4', 'autorouting', 'on');
add_line(mdl, 'DST Mode/1', 'DST Controller/5', 'autorouting', 'on');
add_line(mdl, 'DST Gains/1', 'DST Controller/6', 'autorouting', 'on');

% One-sample delay breaks the algebraic loop between network and controller
add_block('simulink/Discrete/Unit Delay', [mdl '/DST Delay'], ...
    'Position', [x0+50 y0+5 x0+80 y0+35], 'InitialCondition', '0');
add_block('simulink/Signal Routing/Demux', [mdl '/DST Demux'], ...
    'Position', [x0+120 y0-10 x0+125 y0+60], 'Outputs', '3');
add_line(mdl, 'DST Controller/1', 'DST Delay/1', 'autorouting', 'on');
add_line(mdl, 'DST Delay/1', 'DST Demux/1', 'autorouting', 'on');
for k = 1:3
    add_line(mdl, sprintf('DST Demux/%d', k), sprintf('DST Source %s/1', ph(k)), ...
        'autorouting', 'on');
end

%% Logging
add_block('simulink/Sinks/To Workspace', [mdl '/Log DST dbg'], ...
    'Position', [x0+50 y0+85 x0+130 y0+109], 'VariableName', 'log_dst', ...
    'SaveFormat', 'Timeseries', 'MaxDataPoints', 'inf', 'SampleTime', '-1');
add_line(mdl, 'DST Controller/2', 'Log DST dbg/1', 'autorouting', 'on');
add_block('simulink/Signal Routing/From', [mdl '/Log From Idst'], ...
    'Position', [2000 600 2060 624], 'GotoTag', 'Idst');
add_block('simulink/Sinks/To Workspace', [mdl '/Log Idst'], ...
    'Position', [2120 600 2200 624], 'VariableName', 'log_Idst', ...
    'SaveFormat', 'Timeseries', 'MaxDataPoints', 'inf', 'SampleTime', '-1');
add_line(mdl, 'Log From Idst/1', 'Log Idst/1');

group_blocks(mdl, 'DST', 'D-STATCOM');
end
