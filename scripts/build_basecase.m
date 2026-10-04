function build_basecase()
% Builds IEEE13_basecase.slx from the validated IEEE 13-bus model.
% Adds: a three-phase fault at node 680, a switchable non-linear load
% (diode rectifier) at node 634, and waveform logging at 634, 632 and 671.
% The original IEEE model is not modified.

src = 'IEEE13bus_v2019b_Discrete';
dst = 'IEEE13_basecase';
root = fileparts(fileparts(mfilename('fullpath')));

if bdIsLoaded(dst), close_system(dst, 0); end
if bdIsLoaded(src), close_system(src, 0); end
load_system(fullfile(root, [src '.slx']));
save_system(src, fullfile(root, [dst '.slx']));   % loaded model is now dst

load_system('spsThreePhaseFaultLib');
load_system('spsThreePhaseBreakerLib');
load_system('spsUniversalBridgeLib');
load_system('spsSeriesRLCBranchLib');

%% Fault at node 680 (disabled by default: switching times beyond stop time)
flt = [dst '/Fault 680'];
add_block('spsThreePhaseFaultLib/Three-Phase Fault', flt, ...
    'Position', [880 1690 940 1755], ...
    'FaultA', 'on', 'FaultB', 'on', 'FaultC', 'on', 'GroundFault', 'on', ...
    'SwitchTimes', '[100 100.1]', ...
    'FaultResistance', '0.01', 'GroundResistance', '0.01');
p680 = get_param([dst '/680'], 'PortHandles');
pflt = get_param(flt, 'PortHandles');
for k = 1:3
    add_line(dst, p680.RConn(k), pflt.LConn(k), 'autorouting', 'on');
end

%% Non-linear load at node 634: breaker -> diode rectifier -> RL load
% 480 V line-to-line gives about 648 V DC, so 4.2 ohm draws about 100 kW.
brk = [dst '/NL Breaker'];
rec = [dst '/NL Rectifier'];
dcl = [dst '/NL DC Load'];
add_block('spsThreePhaseBreakerLib/Three-Phase Breaker', brk, ...
    'Position', [1905 1110 1960 1176], ...
    'InitialState', 'open', 'SwitchA', 'on', 'SwitchB', 'on', 'SwitchC', 'on', ...
    'SwitchTimes', '[100]');
add_block('spsUniversalBridgeLib/Universal Bridge', rec, ...
    'Position', [2030 1105 2100 1180], 'Arms', '3', 'Device', 'Diodes');
add_block('spsSeriesRLCBranchLib/Series RLC Branch', dcl, ...
    'Position', [2170 1120 2230 1165], 'Orientation', 'down', ...
    'BranchType', 'RL', 'Resistance', '4.2', 'Inductance', '5e-3');
p634 = get_param([dst '/634'], 'PortHandles');
pbrk = get_param(brk, 'PortHandles');
prec = get_param(rec, 'PortHandles');
pdcl = get_param(dcl, 'PortHandles');
for k = 1:3
    add_line(dst, p634.RConn(k), pbrk.LConn(k), 'autorouting', 'on');
    add_line(dst, pbrk.RConn(k), prec.LConn(k), 'autorouting', 'on');
end
add_line(dst, prec.RConn(1), pdcl.LConn(1), 'autorouting', 'on');
add_line(dst, pdcl.RConn(1), prec.RConn(2), 'autorouting', 'on');

%% Waveform logging (signals come from the V-I measurement labels)
tags = {'V634', 'I634', 'V632', 'V671'};
for k = 1:numel(tags)
    y = 300 + 60*(k-1);
    frm = sprintf('%s/Log From %s', dst, tags{k});
    tow = sprintf('%s/Log %s', dst, tags{k});
    add_block('simulink/Signal Routing/From', frm, ...
        'Position', [2000 y 2060 y+24], 'GotoTag', tags{k});
    add_block('simulink/Sinks/To Workspace', tow, ...
        'Position', [2120 y 2200 y+24], 'VariableName', ['log_' tags{k}], ...
        'SaveFormat', 'Timeseries', 'MaxDataPoints', 'inf', 'SampleTime', '-1');
    add_line(dst, sprintf('Log From %s/1', tags{k}), sprintf('Log %s/1', tags{k}));
end

% Plain Tustin integration chatters at the sample rate when the diodes
% switch; the Tustin/Backward Euler solver damps it.
set_param([dst '/powergui'], 'SolverType', 'Tustin/Backward Euler (TBE)');

set_param(dst, 'StopTime', '1.3');
save_system(dst);
close_system(dst, 0);
fprintf('Built %s\n', fullfile(root, [dst '.slx']));
end
