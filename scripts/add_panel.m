function add_panel(mdl)
% Adds a results panel below the feeder of a loaded model, so that a run
% started with the Simulink Run button shows its results in Simulink:
%   Measurements  a subsystem of standard measurement blocks (RMS, THD,
%                 Sequence Analyzer, Power, Mean) that turns the measured
%                 voltages and currents into per-unit voltages, distortion,
%                 power factor and unbalance
%   Scopes        voltage waveforms, RMS voltages, power quality, power and
%                 devices, currents; they open when the run starts
%   Displays      lowest and highest voltages, DVR power and energy, and
%                 the power quality at the end of the run
%   Note          how to set the scenario and run
% Parts for the DVR, D-STATCOM and PV and wind plants are added only when
% the model has them. Every result is also logged for the Simulation Data
% Inspector, where runs of different models can be overlaid. Running it
% again replaces the panel. The rest of the model is not moved; the model
% is not saved here (see build_panels).

hasDvr = has(mdl, 'DVR'); hasDst = has(mdl, 'D-STATCOM'); hasDg = has(mdl, 'PV Plant');
remove_panel(mdl);

%% Signals that are not on a Goto block yet
if hasDvr, tap(mdl, 'log_Vinj', 'Vinj'); tap(mdl, 'log_dvr', 'DVRdata'); end
if hasDst, tap(mdl, 'log_dst', 'DSTdata'); end
if hasDg,  tap(mdl, 'log_pv', 'PVdata'); tap(mdl, 'log_wind', 'WINDdata'); end

%% Measurements subsystem
src = 'I634'; if hasDvr || hasDst, src = 'Is634'; end    % current from the source
in = {'V634', 'Load voltage'; src, 'Source current'};
if hasDvr, in = [in; {'XFXFM1', 'Supply voltage'; 'Vinj', 'DVR voltage'; 'DVRdata', 'DVR data'}]; end
if hasDst, in = [in; {'DSTdata', 'D-STATCOM data'}]; end
if hasDg,  in = [in; {'V675', 'Node 675 voltage'; 'PVdata', 'PV data'; 'WINDdata', 'Wind data'}]; end
in = [in; {'', 'Min-max start'}];
S = [mdl '/Measurements'];
add_block('built-in/Subsystem', S, 'Tag', 'results_panel');
measurements(S, in(:, 2), hasDvr, hasDst, hasDg);

% What each scope and the displays show, in the order the results leave
% the subsystem, so that every line runs straight across
W = {}; R = {};
if hasDvr, W = {'Supply voltage (pu)', 'DVR voltage (pu)'}; R = {'Supply RMS voltage (pu)'}; end
W = [W {'Load voltage (pu)'}]; R = [R {'Load RMS voltage (pu)'}];
if hasDg, R = [R {'Node 675 RMS voltage (pu)'}]; end
Q = {'Load voltage THD (%)', 'Source current THD (%)', 'Source power factor', ...
    'Source current unbalance (%)', 'Load voltage unbalance (%)'};
D = {}; L = {};
if hasDvr, D = {'DVR power (kW)', 'DVR energy (kJ)'}; L = {[-50 200], [-5 40]}; end
if hasDst, D = [D {'D-STATCOM DC voltage (V)'}]; L = [L {[0 1200]}]; end
if hasDg,  D = [D {'PV power (kW)', 'Wind power (kW)'}]; L = [L {[-100 700], [-100 700]}]; end
D = [D {'Active power from source (kW)', 'Reactive power from source (kvar)'}];
L = [L {[-500 1500], [-500 1000]}];
Z = {'Lowest load voltage (pu)', 'Highest load voltage (pu)'};
if hasDvr, Z = [Z {'Lowest supply voltage (pu)', 'Peak DVR power (kW)', 'DVR energy used (kJ)'}]; end
Z = [Z {'Power factor at the end', 'Source current THD at the end (%)', ...
    'Current unbalance at the end (%)', 'Load voltage THD at the end (%)'}];
scopes = {'Voltage waveforms', W, repmat({[-1.5 1.5]}, 1, numel(W)); ...
          'RMS voltages', R, repmat({[0 1.3]}, 1, numel(R)); ...
          'Power quality', Q, {[0 10], [0 30], [0 1.05], [0 20], [0 20]}; ...
          'Power and devices', D, L};
order = [scopes{:, 2} Z];
assert(numel(order) == numel(find_system(S, 'SearchDepth', 1, 'BlockType', 'Outport')));
for k = 1:numel(order), set_param([S '/' order{k}], 'Port', num2str(k)); end

