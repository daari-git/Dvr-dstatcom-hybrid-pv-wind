function add_dvr(mdl, itag)
% Inserts the DVR (averaged series voltage source with series impedance)
% between the transformer and node 634 of a loaded model built from the
% IEEE 13-bus base case, with its controller and logging, grouped into the
% 'DVR' subsystem. Add it before the D-STATCOM.
%   itag  label of the current through the DVR: 'Is634' (default) when any
%         D-STATCOM is on its load side, 'I634' when one is on its supply side

if nargin < 2, itag = 'Is634'; end
here = fileparts(mfilename('fullpath'));
libs = {'spsControlledVoltageSourceLib', 'spsThreePhaseSeriesRLCBranchLib'};
for k = 1:numel(libs), load_system(libs{k}); end

x0 = 1500; y0 = 380;      % top-left of the DVR area, above the D-STATCOM

log_source_current(mdl);

%% Power circuit: open the feeder at node 634 and insert the series sources
% Series impedance stands for the injection transformer leakage, about 5 %
% on a 500 kVA, 480 V base.
flt = [mdl '/DVR Series Z'];
add_block('spsThreePhaseSeriesRLCBranchLib/Three-Phase Series RLC Branch', flt, ...
    'Position', [x0+330 y0 x0+390 y0+70], ...
    'BranchType', 'RL', 'Resistance', '2e-3', 'Inductance', '60e-6');
pflt = get_param(flt, 'PortHandles');
psup = get_param([mdl '/XFXFM1'], 'PortHandles');
p634 = get_param([mdl '/634'], 'PortHandles');
ph = 'ABC';
for k = 1:3
    delete_line(get_param(p634.LConn(k), 'Line'));
    cvs = sprintf('%s/DVR Source %s', mdl, ph(k));
    y = y0 - 10 + 35*(k-1);
    add_block('spsControlledVoltageSourceLib/Controlled Voltage Source', cvs, ...
        'Position', [x0+220 y x0+250 y+25], 'Initialize', 'off');
    pc = get_param(cvs, 'PortHandles');
    add_line(mdl, psup.RConn(k), pc.LConn(1), 'autorouting', 'on');   % supply to -
    add_line(mdl, pc.RConn(1), pflt.LConn(k), 'autorouting', 'on');   % + to load side
    add_line(mdl, pflt.RConn(k), p634.LConn(k), 'autorouting', 'on');
end

%% Controller
ctl = [mdl '/DVR Controller'];
add_block('simulink/User-Defined Functions/MATLAB Function', ctl, ...
    'Position', [x0-150 y0-20 x0+10 y0+130]);
chart = find(sfroot, '-isa', 'Stateflow.EMChart', 'Path', ctl);
chart.Script = fileread(fullfile(here, 'dvr_controller.m'));
chart.ChartUpdate = 'DISCRETE';
chart.SampleTime = '50e-6';

tags = {'XFXFM1', 'V634', itag};       % supply voltage, load voltage, series current
for k = 1:3
    y = y0 - 15 + 30*(k-1);
    frm = sprintf('%s/DVR From %s', mdl, tags{k});
    add_block('simulink/Signal Routing/From', frm, ...
        'Position', [x0-260 y x0-200 y+18], 'GotoTag', tags{k});
    add_line(mdl, sprintf('DVR From %s/1', tags{k}), sprintf('DVR Controller/%d', k), ...
        'autorouting', 'on');
end
add_block('simulink/Sources/Step', [mdl '/DVR Enable'], ...
    'Position', [x0-260 y0+85 x0-230 y0+105], ...
    'Time', '100', 'Before', '0', 'After', '1', 'SampleTime', '50e-6');
% Gains, rating and strategy: [KpV; KiV; injection limit (pu); target in a
% disturbance (pu); usable battery energy (kJ)]
add_block('simulink/Sources/Constant', [mdl '/DVR Gains'], ...
    'Position', [x0-300 y0+115 x0-230 y0+135], 'Value', '[0.2; 200; 0.5; 1; 1e6]', ...
    'SampleTime', '50e-6');
add_line(mdl, 'DVR Enable/1', 'DVR Controller/4', 'autorouting', 'on');
add_line(mdl, 'DVR Gains/1', 'DVR Controller/5', 'autorouting', 'on');

% One-sample delay breaks the algebraic loop between network and controller
add_block('simulink/Discrete/Unit Delay', [mdl '/DVR Delay'], ...
    'Position', [x0+50 y0+5 x0+80 y0+35], 'InitialCondition', '0');
add_block('simulink/Signal Routing/Demux', [mdl '/DVR Demux'], ...
    'Position', [x0+120 y0-10 x0+125 y0+60], 'Outputs', '3');
add_line(mdl, 'DVR Controller/1', 'DVR Delay/1', 'autorouting', 'on');
add_line(mdl, 'DVR Delay/1', 'DVR Demux/1', 'autorouting', 'on');
for k = 1:3
    add_line(mdl, sprintf('DVR Demux/%d', k), sprintf('DVR Source %s/1', ph(k)), ...
        'autorouting', 'on');
end

%% Logging
logs = {'Log DVR dbg', 'log_dvr', 2; 'Log DVR vinj', 'log_Vinj', 1};
for k = 1:size(logs, 1)
    y = y0 + 75 + 40*(k-1);
    add_block('simulink/Sinks/To Workspace', [mdl '/' logs{k, 1}], ...
        'Position', [x0+50 y x0+130 y+24], 'VariableName', logs{k, 2}, ...
        'SaveFormat', 'Timeseries', 'MaxDataPoints', 'inf', 'SampleTime', '-1');
end
add_line(mdl, 'DVR Controller/2', 'Log DVR dbg/1', 'autorouting', 'on');
add_line(mdl, 'DVR Delay/1', 'Log DVR vinj/1', 'autorouting', 'on');
add_block('simulink/Signal Routing/From', [mdl '/Log From XFXFM1'], ...
    'Position', [2000 660 2060 684], 'GotoTag', 'XFXFM1');
add_block('simulink/Sinks/To Workspace', [mdl '/Log Vs634'], ...
    'Position', [2120 660 2200 684], 'VariableName', 'log_Vs634', ...
    'SaveFormat', 'Timeseries', 'MaxDataPoints', 'inf', 'SampleTime', '-1');
add_line(mdl, 'Log From XFXFM1/1', 'Log Vs634/1');
add_block('simulink/Signal Routing/From', [mdl '/Log From Idvr'], ...
    'Position', [2000 780 2060 804], 'GotoTag', itag);
add_block('simulink/Sinks/To Workspace', [mdl '/Log Idvr'], ...
    'Position', [2120 780 2200 804], 'VariableName', 'log_Idvr', ...
    'SaveFormat', 'Timeseries', 'MaxDataPoints', 'inf', 'SampleTime', '-1');
add_line(mdl, 'Log From Idvr/1', 'Log Idvr/1');

group_blocks(mdl, 'DVR', 'DVR');
end
