function T = generate_dataset(nScen, seed)
% Step 8: simulates random fault scenarios on IEEE13_coord.slx, each under
% the four coordination strategies, and writes one row per scenario to
% results/dataset.csv: the scenario, the features measured in the first half
% cycle, the outcome of every strategy and the best strategy.
%   nScen  number of scenarios (default 400)
%   seed   random seed for the scenario list (default 1)
% Scenarios already in the file are not repeated, so an interrupted run can
% be restarted. Each scenario takes about 50 s on four cores.
% Run build_basecase and build_coord first.

if nargin < 1, nScen = 400; end
if nargin < 2, seed = 1; end
root = fileparts(fileparts(mfilename('fullpath')));
outd = fullfile(root, 'results');
file = fullfile(outd, 'dataset.csv');
[S, tl] = coord_scenarios(nScen, seed);
strat = coord_strategies();
ns = size(strat, 1);

done = [];
if exist(file, 'file'), T = readtable(file); done = T.id'; else, T = table(); end
todo = setdiff(1:nScen, done);
chunk = 8;                                    % scenarios per parallel batch
setup = @() addpath(root, fullfile(root, 'scripts'));
for c = 1:chunk:numel(todo)
    ids = todo(c:min(c + chunk - 1, numel(todo)));
    in = Simulink.SimulationInput.empty;
    for id = ids
        for s = 1:ns, in(end+1) = coord_input(S(id), strat(s, :), tl); end %#ok<AGROW>
    end
    out = parsim(in, 'ShowProgress', 'off', 'SetupFcn', setup);
    for k = 1:numel(ids)
        id = ids(k); o = out((k-1)*ns + (1:ns));
        row = dataset_row(id, S(id), o, tl);
        T = [T; row]; %#ok<AGROW>
    end
    writetable(T, file);
    fprintf('dataset: %d of %d scenarios done\n', height(T), nScen);
end
end

function row = dataset_row(id, sc, o, tl)
ns = numel(o);
[m, feat, names] = coord_metrics(o(1), sc, tl);       % features from strategy 1
J = nan(1, ns); extra = nan(ns, 4);
for s = 1:ns
    ms = coord_metrics(o(s), sc, tl);
    J(s) = ms.J;
    if ~isnan(ms.J), extra(s, :) = [ms.Jload, ms.Jbus, ms.Edvr_kJ, ms.batt_empty]; end
end
[~, best] = min(J);
types = {'ABC', 'A', 'BC'}; g = strcmp(sc.gnd, 'on');
cls = find(strcmp(types, sc.fph)); if cls == 3 && g, cls = 4; end   % 1 LLLG 2 LG 3 LL 4 LLG
row = table(id, string(sc.fph), string(sc.gnd), sc.loc, sc.Rf, sc.tOn, sc.G, sc.wind, ...
    'VariableNames', {'id', 'phases', 'ground', 'location', 'Rf_ohm', 'tOn_s', 'G_Wm2', 'wind_ms'});
row = [row, array2table(feat, 'VariableNames', names)];
row.fault_class = cls; row.depth_pu = m.depth; row.duration_s = m.duration;
row.Ifault_A = m.Ifault; row.t_detect_s = m.t_detect;
for s = 1:ns
    row.(sprintf('J_s%d', s)) = J(s);
    row.(sprintf('Jload_s%d', s)) = extra(s, 1);
    row.(sprintf('Jbus_s%d', s)) = extra(s, 2);
    row.(sprintf('Edvr_s%d', s)) = extra(s, 3);
    row.(sprintf('empty_s%d', s)) = extra(s, 4);
end
row.best = best;
end
