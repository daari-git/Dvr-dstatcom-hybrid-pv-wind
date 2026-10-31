function build_single()
% Makes the one model to show and hand on, Simulink_model/IEEE13_DVR_DSTATCOM_PV_Wind.slx:
% IEEE13_full with its results panel (build_panels), with every setting of
% the scenario as a plain block in one place at the top left, so that each
% step of the study is run from this one model with the Run button.
%   In service   a 1/0 block for each device. The base case, D-STATCOM,
%                DVR, DG and combined cases (steps 3 to 7) are this model
%                with devices taken out of service. A device out of service
%                is disconnected: the DVR by a bypass breaker, the shunt
%                devices by their breakers.
%   Settings     switch-on times, controller gains, D-STATCOM mode, sun
%                and wind against time
% The blocks inside the device subsystems that held these settings become
% From blocks. The To Workspace blocks the run scripts read are left out.
% The step models and the run scripts are not changed.
% The saved model was then arranged by hand, its block colours removed and
% its settings and results grouped into two subsystems. Running this again
% overwrites it and loses all of that.

root = fileparts(fileparts(mfilename('fullpath')));
m = 'IEEE13_DVR_DSTATCOM_PV_Wind';
folder = fullfile(root, 'Simulink_model');
if ~exist(folder, 'dir'), mkdir(folder); end
file = fullfile(folder, [m '.slx']);
if bdIsLoaded(m), close_system(m, 0); end
if bdIsLoaded('IEEE13_full'), close_system('IEEE13_full', 0); end
copyfile(fullfile(root, 'IEEE13_full.slx'), file, 'f');
load_system(file);

%% Leave out the workspace logging
tw = find_system(m, 'LookUnderMasks', 'all', 'BlockType', 'ToWorkspace');
for k = 1:numel(tw), delete_block(tw{k}); end
fb = find_system(m, 'SearchDepth', 1, 'BlockType', 'From');
fb = fb(startsWith(get_param(fb, 'Name'), 'Log From'));
for k = 1:numel(fb), delete_block(fb{k}); end
delete_line(find_system(m, 'FindAll', 'on', 'Type', 'line', 'Connected', 'off'));
a = find_system(m, 'FindAll', 'on', 'Type', 'annotation', 'Tag', 'results_panel');
for k = 1:numel(a), delete(get_param(a(k), 'Object')); end     % the step models' note

%% Settings at the top left, each sent to its device on a Goto block
x = -450; y = 560;
y = header(m, 'DVR (series, between the transformer XFXFM1 and node 634)', x, y);
y = device(m, 'DVR', 'DVR', [m '/DVR/DVR Enable'], x, y);
y = setting(m, [m '/DVR/DVR Gains'], 'DVR gains [KpV; KiV; limit (pu)]', 'DVRgains', x, y);
y = header(m, 'D-STATCOM (shunt, at node 634)', x, y + 40);
y = device(m, 'D-STATCOM', 'DST', [m '/D-STATCOM/DST Enable'], x, y);
y = setting(m, [m '/D-STATCOM/DST Mode'], ...
    'D-STATCOM mode (1 = load compensation, 2 = voltage regulation)', 'DSTmode', x, y);
y = setting(m, [m '/D-STATCOM/DST Gains'], ...
    'D-STATCOM gains [bandwidth (Hz); KpDc; KiDc; KpV; KiV; Imax (A)]', 'DSTgains', x, y);
y = header(m, 'PV plant (400 kW, at node 634)', x, y + 40);
y = device(m, 'PV plant', 'PV', [m '/PV Plant/PV Enable'], x, y);
y = resource(m, [m '/PV Plant'], 'PV', 'Sun: irradiance (W/m2) against time (s)', 'Sun', x, y);
y = header(m, 'Wind plant (500 kW, at node 675)', x, y + 40);
y = device(m, 'Wind plant', 'WIND', [m '/Wind Plant/Wind Enable'], x, y);
resource(m, [m '/Wind Plant'], 'Wind', 'Wind speed (m/s) against time (s)', 'WindSpeed', x, y);