%% Layout: note, inputs, subsystem, scopes, displays
top = find_system(mdl, 'SearchDepth', 1, 'Type', 'Block');
top = setdiff(top, find_system(mdl, 'SearchDepth', 1, 'Tag', 'results_panel'));
pos = cell2mat(get_param(top, 'Position'));
x0 = min(pos(:, 1)); y0 = max(pos(:, 4)) + 150;
s = 80; N = numel(order);                     % pitch of the subsystem outputs
xS = x0 + 900; xs = xS + 450; xd = xs + 380;
set_param(S, 'Position', [xS y0 xS+260 y0+s*N]);
ph = get_param(S, 'PortHandles');
for k = 1:size(in, 1)
    p = get_param(ph.Inport(k), 'Position'); y = p(2);
    if isempty(in{k, 1})
        b = add(mdl, 'simulink/Sources/Constant', 'Min-max start (s)', ...
            [x0+760 y-12 x0+820 y+12], 'Value', '0.5');
    else
        b = add(mdl, 'simulink/Signal Routing/From', ['Results From ' in{k, 1}], ...
            [x0+730 y-12 x0+820 y+12], 'GotoTag', in{k, 1});
    end
    add_line(mdl, outport(b), ph.Inport(k));
end
for k = 1:N                             % name and log every result
    set_param(ph.Outport(k), 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', ...
        'DataLoggingName', order{k}, 'DataLoggingDecimateData', 'on', 'DataLoggingDecimation', '10');
end

win = [10 50 640 480; 660 50 640 480; 10 560 640 480; 660 560 640 480];
f = 1;
for g = 1:size(scopes, 1)               % each scope lines up with its results
    n = numel(scopes{g, 2});
    x = xs + 160*mod(g+1, 2);           % staggered so the names stay clear
    scope(mdl, scopes{g, 1}, num2cell(ph.Outport(f:f+n-1)), scopes{g, 2}, scopes{g, 3}, ...
        [x y0+s*(f-1) x+60 y0+s*(f-1+n)], win(g, :));
    f = f + n;
end
for k = f:N
    b = add(mdl, 'simulink/Sinks/Display', order{k}, [xd y0+s*(k-0.5)-25 xd+170 y0+s*(k-0.5)+25]);
    gp = get_param(b, 'PortHandles');
    add_line(mdl, ph.Outport(k), gp.Inport(1));
end

% Currents, straight from their Goto blocks, below the subsystem
I = {src, 'Source current (A)'};
if hasDvr || hasDst, I = [I; {'I634', 'Load current (A)'}]; end
if hasDst, I = [I; {'Idst', 'D-STATCOM current (A)'}]; end
if hasDg,  I = [I; {'Ipv', 'PV current (A)'; 'Iwind', 'Wind current (A)'}]; end
yc = y0 + s*N + 120; n = size(I, 1); fb = cell(1, n);
for k = 1:n
    y = yc + s*(k-0.5);
    b = add(mdl, 'simulink/Signal Routing/From', ['Results Scope From ' I{k, 1}], ...
        [x0+730 y-12 x0+820 y+12], 'GotoTag', I{k, 1});
    fb{k} = outport(b);
end
scope(mdl, 'Currents', fb, I(:, 2)', repmat({[-1500 1500]}, 1, n), ...
    [xS yc xS+60 yc+s*n], [1310 50 600 480]);

%% Note
t = {'HOW TO RUN THIS MODEL IN SIMULINK (no script needed)', '', ...
    '1. Press Run. The scopes open and fill in as the model runs (about a minute);', ...
    '   the displays on the right show the results.', ...
    '2. The fault: double-click ''Fault 680''. Tick the faulted phases and ''Ground''', ...
    '   (untick it for a line-to-line fault). Switching times [start end] in s;', ...
    '   [100 100.1] means no fault.', ...
    '3. The rectifier load: ''NL Breaker'', switching time = when it connects (100 = never).'};
k = 3;
if hasDvr
    k = k + 1;
    t = [t {sprintf('%d. DVR: inside ''DVR'', step time of ''DVR Enable'' = when it starts (100 = off).', k)}];
end
if hasDst
    k = k + 1;
    t = [t {sprintf('%d. D-STATCOM: inside ''D-STATCOM'', the same time in ''DST Enable'' and', k), ...
        '   ''DST Breaker''. ''DST Mode'': 1 = load compensation, 2 = voltage regulation.'}];
