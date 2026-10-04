function add_dg(mdl)
% Adds the PV plant (400 kW, node 634) and the wind plant (500 kW, node 675)
% to a loaded model built from the IEEE 13-bus base case.
% Each plant is an averaged inverter behind a coupling filter, connected
% through a breaker that closes at 0.2 s.

here = fileparts(mfilename('fullpath'));
libs = {'spsControlledVoltageSourceLib', 'spsThreePhaseSeriesRLCBranchLib', ...
    'spsThreePhaseVIMeasurementLib', 'spsThreePhaseBreakerLib', ...
    'spsSeriesRLCBranchLib', 'spsGroundLib'};
for k = 1:numel(libs), load_system(libs{k}); end
code = fileread(fullfile(here, 'dg_controller.m'));

% name, node, voltage tag, current tag, kind, rated V, rated VA, resource
% default, top-left position
plant(mdl, code, 'PV',   '634', 'V634', 'Ipv',   1, '480',  '450e3', '1000', [2500 620]);
plant(mdl, code, 'Wind', '675', 'V675', 'Iwind', 2, '4160', '550e3', '12',   [2500 1500]);

% Voltage at the wind plant's node
add_block('simulink/Signal Routing/From', [mdl '/Log From V675'], ...
    'Position', [2000 720 2060 744], 'GotoTag', 'V675');
add_block('simulink/Sinks/To Workspace', [mdl '/Log V675'], ...
    'Position', [2120 720 2200 744], 'VariableName', 'log_V675', ...
    'SaveFormat', 'Timeseries', 'MaxDataPoints', 'inf', 'SampleTime', '-1');
add_line(mdl, 'Log From V675/1', 'Log V675/1');
end

function plant(mdl, code, name, node, vtag, itag, kind, vn, sr, res0, xy)
x0 = xy(1); y0 = xy(2);
tEn = '0.2';
blk = @(s) sprintf('%s/%s %s', mdl, name, s);

%% Power circuit: sources -> filter -> current measurement -> breaker -> node
% Filter of 0.1 pu reactance and 0.01 pu resistance on the plant rating,
% the same values as in dg_controller.
add_block('spsThreePhaseSeriesRLCBranchLib/Three-Phase Series RLC Branch', blk('Filter'), ...
    'Position', [x0+330 y0 x0+390 y0+70], 'BranchType', 'RL', ...
    'Resistance', sprintf('0.01*%s^2/%s', vn, sr), ...
    'Inductance', sprintf('0.1*%s^2/%s/(2*pi*60)', vn, sr));
add_block('spsThreePhaseVIMeasurementLib/Three-Phase V-I Measurement', blk('Current'), ...
    'Position', [x0+440 y0 x0+465 y0+70], ...
    'VoltageMeasurement', 'no', 'CurrentMeasurement', 'yes', ...
    'SetLabelI', 'on', 'LabelI', itag);
add_block('spsThreePhaseBreakerLib/Three-Phase Breaker', blk('Breaker'), ...
    'Position', [x0+520 y0 x0+575 y0+70], ...
    'InitialState', 'open', 'SwitchA', 'on', 'SwitchB', 'on', 'SwitchC', 'on', ...
    'SwitchTimes', ['[' tEn ']']);
add_block('spsSeriesRLCBranchLib/Series RLC Branch', blk('Neutral R'), ...
    'Position', [x0+120 y0+150 x0+170 y0+180], 'BranchType', 'R', 'Resistance', '1e6');
add_block('spsGroundLib/Ground', blk('Ground'), ...
    'Position', [x0+60 y0+185 x0+85 y0+210]);