%% Inside the devices: From blocks in place of the settings, and the
% breakers of the shunt devices switched by the same command
swap([m '/DVR/DVR Enable'], 'DVRon');
swap([m '/DVR/DVR Gains'], 'DVRgains');
f = swap([m '/D-STATCOM/DST Enable'], 'DSTon');
external([m '/D-STATCOM/DST Breaker'], f);
swap([m '/D-STATCOM/DST Mode'], 'DSTmode');
swap([m '/D-STATCOM/DST Gains'], 'DSTgains');
for p = {'PV', 'PV Plant', 'PVon', 'Sun'; 'Wind', 'Wind Plant', 'WINDon', 'WindSpeed'}'
    s = [m '/' p{2}];
    f = swap([s '/' p{1} ' Enable'], p{3});
    external([s '/' p{1} ' Breaker'], f);
    delete_block([s '/' p{1} ' Clock']);
    swap([s '/' p{1} ' Resource'], p{4});
    delete_line(find_system(s, 'FindAll', 'on', 'Type', 'line', 'Connected', 'off'));
end
for s = {'DVR', 'D-STATCOM', 'PV Plant', 'Wind Plant'}  % the tags name the signals
    f = find_system([m '/' s{1}], 'SearchDepth', 1, 'BlockType', 'From');
    for k = 1:numel(f), set_param(f{k}, 'ShowName', 'off'); end
end

%% DVR bypass breaker, in parallel with the DVR
d = get_param([m '/DVR'], 'Position');
b = [m '/DVR Bypass'];
add_block('spsThreePhaseBreakerLib/Three-Phase Breaker', b, 'Position', [d(1)+10 d(2)-130 d(3)-10 d(2)-50], ...
    'External', 'on', 'InitialState', 'open', 'BreakerResistance', '1e-3', ...
    'SnubberResistance', '1e6', 'SnubberCapacitance', 'inf');
f = add_block('simulink/Signal Routing/From', [m '/DVR Bypass From'], ...
    'Position', [d(1)-110 d(2)-112 d(1)-30 d(2)-88], 'GotoTag', 'DVRbypass', 'ShowName', 'off');
bp = get_param(b, 'PortHandles'); dp = get_param([m '/DVR'], 'PortHandles');
add_line(m, outport(f), bp.Inport(1));
for k = 1:3                              % one lane for each phase
    route(m, bp.LConn(k), dp.LConn(k), d(1) - 25 - 12*(k-1));
    route(m, bp.RConn(k), dp.RConn(k), d(3) + 115 + 11*(k-1));   % clear of the DVR's own lines
end

%% Note
t = {'HOW TO USE THIS MODEL (everything is set in blocks; no script is needed)', '', ...
    '1. Press Run (stop time 1 s). The scopes open and fill in as the model runs, and', ...
    '   the displays right of ''Measurements'' (below the feeder) show the results.', ...
    '2. Choose the devices in service with the 1/0 blocks below:', ...
    '   - step 3, base case: all 0', ...
    '   - step 4, D-STATCOM: D-STATCOM 1, others 0', ...
    '   - step 5, DVR: DVR 1, others 0', ...
    '   - step 6, PV and wind: PV 1 and wind 1, others 0', ...
    '   - step 7, combined: all 1 (as saved)', ...
    '3. The fault: double-click ''Fault 680'' (bottom of the feeder). Tick the faulted', ...
    '   phases and ''Ground'' (untick it for a line-to-line fault). Switching times', ...
    '   [start end] in s; [100 100.1] means no fault. Saved: phase A to ground,', ...
    '   0.6 to 0.8 s.', ...
    '4. The rectifier load: ''NL Breaker'' next to node 634, switching time = when it', ...
    '   connects (100 = never). Saved: 0.3 s.', ...
    '5. Gains: saved are the PSO gains. The hand-tuned gains of steps 4 and 5 are', ...
    '   D-STATCOM [1500; 1; 15; 5; 500; 850] and DVR [0.2; 200; 0.5].', ...
    '6. Sun and wind: double-click the tables to give the irradiance or wind speed', ...
    '   at chosen times, for example a cloud from 0.5 s.', ...
    '', 'To compare runs, for example with and without a device: Simulation tab >', ...
    'Data Inspector. Every run is kept there and the results can be overlaid.', ...
    'Lowest and highest values are taken from ''Min-max start'' (0.5 s) on.'};
a = Simulink.Annotation(m, strjoin(t, newline));
a.Position = [x 90 x+700 130]; a.FontSize = 14;
a.HorizontalAlignment = 'left'; a.Interpreter = 'off';

set_param(m, 'ZoomFactor', 'FitSystem');
save_system(m);
close_system(m, 0);
fprintf('Saved %s\n', file);
end

function y = header(m, text, x, y)
a = Simulink.Annotation(m, text);
a.Position = [x y x+700 y+20]; a.FontSize = 14; a.FontWeight = 'bold';
a.HorizontalAlignment = 'left'; a.Interpreter = 'off';
y = y + 50;
end