end
if hasDg
    k = k + 1;
    t = [t {sprintf('%d. PV and wind: ''PV Resource'' (irradiance, W/m2) and ''Wind Resource''', k), ...
        '   (wind speed, m/s) inside the plants give the resource against time.'}];
end
if hasDvr && hasDst
    k = k + 1;
    t = [t {sprintf('%d. Gains: ''DST Gains'' [bandwidth (Hz); KpDc; KiDc; KpV; KiV; Imax (A)] and', k), ...
        '   ''DVR Gains'' [KpV; KiV; limit (pu)]. Set now: the PSO gains. Hand-tuned:', ...
        '   [1500; 1; 15; 5; 500; 850] and [0.2; 200; 0.5].'}];
end
t = [t {'', 'To compare runs, for example with and without a device: Simulation tab >', ...
    'Data Inspector. Every run is kept there and the same result of different runs', ...
    'and models can be overlaid.', ...
    'Lowest and highest values are taken from ''Min-max start'' (0.5 s) on.'}];
a = Simulink.Annotation(mdl, strjoin(t, newline));
a.Position = [x0 y0 x0+640 y0+40]; a.FontSize = 14; a.Tag = 'results_panel';
a.HorizontalAlignment = 'left'; a.Interpreter = 'off';
end

function measurements(S, in, hasDvr, hasDst, hasDg)
% Fills the Measurements subsystem: one row of blocks per result.
vpk = '1/(480*sqrt(2/3))'; vb = '1/(480/sqrt(3))'; ts = '50e-6';
for k = 1:numel(in)
    add_block('built-in/Inport', [S '/' in{k}], 'Position', [20 30+60*k 50 44+60*k]);
end
row = 0;
put('simulink/Sources/Digital Clock', 'Clock', 1, 'SampleTime', ts);
put('simulink/Logic and Bit Operations/Relational Operator', 'After start', 2, 'Operator', '>=');
wire('Clock/1', 'After start/1'); wire('Min-max start/1', 'After start/2');
put('simulink/Sources/Constant', 'Reset', 3, 'Value', '0');

voltage('Load voltage', 'Load', true);
put('spsTHDLib/THD', 'Load THD', 1, 'Freq', '60', 'Ts', ts);
put('simulink/Math Operations/Gain', 'Load THD %', 2, 'Gain', '100');
wire('Load voltage/1', 'Load THD/1'); wire('Load THD/1', 'Load THD %/1');
out('Load THD %', 'Load voltage THD (%)');
out('Load THD %', 'Load voltage THD at the end (%)', 1);
unbalance('Load voltage', 'Load', 'Load voltage unbalance (%)');

put('spsTHDLib/THD', 'Current THD', 1, 'Freq', '60', 'Ts', ts);
put('simulink/Math Operations/Gain', 'Current THD %', 2, 'Gain', '100');
wire('Source current/1', 'Current THD/1'); wire('Current THD/1', 'Current THD %/1');
out('Current THD %', 'Source current THD (%)');
out('Current THD %', 'Source current THD at the end (%)', 1);
unbalance('Source current', 'Current', 'Source current unbalance (%)');
out('Current unbalance', 'Current unbalance at the end (%)', 1);
% P and Q into node 634 from the source, averaged over a cycle
put(sprintf('spsPower3phInstantaneousLib/Power\n(3ph, Instantaneous)'), 'Source PQ', 1);
put('spsMeanLib/Mean', 'Mean P', 2, 'Freq', '60', 'Ts', ts);
put('simulink/Math Operations/Gain', 'P kW', 3, 'Gain', '1e-3');
wire('Load voltage/1', 'Source PQ/1'); wire('Source current/1', 'Source PQ/2');
wire('Source PQ/1', 'Mean P/1'); wire('Mean P/1', 'P kW/1');
out('P kW', 'Active power from source (kW)');
row = row + 1;
put('spsMeanLib/Mean', 'Mean Q', 2, 'Freq', '60', 'Ts', ts);
put('simulink/Math Operations/Gain', 'Q kvar', 3, 'Gain', '1e-3');
wire('Source PQ/2', 'Mean Q/1'); wire('Mean Q/1', 'Q kvar/1');
out('Q kvar', 'Reactive power from source (kvar)');
row = row + 1;
put('simulink/Signal Routing/Mux', 'PQ', 3, 'Inputs', '2');
put('simulink/User-Defined Functions/Fcn', 'PF', 4, 'Expr', 'abs(u(1))/(sqrt(u(1)^2+u(2)^2)+1)');
wire('Mean P/1', 'PQ/1'); wire('Mean Q/1', 'PQ/2'); wire('PQ/1', 'PF/1');
out('PF', 'Source power factor');
out('PF', 'Power factor at the end', 1);

