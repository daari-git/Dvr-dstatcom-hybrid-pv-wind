function best = optimise_gains(method, seed)
% Optimises the PI gains of the D-STATCOM and the DVR on IEEE13_full.slx.
%   method  'pso'  particle swarm (default)
%           'gwo'  grey wolf optimiser
%           'ba'   bat algorithm
%           'woa'  whale optimisation algorithm
%           'de'   differential evolution
%   seed    random seed (default 1); sets the starting population
% Each candidate is scored by one simulation with a single line-to-ground
% fault (a sag and a swell together); see full_metrics for the cost.
% Every method uses 8 agents and 6 iterations (56 simulations) and, for a
% given seed, the same starting population, which includes the hand-tuned
% gains.
% Writes results/optim_<method>_s<seed>_history.csv and updates
% results/optim_<method>_best.csv with the best gains over all seeds run.
% Run build_basecase and build_full first. Takes about 10 minutes.

if nargin < 1, method = 'pso'; end
if nargin < 2, seed = 1; end
method = lower(method);
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
n = 8; iters = 6; d = numel(x0);
clip = @(X) min(max(X, lb), ub);

hist = zeros(0, d + 1);
    function J = cost(X)
        in = Simulink.SimulationInput.empty;
        for k = 1:size(X, 1)
            in(k) = full_input('A', 'on', tl, [X(k, 1:3) 5 500 850], [X(k, 4:5) 0.5]);
        end
        out = parsim(in, 'ShowProgress', 'off', ...
            'SetupFcn', @() addpath(root, fullfile(root, 'scripts')));
        J = zeros(size(X, 1), 1);
        for k = 1:size(X, 1)
            m = full_metrics(out(k), tl);
            J(k) = m.J;
        end
        hist = [hist; X J];
        fprintf('%s seed %d: evaluated %d candidates, best so far %.3f\n', ...
            method, seed, size(hist, 1), min(hist(:, end)));
    end

rng(seed);                                      % repeatable; same start for all methods
X = [x0; lb + rand(n - 1, d) .* (ub - lb)];

switch method
    case 'pso'
        opt = optimoptions('particleswarm', 'SwarmSize', n, 'MaxIterations', iters, ...
            'UseVectorized', true, 'InitialSwarmMatrix', X, 'Display', 'off');
        particleswarm(@cost, d, lb, ub, opt);

    case 'gwo'
        % Grey wolf optimiser: every wolf moves toward the three best
        % positions found so far, with a step that shrinks from
        % exploration (a = 2) to exploitation (a = 0).
        J = cost(X);
        [Js, order] = sort(J);
        lead = X(order(1:3), :); leadJ = Js(1:3);       % alpha, beta, delta
        for it = 1:iters
            a = 2 - 2*it/iters;
            Xn = zeros(n, d);
            for k = 1:3
                A = 2*a*rand(n, d) - a;
                C = 2*rand(n, d);
                Xn = Xn + lead(k, :) - A .* abs(C .* lead(k, :) - X);
            end
            X = clip(Xn/3);
            J = cost(X);
            [Js, order] = sort([leadJ; J]);
            pool = [lead; X];
            lead = pool(order(1:3), :); leadJ = Js(1:3);
        end

    case 'ba'
        % Bat algorithm: each bat flies toward the best position at a
        % random frequency, or takes a small random walk around the best.
        % A move is kept if it is better and passes the loudness test;
        % loudness then falls and the pulse rate rises.
        fmax = 2; A = 0.9*ones(n, 1); alpha = 0.9; r0 = 0.9; gamma = 0.9;
        J = cost(X); V = zeros(n, d);
        [Jb, ib] = min(J); xb = X(ib, :);
        for it = 1:iters
            r = r0*(1 - exp(-gamma*it));
            V = V + (X - xb) .* (fmax*rand(n, 1));
            Xn = X + V;
            walk = rand(n, 1) > r;
            Xn(walk, :) = xb + 0.1*mean(A)*(2*rand(nnz(walk), d) - 1) .* (ub - lb);
            Xn = clip(Xn);
            Jn = cost(Xn);
            keep = Jn <= J & rand(n, 1) < A;
            X(keep, :) = Xn(keep, :); J(keep) = Jn(keep);
            A(keep) = alpha*A(keep);
            [Jm, im] = min(Jn);
            if Jm < Jb, Jb = Jm; xb = Xn(im, :); end
        end

    case 'woa'
        % Whale optimisation algorithm: each whale either encircles the
        % best position (or a random whale while exploring) or moves
        % along a spiral toward the best.
        J = cost(X);
        [Jb, ib] = min(J); xb = X(ib, :);
        for it = 1:iters
            a = 2 - 2*it/iters;
            Xn = X;
            for k = 1:n
                A = 2*a*rand - a; C = 2*rand; l = 2*rand - 1;
                if rand < 0.5
                    if abs(A) < 1, ref = xb; else, ref = X(randi(n), :); end
                    Xn(k, :) = ref - A*abs(C*ref - X(k, :));
                else
                    Xn(k, :) = abs(xb - X(k, :)) * exp(l) * cos(2*pi*l) + xb;
                end
            end
            X = clip(Xn);
            J = cost(X);
            [Jm, im] = min(J);
            if Jm < Jb, Jb = Jm; xb = X(im, :); end
        end

    case 'de'
        % Differential evolution (rand/1/bin): each trial vector is a
        % third member plus the scaled difference of two others, crossed
        % with the current member; it replaces the member if it is better.
        F = 0.5; CR = 0.9;
        J = cost(X);
        for it = 1:iters
            U = X;
            for k = 1:n
                others = setdiff(1:n, k);
                pick = others(randperm(n - 1, 3));
                v = X(pick(1), :) + F*(X(pick(2), :) - X(pick(3), :));
                cross = rand(1, d) < CR; cross(randi(d)) = true;
                U(k, cross) = v(cross);
            end
            U = clip(U);
            Ju = cost(U);
            better = Ju < J;
            X(better, :) = U(better, :); J(better) = Ju(better);
        end

    otherwise
        error('method must be pso, gwo, ba, woa or de');
end

writetable(array2table(hist, 'VariableNames', [names {'cost'}]), ...
    fullfile(outd, sprintf('optim_%s_s%d_history.csv', method, seed)));
[Jbest, ib] = min(hist(:, end)); best = hist(ib, 1:d);
fprintf('%s seed %d: hand-tuned cost %.3f, optimised cost %.3f\n', ...
    method, seed, hist(1, end), Jbest);

% Best gains for this method over every seed run so far
f = dir(fullfile(outd, sprintf('optim_%s_s*_history.csv', method)));
all = [];
for k = 1:numel(f), all = [all; readmatrix(fullfile(f(k).folder, f(k).name))]; end %#ok<AGROW>
[~, ib] = min(all(:, end));
writematrix(all(ib, 1:d), fullfile(outd, sprintf('optim_%s_best.csv', method)));
end
