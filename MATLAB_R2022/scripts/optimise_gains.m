function best = optimise_gains(method)
% Optimises the PI gains of the D-STATCOM and the DVR on IEEE13_full.slx.
%   method  'pso' particle swarm (default) or 'gwo' grey wolf optimiser
% Each candidate is scored by one simulation with a single line-to-ground
% fault (a sag and a swell together); see full_metrics for the cost.
% Both methods use 8 agents, 6 iterations and the same starting population,
% which includes the hand-tuned gains.
% Writes results/optim_<method>_best.csv, results/optim_<method>_history.csv
% and results/optim_convergence.png (all methods run so far).
% Run build_basecase and build_full first. Takes about 10 minutes.

if nargin < 1, method = 'pso'; end
root = fileparts(fileparts(mfilename('fullpath')));
outd = fullfile(root, 'results');
if ~exist(outd, 'dir'), mkdir(outd); end

% x = [D-STATCOM current-loop bandwidth (Hz), KpDc, KiDc, DVR KpV, DVR KiV]
names = {'dst_fI_Hz', 'dst_KpDc', 'dst_KiDc', 'dvr_KpV', 'dvr_KiV'};
x0 = [1500 1 15 0.2 200];                       % hand-tuned baseline
lb = [ 500 0.2   2 0    20];
ub = [2500 5   200 0.9 2000];
tl = struct('tNL', 0.3, 'tDev', 0.35, 'tOn', 0.55, 'tOff', 0.7, 'tStop', 0.8, ...
    'tSteady', 0.49, 'tFault', 0.62);
agents = 8; iters = 6; d = numel(x0);

hist = zeros(0, d + 1);
    function J = cost(X)
        in = Simulink.SimulationInput.empty;
        for k = 1:size(X, 1)
            in(k) = full_input('A', 'on', tl, [X(k, 1:3) 5 500], X(k, 4:5));
        end
        out = parsim(in, 'ShowProgress', 'off', ...
            'SetupFcn', @() addpath(root, fullfile(root, 'scripts')));
        J = zeros(size(X, 1), 1);
        for k = 1:size(X, 1)
            m = full_metrics(out(k), tl);
            J(k) = m.J;
        end
        hist = [hist; X J];
        fprintf('%s: evaluated %d candidates, best so far %.3f\n', ...
            method, size(hist, 1), min(hist(:, end)));
    end

rng(1);                                         % repeatable, same start for both
init = [x0; lb + rand(agents - 1, d) .* (ub - lb)];

switch lower(method)
    case 'pso'
        opt = optimoptions('particleswarm', 'SwarmSize', agents, 'MaxIterations', iters, ...
            'UseVectorized', true, 'InitialSwarmMatrix', init, 'Display', 'iter');
        [best, Jbest] = particleswarm(@cost, d, lb, ub, opt);
    case 'gwo'
        % Grey wolf optimiser (Mirjalili et al., 2014): every wolf moves
        % toward the three best positions found so far, with a step that
        % shrinks from exploration (a = 2) to exploitation (a = 0).
        X = init; J = cost(X);
        [Js, order] = sort(J);
        lead = X(order(1:3), :); leadJ = Js(1:3);       % alpha, beta, delta
        for it = 1:iters
            a = 2 - 2*it/iters;
            Xn = zeros(size(X));
            for k = 1:3
                A = 2*a*rand(agents, d) - a;
                C = 2*rand(agents, d);
                Xn = Xn + lead(k, :) - A .* abs(C .* lead(k, :) - X);
            end
            X = min(max(Xn/3, lb), ub);
            J = cost(X);
            [Js, order] = sort([leadJ; J]);
            pool = [lead; X];
            lead = pool(order(1:3), :); leadJ = Js(1:3);
        end
        best = lead(1, :); Jbest = leadJ(1);
    otherwise
        error('method must be ''pso'' or ''gwo''');
end

writematrix(best, fullfile(outd, sprintf('optim_%s_best.csv', method)));
writetable(array2table(hist, 'VariableNames', [names {'cost'}]), ...
    fullfile(outd, sprintf('optim_%s_history.csv', method)));
fprintf('%s: baseline cost %.3f, optimised cost %.3f\n', method, hist(1, end), Jbest);
disp(array2table([x0; best], 'VariableNames', names, 'RowNames', {'hand_tuned', method}));

plot_convergence(outd, agents);
end

function plot_convergence(outd, agents)
% Best cost found after each evaluation of the population, per method
ink = [0.25 0.25 0.25];
meth = {'pso', 'gwo'}; lab = {'Particle swarm', 'Grey wolf'};
col = [42 120 214; 235 104 52] / 255;
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 760 380]);
ax = axes(fig); hold(ax, 'on'); used = {}; base = NaN;
for k = 1:numel(meth)
    f = fullfile(outd, sprintf('optim_%s_history.csv', meth{k}));
    if ~exist(f, 'file'), continue; end
    J = readmatrix(f); J = J(:, end); base = J(1);
    b = cummin(min(reshape(J, agents, []), [], 1))';
    plot(ax, (0:numel(b) - 1)', b, '-o', 'Color', col(k, :), 'LineWidth', 2, ...
        'MarkerFaceColor', col(k, :), 'MarkerSize', 6);
    used{end+1} = lab{k}; %#ok<AGROW>
end
yline(ax, base, ':', 'hand-tuned gains', 'Color', ink, ...
    'LabelHorizontalAlignment', 'right', 'HandleVisibility', 'off');
xlabel(ax, 'Iteration'); ylabel(ax, 'Best cost');
title(ax, 'Optimisation of the PI gains', 'Color', ink);
legend(ax, used, 'Location', 'eastoutside', 'Box', 'off');
grid(ax, 'on'); box(ax, 'off'); ax.GridColor = [0.85 0.85 0.85]; ax.GridAlpha = 1;
ax.XColor = ink; ax.YColor = ink;
exportgraphics(fig, fullfile(outd, 'optim_convergence.png'), 'Resolution', 200);
close(fig);
end