if hasDvr
    voltage('Supply voltage', 'Supply', false);
    put('simulink/Math Operations/Gain', 'DVR pu', 1, 'Gain', vpk);
    wire('DVR voltage/1', 'DVR pu/1'); out('DVR pu', 'DVR voltage (pu)');
    pick('DVR data', 'DVR P', 1, 1e-3, 'DVR power (kW)');
    running('DVR P out', 'max', 'Peak DVR power (kW)');
    pick('DVR data', 'DVR E', 2, 1e-3, 'DVR energy (kJ)');
    out('DVR E out', 'DVR energy used (kJ)', 1);
end
if hasDst, pick('D-STATCOM data', 'DST Vdc', 1, 1, 'D-STATCOM DC voltage (V)'); end
if hasDg
    put('spsRMSLib/RMS', 'RMS 675', 1, 'Freq', '60', 'RMSInit', '4160/sqrt(3)', 'Ts', ts);
    put('simulink/Math Operations/Gain', 'RMS 675 pu', 2, 'Gain', '1/(4160/sqrt(3))');   % 4.16 kV feeder
    wire('Node 675 voltage/1', 'RMS 675/1'); wire('RMS 675/1', 'RMS 675 pu/1');
    out('RMS 675 pu', 'Node 675 RMS voltage (pu)');
    pick('PV data', 'PV P', 2, 1, 'PV power (kW)');
    pick('Wind data', 'Wind P', 2, 1, 'Wind power (kW)');
end

    function voltage(sig, tag, both)
        % per-unit waveform, per-unit RMS, and the lowest (and highest) RMS
        put('simulink/Math Operations/Gain', [tag ' pu'], 1, 'Gain', vpk);
        wire([sig '/1'], [tag ' pu/1']); out([tag ' pu'], [sig ' (pu)']);
        put('spsRMSLib/RMS', [tag ' RMS'], 1, 'Freq', '60', 'RMSInit', '480/sqrt(3)', 'Ts', ts);
        put('simulink/Math Operations/Gain', [tag ' RMS pu'], 2, 'Gain', vb);
        wire([sig '/1'], [tag ' RMS/1']); wire([tag ' RMS/1'], [tag ' RMS pu/1']);
        out([tag ' RMS pu'], [strtok(sig) ' RMS voltage (pu)']);
        running([tag ' RMS pu'], 'min', ['Lowest ' lower(strtok(sig)) ' voltage (pu)']);
        if both, running([tag ' RMS pu'], 'max', ['Highest ' lower(strtok(sig)) ' voltage (pu)']); end
    end

    function unbalance(sig, tag, name)
        % negative- over positive-sequence magnitude, in percent
        put('spsSequenceAnalyzerLib/Sequence Analyzer', [tag ' sequences'], 1, ...
            'Freq', '60', 'seq', 'Positive Negative Zero', 'Ts', ts);
        put('simulink/Sinks/Terminator', [tag ' angles'], 2);
        put('simulink/User-Defined Functions/Fcn', [tag ' unbalance'], 3, ...
            'Expr', 'u(2)/(u(1)+1e-6)*100');
        wire([sig '/1'], [tag ' sequences/1']); wire([tag ' sequences/2'], [tag ' angles/1']);
        wire([tag ' sequences/1'], [tag ' unbalance/1']);
        out([tag ' unbalance'], name);
    end

    function pick(sig, tag, idx, gain, name)
        % one element of a controller's data vector, scaled
        put('simulink/Signal Routing/Selector', tag, 1, 'Indices', num2str(idx), 'InputPortWidth', '8');
        put('simulink/Math Operations/Gain', [tag ' out'], 2, 'Gain', num2str(gain));
        wire([sig '/1'], [tag '/1']); wire([tag '/1'], [tag ' out/1']);
        out([tag ' out'], name);
    end

    function running(blk, fn, name)
        % lowest or highest value from the min-max start time on
        lim = struct('min', 'inf', 'max', '-inf');
        row = row + 1;
        put('simulink/Sources/Constant', [name ' idle'], 3, 'Value', lim.(fn));
        put('simulink/Signal Routing/Switch', [name ' gate'], 4, 'Criteria', 'u2 ~= 0');
        put('simulink/Math Operations/MinMax Running Resettable', [name ' run'], 5, ...
            'Function', fn, 'vinit', lim.(fn));
        wire([blk '/1'], [name ' gate/1']); wire('After start/1', [name ' gate/2']);
        wire([name ' idle/1'], [name ' gate/3']); wire([name ' gate/1'], [name ' run/1']);
        wire('Reset/1', [name ' run/2']);
        out([name ' run'], name);
    end

    function put(lib, name, col, varargin)
        % adds a block in the given column of the current row
        if col == 1, row = row + 1; end
        x = 120 + 170*col; y = 20 + 70*row;
        add_block(lib, [S '/' name], 'Position', [x y x+120 y+40], varargin{:});
    end

    function wire(a, b)
        add_line(S, a, b, 'autorouting', 'on');
    end

    function out(blk, name, second)
        % an output of the subsystem; a second output of the same block
        % (for a display) sits further right
        x = 1300 + 150*(nargin > 2); y = 20 + 70*row;
        add_block('built-in/Outport', [S '/' name], 'Position', [x y+13 x+30 y+27]);
        wire([blk '/1'], [name '/1']);
        lh = get_param([S '/' name], 'LineHandles');
        set_param(lh.Inport, 'Name', name);
    end
