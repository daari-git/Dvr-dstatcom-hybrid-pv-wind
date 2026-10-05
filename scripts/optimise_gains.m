function best = optimise_gains()
% Particle swarm optimisation of the PI gains of the D-STATCOM and the DVR
% on IEEE13_full.slx. Each candidate is scored by one simulation with a
% single line-to-ground fault (a sag and a swell together); see
% full_metrics for the cost. Writes results/optim_best.csv,
% results/optim_history.csv and results/optim_convergence.png.
% Run build_basecase and build_full first. Takes roughly half an hour.

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

hist = zeros(0, numel(x0) + 1);
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
        fprintf('evaluated %d candidates, best so far %.3f\n', size(hist, 1), min(hist(:, end)));
    end

rng(1);                                         % repeatable run
swarm = 8;
init = [x0; lb + rand(swarm - 1, numel(x0)) .* (ub - lb)];
opt = optimoptions('particleswarm', 'SwarmSize', swarm, 'MaxIterations', 6, ...
    'UseVectorized', true, 'InitialSwarmMatrix', init, 'Display', 'iter');
[best, Jbest] = particleswarm(@cost, numel(x0), lb, ub, opt);

writematrix(best, fullfile(outd, 'optim_best.csv'));
H = array2table(hist, 'VariableNames', [names {'cost'}]);
writetable(H, fullfile(outd, 'optim_history.csv'));
fprintf('baseline cost %.3f, optimised cost %.3f\n', hist(1, end), Jbest);
disp(array2table([x0; best], 'VariableNames', names, 'RowNames', {'hand_tuned', 'optimised'}));

% Convergence: best cost found after each swarm evaluation
ink = [0.25 0.25 0.25];
it = (0:size(hist, 1)/swarm - 1)';
bestSoFar = cummin(min(reshape(hist(:, end), swarm, []), [], 1))';
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 760 380]);
ax = axes(fig); hold(ax, 'on');
plot(ax, it, bestSoFar, '-o', 'Color', [42 120 214]/255, 'LineWidth', 2, ...
    'MarkerFaceColor', [42 120 214]/255, 'MarkerSize', 6);
yline(ax, hist(1, end), ':', 'hand-tuned gains', 'Color', ink, 'LabelHorizontalAlignment', 'right');
xlabel(ax, 'Iteration'); ylabel(ax, 'Best cost');
title(ax, 'Particle swarm optimisation of the PI gains', 'Color', ink);
grid(ax, 'on'); box(ax, 'off'); ax.GridColor = [0.85 0.85 0.85]; ax.GridAlpha = 1;
ax.XColor = ink; ax.YColor = ink; xticks(ax, it);
exportgraphics(fig, fullfile(outd, 'optim_convergence.png'), 'Resolution', 200);
close(fig);
end