pflt = get_param(blk('Filter'), 'PortHandles');
pmea = get_param(blk('Current'), 'PortHandles');
pbrk = get_param(blk('Breaker'), 'PortHandles');
pnod = get_param([mdl '/' node], 'PortHandles');
pnr  = get_param(blk('Neutral R'), 'PortHandles');
pgnd = get_param(blk('Ground'), 'PortHandles');
ph = 'ABC';
for k = 1:3
    cvs = blk(['Source ' ph(k)]);
    y = y0 - 10 + 35*(k-1);
    add_block('spsControlledVoltageSourceLib/Controlled Voltage Source', cvs, ...
        'Position', [x0+220 y x0+250 y+25], 'Initialize', 'off');
    pc = get_param(cvs, 'PortHandles');
    add_line(mdl, pc.RConn(1), pflt.LConn(k), 'autorouting', 'on');   % + terminal
    add_line(mdl, pc.LConn(1), pnr.RConn(1), 'autorouting', 'on');    % - to neutral
    add_line(mdl, pflt.RConn(k), pmea.LConn(k), 'autorouting', 'on');
    add_line(mdl, pmea.RConn(k), pbrk.LConn(k), 'autorouting', 'on');
    add_line(mdl, pbrk.RConn(k), pnod.RConn(k), 'autorouting', 'on');
end
add_line(mdl, pnr.LConn(1), pgnd.LConn(1), 'autorouting', 'on');

%% Controller and its inputs
ctl = blk('Controller');
add_block('simulink/User-Defined Functions/MATLAB Function', ctl, ...
    'Position', [x0-150 y0-20 x0+10 y0+130]);
chart = find(sfroot, '-isa', 'Stateflow.EMChart', 'Path', ctl);
chart.Script = code;
chart.ChartUpdate = 'DISCRETE';
chart.SampleTime = '50e-6';
cn = [name ' Controller'];

tags = {vtag, itag};
for k = 1:2
    y = y0 - 15 + 28*(k-1);
    add_block('simulink/Signal Routing/From', blk(['From ' tags{k}]), ...
        'Position', [x0-260 y x0-200 y+18], 'GotoTag', tags{k});
    add_line(mdl, sprintf('%s From %s/1', name, tags{k}), sprintf('%s/%d', cn, k), ...
        'autorouting', 'on');
end
% Resource profile: time breakpoints and values, set by the run scripts
add_block('simulink/Sources/Digital Clock', blk('Clock'), ...
    'Position', [x0-380 y0+45 x0-340 y0+65], 'SampleTime', '50e-6');
add_block('simulink/Lookup Tables/1-D Lookup Table', blk('Resource'), ...
    'Position', [x0-300 y0+40 x0-240 y0+70], ...
    'BreakpointsForDimension1', '[0 100]', 'Table', sprintf('[%s %s]', res0, res0), ...
    'ExtrapMethod', 'Clip');
add_line(mdl, [name ' Clock/1'], [name ' Resource/1']);
add_line(mdl, [name ' Resource/1'], [cn '/3'], 'autorouting', 'on');
add_block('simulink/Sources/Step', blk('Enable'), ...
    'Position', [x0-260 y0+85 x0-230 y0+105], ...
    'Time', tEn, 'Before', '0', 'After', '1', 'SampleTime', '50e-6');
add_block('simulink/Sources/Constant', blk('Kind'), ...
    'Position', [x0-260 y0+115 x0-230 y0+135], 'Value', num2str(kind), ...
    'SampleTime', '50e-6');
add_line(mdl, [name ' Enable/1'], [cn '/4'], 'autorouting', 'on');
add_line(mdl, [name ' Kind/1'], [cn '/5'], 'autorouting', 'on');

% One-sample delay breaks the algebraic loop between network and controller
add_block('simulink/Discrete/Unit Delay', blk('Delay'), ...
    'Position', [x0+50 y0+5 x0+80 y0+35], 'InitialCondition', '0');
add_block('simulink/Signal Routing/Demux', blk('Demux'), ...
    'Position', [x0+120 y0-10 x0+125 y0+60], 'Outputs', '3');
add_line(mdl, [cn '/1'], [name ' Delay/1'], 'autorouting', 'on');
add_line(mdl, [name ' Delay/1'], [name ' Demux/1'], 'autorouting', 'on');
for k = 1:3
    add_line(mdl, sprintf('%s Demux/%d', name, k), sprintf('%s Source %s/1', name, ph(k)), ...
        'autorouting', 'on');
end

add_block('simulink/Sinks/To Workspace', blk('Log'), ...
    'Position', [x0+50 y0+85 x0+130 y0+109], 'VariableName', ['log_' lower(name)], ...
    'SaveFormat', 'Timeseries', 'MaxDataPoints', 'inf', 'SampleTime', '-1');
add_line(mdl, [cn '/2'], [name ' Log/1'], 'autorouting', 'on');
end
