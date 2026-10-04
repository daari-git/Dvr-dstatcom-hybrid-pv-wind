function build_dvr()
% Builds IEEE13_dvr.slx from IEEE13_basecase.slx.
% Inserts a DVR (averaged series voltage source with series impedance)
% between the transformer and node 634, its controller, and logging.
% Run build_basecase first.

src = 'IEEE13_basecase';
dst = 'IEEE13_dvr';
here = fileparts(mfilename('fullpath'));
root = fileparts(here);

if bdIsLoaded(dst), close_system(dst, 0); end
if bdIsLoaded(src), close_system(src, 0); end
load_system(fullfile(root, [src '.slx']));
save_system(src, fullfile(root, [dst '.slx']));   % loaded model is now dst

libs = {'spsControlledVoltageSourceLib', 'spsThreePhaseSeriesRLCBranchLib'};
for k = 1:numel(libs), load_system(libs{k}); end

x0 = 1500; y0 = 640;      % top-left of the DVR area, above node 634

%% Power circuit: open the feeder at node 634 and insert the series sources
% Series impedance stands for the injection transformer leakage, about 5 %
% on a 500 kVA, 480 V base.
flt = [dst '/DVR Series Z'];
add_block('spsThreePhaseSeriesRLCBranchLib/Three-Phase Series RLC Branch', flt, ...
    'Position', [x0+330 y0 x0+390 y0+70], ...
    'BranchType', 'RL', 'Resistance', '2e-3', 'Inductance', '60e-6');
pflt = get_param(flt, 'PortHandles');
psup = get_param([dst '/XFXFM1'], 'PortHandles');
p634 = get_param([dst '/634'], 'PortHandles');
ph = 'ABC';
for k = 1:3
    delete_line(get_param(p634.LConn(k), 'Line'));
    cvs = sprintf('%s/DVR Source %s', dst, ph(k));
    y = y0 - 10 + 35*(k-1);
    add_block('spsControlledVoltageSourceLib/Controlled Voltage Source', cvs, ...
        'Position', [x0+220 y x0+250 y+25], 'Initialize', 'off');
    pc = get_param(cvs, 'PortHandles');
    add_line(dst, psup.RConn(k), pc.LConn(1), 'autorouting', 'on');   % supply to -
    add_line(dst, pc.RConn(1), pflt.LConn(k), 'autorouting', 'on');   % + to load side
    add_line(dst, pflt.RConn(k), p634.LConn(k), 'autorouting', 'on');
end

%% Controller
ctl = [dst '/DVR Controller'];
add_block('simulink/User-Defined Functions/MATLAB Function', ctl, ...
    'Position', [x0-150 y0-20 x0+10 y0+110]);
chart = find(sfroot, '-isa', 'Stateflow.EMChart', 'Path', ctl);
chart.Script = fileread(fullfile(here, 'dvr_controller.m'));
chart.ChartUpdate = 'DISCRETE';
chart.SampleTime = '50e-6';

tags = {'XFXFM1', 'V634', 'I634'};     % supply voltage, load voltage, load current
for k = 1:3
    y = y0 - 15 + 30*(k-1);
    frm = sprintf('%s/DVR From %s', dst, tags{k});
    add_block('simulink/Signal Routing/From', frm, ...
        'Position', [x0-260 y x0-200 y+18], 'GotoTag', tags{k});
    add_line(dst, sprintf('DVR From %s/1', tags{k}), sprintf('DVR Controller/%d', k), ...
        'autorouting', 'on');
end
add_block('simulink/Sources/Step', [dst '/DVR Enable'], ...
    'Position', [x0-260 y0+85 x0-230 y0+105], ...
    'Time', '100', 'Before', '0', 'After', '1', 'SampleTime', '50e-6');
add_line(dst, 'DVR Enable/1', 'DVR Controller/4', 'autorouting', 'on');

% One-sample delay breaks the algebraic loop between network and controller
add_block('simulink/Discrete/Unit Delay', [dst '/DVR Delay'], ...
    'Position', [x0+50 y0+5 x0+80 y0+35], 'InitialCondition', '0');
add_block('simulink/Signal Routing/Demux', [dst '/DVR Demux'], ...
    'Position', [x0+120 y0-10 x0+125 y0+60], 'Outputs', '3');
add_line(dst, 'DVR Controller/1', 'DVR Delay/1', 'autorouting', 'on');
add_line(dst, 'DVR Delay/1', 'DVR Demux/1', 'autorouting', 'on');
for k = 1:3
    add_line(dst, sprintf('DVR Demux/%d', k), sprintf('DVR Source %s/1', ph(k)), ...
        'autorouting', 'on');
end

%% Logging
logs = {'Log DVR dbg', 'log_dvr', 2; 'Log DVR vinj', 'log_Vinj', 1};
for k = 1:size(logs, 1)
    y = y0 + 75 + 40*(k-1);
    add_block('simulink/Sinks/To Workspace', [dst '/' logs{k, 1}], ...
        'Position', [x0+50 y x0+130 y+24], 'VariableName', logs{k, 2}, ...
        'SaveFormat', 'Timeseries', 'MaxDataPoints', 'inf', 'SampleTime', '-1');
end
add_line(dst, 'DVR Controller/2', 'Log DVR dbg/1', 'autorouting', 'on');
add_line(dst, 'DVR Delay/1', 'Log DVR vinj/1', 'autorouting', 'on');
add_block('simulink/Signal Routing/From', [dst '/Log From XFXFM1'], ...
    'Position', [2000 540 2060 564], 'GotoTag', 'XFXFM1');
add_block('simulink/Sinks/To Workspace', [dst '/Log Vs634'], ...
    'Position', [2120 540 2200 564], 'VariableName', 'log_Vs634', ...
    'SaveFormat', 'Timeseries', 'MaxDataPoints', 'inf', 'SampleTime', '-1');
add_line(dst, 'Log From XFXFM1/1', 'Log Vs634/1');

group_blocks(dst, 'DVR', 'DVR');

save_system(dst);
close_system(dst, 0);
fprintf('Built %s\n', fullfile(root, [dst '.slx']));
end