end

function scope(mdl, name, src, titles, ylims, box, win)
% Adds a scope with one display per signal, fed from the given output ports.
n = numel(titles);
b = add(mdl, 'simulink/Sinks/Scope', name, box, 'NumInputPorts', num2str(n));
gp = get_param(b, 'PortHandles');
for k = 1:n, add_line(mdl, src{k}, gp.Inport(k)); end
c = get_param(b, 'ScopeConfiguration');
c.LayoutDimensions = [n 1];
c.OpenAtSimulationStart = true;
c.Position = win;
for k = 1:n
    c.ActiveDisplay = k;
    c.Title = titles{k};
    c.YLimits = ylims{k};
    c.ShowGrid = true;
end
end

function tap(mdl, var, tag)
% Puts the signal logged to the workspace as var on a global Goto block,
% placed in the first free spot next to the To Workspace block.
tw = find_system(mdl, 'LookUnderMasks', 'all', 'BlockType', 'ToWorkspace', 'VariableName', var);
tw = tw{1}; par = get_param(tw, 'Parent');
p = get_param(tw, 'Position'); w = 90; h = 24;
bl = find_system(par, 'SearchDepth', 1, 'Type', 'Block');
bl = bl(~strcmp(bl, par));
bp = cell2mat(get_param(bl, 'Position')); bp(:, 4) = bp(:, 4) + 25;   % room for names
free = @(x, y) ~any(x < bp(:, 3) & x + w > bp(:, 1) & y < bp(:, 4) & y + h + 25 > bp(:, 2));
cand = [p(3)+40 p(2); p(1) p(4)+35; p(1) p(2)-h-40; p(3)+40 p(4)+35; p(3)+40 p(2)-h-40];
k = find(arrayfun(@(i) free(cand(i, 1), cand(i, 2)), 1:size(cand, 1)), 1);
if isempty(k)                           % otherwise further down, below everything
    xy = [p(1) max(bp(:, 4)) + 20];
else
    xy = cand(k, :);
end
g = add(par, 'simulink/Signal Routing/Goto', ['Results Goto ' tag], ...
    [xy(1) xy(2) xy(1)+w xy(2)+h], 'GotoTag', tag, 'TagVisibility', 'global');
lh = get_param(tw, 'LineHandles');
src = get_param(lh.Inport, 'SrcPortHandle');
gp = get_param(g, 'PortHandles');
add_line(par, src, gp.Inport(1), 'autorouting', 'on');
end

function remove_panel(mdl)
% Deletes a panel added before, with its lines and note.
b = find_system(mdl, 'LookUnderMasks', 'all', 'Tag', 'results_panel', 'Type', 'Block');
for k = 1:numel(b)
    lh = get_param(b{k}, 'LineHandles');
    l = [lh.Inport(:); lh.Outport(:)];
    for h = unique(l(l > 0))'
        if ishandle(h), delete_line(h); end
    end
end
for k = 1:numel(b), delete_block(b{k}); end
a = find_system(mdl, 'FindAll', 'on', 'Type', 'annotation', 'Tag', 'results_panel');
for k = 1:numel(a), delete(get_param(a(k), 'Object')); end
end

function b = add(par, lib, name, pos, varargin)
b = [par '/' name];
add_block(lib, b, 'Position', pos, 'Tag', 'results_panel', varargin{:});
end

function h = outport(b)
ph = get_param(b, 'PortHandles'); h = ph.Outport(1);
end

function tf = has(mdl, name)
tf = ~isempty(find_system(mdl, 'SearchDepth', 1, 'Name', name));
end
