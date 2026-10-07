function add_relay(mdl)
% Adds relay-timed faults to a loaded model built from the IEEE 13-bus base
% case: fault blocks at nodes 680 (existing), 675 and 632, switched by an
% inverse-time overcurrent relay on the substation current. One location is
% active at a time, chosen in the 'Relay Config' block.

here = fileparts(mfilename('fullpath'));
load_system('spsThreePhaseFaultLib');

%% Fault blocks, all under external control
set_param([mdl '/Fault 680'], 'External', 'on');
nodes = {'675', '632'}; pos = {[1700 1620 1760 1685], [1150 880 1210 945]};
for k = 1:2
    flt = sprintf('%s/Fault %s', mdl, nodes{k});
    add_block('spsThreePhaseFaultLib/Three-Phase Fault', flt, 'Position', pos{k}, ...
        'FaultA', 'on', 'FaultB', 'on', 'FaultC', 'on', 'GroundFault', 'on', ...
        'External', 'on', 'FaultResistance', '0.01', 'GroundResistance', '0.01');
    pn = get_param([mdl '/' nodes{k}], 'PortHandles');
    pf = get_param(flt, 'PortHandles');
    for p = 1:3
        add_line(mdl, pn.RConn(p), pf.LConn(p), 'autorouting', 'on');
    end
end

%% Relay
x0 = 500; y0 = 300;
rly = [mdl '/Relay Logic'];
add_block('simulink/User-Defined Functions/MATLAB Function', rly, ...
    'Position', [x0 y0 x0+140 y0+100]);
chart = find(sfroot, '-isa', 'Stateflow.EMChart', 'Path', rly);
chart.Script = fileread(fullfile(here, 'fault_relay.m'));
chart.ChartUpdate = 'DISCRETE';
chart.SampleTime = '50e-6';

add_block('simulink/Signal Routing/From', [mdl '/Relay From I650'], ...
    'Position', [x0-110 y0+8 x0-50 y0+26], 'GotoTag', 'I650');
add_block('simulink/Sources/Digital Clock', [mdl '/Relay Clock'], ...
    'Position', [x0-110 y0+40 x0-70 y0+60], 'SampleTime', '50e-6');
% [fault start (s); location 1 = 680, 2 = 675, 3 = 632; pickup (A rms);
%  time multiplier; breaker time (s); backup clearing time (s)]
add_block('simulink/Sources/Constant', [mdl '/Relay Config'], ...
    'Position', [x0-200 y0+74 x0-50 y0+94], 'Value', '[100; 1; 700; 0.03; 0.03; 0.6]', ...
    'SampleTime', '50e-6');
add_line(mdl, 'Relay From I650/1', 'Relay Logic/1', 'autorouting', 'on');
add_line(mdl, 'Relay Clock/1', 'Relay Logic/2', 'autorouting', 'on');
add_line(mdl, 'Relay Config/1', 'Relay Logic/3', 'autorouting', 'on');

add_block('simulink/Signal Routing/Demux', [mdl '/Relay Demux'], ...
    'Position', [x0+180 y0 x0+185 y0+70], 'Outputs', '3');
add_line(mdl, 'Relay Logic/1', 'Relay Demux/1', 'autorouting', 'on');
tgt = {'Fault 680', 'Fault 675', 'Fault 632'};
for k = 1:3
    add_line(mdl, sprintf('Relay Demux/%d', k), [tgt{k} '/1'], 'autorouting', 'on');
end
add_block('simulink/Sinks/To Workspace', [mdl '/Log Relay'], ...
    'Position', [x0+180 y0+90 x0+260 y0+114], 'VariableName', 'log_relay', ...
    'SaveFormat', 'Timeseries', 'MaxDataPoints', 'inf', 'SampleTime', '-1');
add_line(mdl, 'Relay Logic/2', 'Log Relay/1', 'autorouting', 'on');
end