function y = device(m, name, tag, step, x, y)
% name in service (1/0) times the switch-on step = the device command. The
% DVR also gets the bypass command, 1 when it is out of service.
c = add(m, 'simulink/Sources/Constant', [name ' in service (1 = yes, 0 = no)'], ...
    [x y x+60 y+30], 'Value', '1');
s = [m '/' name ' switch-on time (s)'];
add_block(step, s, 'Position', [x y+60 x+60 y+90]);
p = add(m, 'simulink/Math Operations/Product', [name ' command'], [x+420 y-15 x+450 y+105]);
g = add(m, 'simulink/Signal Routing/Goto', [name ' Goto'], [x+530 y+33 x+620 y+57], ...
    'GotoTag', [tag 'on'], 'TagVisibility', 'global', 'ShowName', 'off');
pp = get_param(p, 'PortHandles');
add_line(m, outport(c), pp.Inport(1));
add_line(m, outport(s), pp.Inport(2));
add_line(m, pp.Outport(1), inport(g));
y = y + 160;
if strcmp(tag, 'DVR')
    f = add(m, 'simulink/User-Defined Functions/Fcn', 'DVR bypass closed (1 - in service)', ...
        [x+260 y-30 x+370 y], 'Expr', '1 - u(1)');
    g = add(m, 'simulink/Signal Routing/Goto', 'DVR bypass Goto', [x+530 y-27 x+620 y-3], ...
        'GotoTag', 'DVRbypass', 'TagVisibility', 'global', 'ShowName', 'off');
    add_line(m, outport(c), inport(f), 'autorouting', 'on');
    add_line(m, outport(f), inport(g));
    y = y + 70;
end
end

function y = setting(m, blk, name, tag, x, y)
% A copy of the setting block from inside the device, sent on.
c = [m '/' name];
add_block(blk, c, 'Position', [x y x+380 y+30]);
g = add(m, 'simulink/Signal Routing/Goto', [name ' Goto'], [x+530 y+3 x+620 y+27], ...
    'GotoTag', tag, 'TagVisibility', 'global', 'ShowName', 'off');
add_line(m, outport(c), inport(g));
y = y + 90;
end

function y = resource(m, plant, p, name, tag, x, y)
% The plant's clock and resource table, moved out of the plant.
name = strrep(name, '/', '//');           % a slash in a block path is doubled
k = [m '/' p ' time'];
add_block([plant '/' p ' Clock'], k, 'Position', [x y x+60 y+30], 'ShowName', 'off');
r = [m '/' name];
add_block([plant '/' p ' Resource'], r, 'Position', [x+200 y-5 x+280 y+35]);
g = add(m, 'simulink/Signal Routing/Goto', [name ' Goto'], [x+530 y+3 x+620 y+27], ...
    'GotoTag', tag, 'TagVisibility', 'global', 'ShowName', 'off');
add_line(m, outport(k), inport(r));
add_line(m, outport(r), inport(g));
y = y + 90;
end

function route(m, a, b, x)
% A connection from port a to port b along the vertical lane x.
pa = get_param(a, 'Position'); pb = get_param(b, 'Position');
add_line(m, [pa; x pa(2); x pb(2); pb]);
end

function f = swap(blk, tag)
% Replaces a source block with a From block of the tag, wired the same.
par = get_param(blk, 'Parent'); pos = get_param(blk, 'Position');
lh = get_param(blk, 'LineHandles');
dst = [];
if lh.Outport(1) > 0
    dst = get_param(lh.Outport(1), 'DstPortHandle');
    delete_line(lh.Outport(1));
end
delete_block(blk);
r = (pos(2) + pos(4))/2;                 % same right edge, so the line stays
f = add_block('simulink/Signal Routing/From', blk, 'GotoTag', tag, ...
    'Position', [pos(3)-70 r-12 pos(3) r+12], 'ShowName', 'off');
for d = dst(dst > 0)', add_line(par, outport(f), d, 'autorouting', 'on'); end
end

function external(brk, f)
% Switches a breaker by the command on From block f instead of its timer.
set_param(brk, 'External', 'on');
bp = get_param(brk, 'PortHandles');
add_line(get_param(brk, 'Parent'), outport(f), bp.Inport(1), 'autorouting', 'on');
end

function b = add(par, lib, name, pos, varargin)
b = [par '/' name];
add_block(lib, b, 'Position', pos, varargin{:});
end

function h = outport(b)
ph = get_param(b, 'PortHandles'); h = ph.Outport(1);
end

function h = inport(b)
ph = get_param(b, 'PortHandles'); h = ph.Inport(1);
end
