function T = compare_optimisers(seeds)
% Runs the five optimisers on the same problem for each seed and compares
% them. Runs already saved in results/ are not repeated.
% Writes results/optim_comparison.csv and results/optim_convergence.png.
% Each run takes about 10 minutes: 15 runs for the default three seeds.

if nargin < 1, seeds = 1:3; end
root = fileparts(fileparts(mfilename('fullpath')));
outd = fullfile(root, 'results');
meth = {'pso', 'gwo', 'ba', 'woa', 'de'};
lab  = {'Particle swarm', 'Grey wolf', 'Bat', 'Whale', 'Differential evolution'};
n = 8;                                           % agents per method

for s = seeds
    for k = 1:numel(meth)
        f = fullfile(outd, sprintf('optim_%s_s%d_history.csv', meth{k}, s));
        if ~exist(f, 'file'), optimise_gains(meth{k}, s); end
    end
end

% Final cost of every run, and the best-so-far curve averaged over seeds
final = zeros(numel(meth), numel(seeds)); curve = cell(numel(meth), 1); base = NaN;
for k = 1:numel(meth)
    c = [];
    for j = 1:numel(seeds)
        J = readmatrix(fullfile(outd, sprintf('optim_%s_s%d_history.csv', meth{k}, seeds(j))));
        J = J(:, end); base = J(1);
        c(:, j) = cummin(min(reshape(J, n, []), [], 1))'; %#ok<AGROW>
    end
    final(k, :) = c(end, :); curve{k} = mean(c, 2);
end

T = table(lab', mean(final, 2), std(final, 0, 2), min(final, [], 2), max(final, [], 2), ...
    100*(base - mean(final, 2))/base, ...
    'VariableNames', {'method', 'mean_cost', 'std_cost', 'best_cost', 'worst_cost', ...
    'mean_reduction_pct'});
for j = 1:numel(seeds), T.(sprintf('seed_%d', seeds(j))) = final(:, j); end
T = sortrows(T, 'mean_cost');
writetable(T, fullfile(outd, 'optim_comparison.csv'));
fprintf('hand-tuned cost %.3f\n', base); disp(T);

ink = [0.25 0.25 0.25];
col = [42 120 214; 235 104 52; 27 175 122; 237 161 0; 232 123 164] / 255;
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 820 400]);
ax = axes(fig); hold(ax, 'on');
for k = 1:numel(meth)
    plot(ax, (0:numel(curve{k}) - 1)', curve{k}, '-o', 'Color', col(k, :), 'LineWidth', 2, ...
        'MarkerFaceColor', col(k, :), 'MarkerSize', 5);
end
yline(ax, base, ':', 'hand-tuned gains', 'Color', ink, ...
    'LabelHorizontalAlignment', 'right', 'HandleVisibility', 'off');
xlabel(ax, 'Iteration'); ylabel(ax, sprintf('Best cost, mean of %d seeds', numel(seeds)));
title(ax, 'Optimisation of the PI gains: five methods', 'Color', ink);
legend(ax, lab, 'Location', 'eastoutside', 'Box', 'off');
grid(ax, 'on'); box(ax, 'off'); ax.GridColor = [0.85 0.85 0.85]; ax.GridAlpha = 1;
ax.XColor = ink; ax.YColor = ink;
exportgraphics(fig, fullfile(outd, 'optim_convergence.png'), 'Resolution', 200);
close(fig);
end
