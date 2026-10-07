function T = check_strategies(n, seed)
% Runs a few scenarios under every coordination strategy, to see whether
% the best strategy changes from one scenario to another. If one strategy
% wins everywhere, a fixed rule is enough and no supervisor is needed.
% Writes results/strategy_check.csv. Run build_coord first.
if nargin < 1, n = 12; end
if nargin < 2, seed = 7; end
root = fileparts(fileparts(mfilename('fullpath')));
[S, tl] = coord_scenarios(n, seed);
[strat, names] = coord_strategies();
ns = size(strat, 1);
in = Simulink.SimulationInput.empty;
for k = 1:n
    for s = 1:ns, in(end+1) = coord_input(S(k), strat(s, :), tl); end %#ok<AGROW>
end
out = parsim(in, 'ShowProgress', 'off', 'SetupFcn', @() addpath(root, fullfile(root, 'scripts')));

rows = {};
for k = 1:n
    J = nan(1, ns); e = nan(1, ns); L = nan(1, ns); B = nan(1, ns);
    for s = 1:ns
        m = coord_metrics(out((k-1)*ns + s), S(k), tl);
        J(s) = m.J;
        if ~isnan(m.J), e(s) = m.batt_empty; L(s) = m.Jload; B(s) = m.Jbus; end
        if s == 1, m1 = m; end
    end
    [~, b] = min(J);
    rows(end+1, :) = {k, [S(k).fph '-' S(k).gnd], S(k).loc, S(k).Rf, S(k).Ecap, S(k).G, ...
        m1.depth, m1.Vbus_min, m1.duration, m1.Ifault, J, L, B, e, b}; %#ok<AGROW>
end
T = cell2table(rows, 'VariableNames', {'id', 'fault', 'loc', 'Rf', 'Ecap_kJ', 'G', ...
    'depth_pu', 'Vbus675_min', 'duration_s', 'Ifault_A', 'J', 'Jload', 'Jbus', 'batt_empty', 'best'});
writetable(T, fullfile(root, 'results', 'strategy_check.csv'));
disp(T);
fprintf('Best strategy counts:\n');
for s = 1:ns, fprintf('  %d  %-38s %d\n', s, names{s}, nnz(T.best == s)); end
end
