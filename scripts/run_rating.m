function run_rating()
% Placement and rating study on the combined model, with the hand-tuned
% gains:
%   placement  D-STATCOM on the load side of the DVR (IEEE13_full) against
%              the supply side (IEEE13_full_supply), four faults
%   DVR        injection limit of 0.2 to 0.5 pu, four faults
%   D-STATCOM  current limit of 200 to 850 A peak
% Writes results/placement_summary.csv, results/rating_dvr.csv,
% results/rating_dstatcom.csv and a figure for each rating sweep.
% Run build_basecase, build_full and build_full('supply') first.

root = fileparts(fileparts(mfilename('fullpath')));
outd = fullfile(root, 'results');
if ~exist(outd, 'dir'), mkdir(outd); end

tl = struct('tNL', 0.3, 'tDev', 0.4, 'tOn', 0.8, 'tOff', 1.0, 'tStop', 1.2, ...
    'tSteady', 0.7, 'tFault', 0.9);
scen = {'fault_LLLG', 'ABC', 'on'; 'fault_LG_A', 'A', 'on'; ...
        'fault_LL_BC', 'BC', 'off'; 'fault_LLG_BC', 'BC', 'on'};
gD = [1500; 1; 15; 5; 500; 850]; gV = [0.2; 200; 0.5];
vlim = [0.2 0.3 0.4 0.5];
ilim = [200 400 600 850];
place = {'load_side', 'IEEE13_full'; 'supply_side', 'IEEE13_full_supply'};

in = Simulink.SimulationInput.empty; tag = {};
for p = 1:2
    for s = 1:4
        in(end+1) = full_input(scen{s, 2}, scen{s, 3}, tl, gD, gV, place{p, 2}); %#ok<AGROW>
        tag(end+1, :) = {'placement', place{p, 1}, scen{s, 1}}; %#ok<AGROW>
    end
end
for v = vlim(1:end-1)                    % 0.5 pu is the load-side placement run
    for s = 1:4
        in(end+1) = full_input(scen{s, 2}, scen{s, 3}, tl, gD, [gV(1:2); v]); %#ok<AGROW>
        tag(end+1, :) = {'dvr', v, scen{s, 1}}; %#ok<AGROW>
    end
end
for i = ilim(1:end-1)                    % 850 A is the load-side placement run
    in(end+1) = full_input('A', 'on', tl, [gD(1:5); i], gV); %#ok<AGROW>
    tag(end+1, :) = {'dst', i, 'fault_LG_A'}; %#ok<AGROW>
end
% parsim takes one model at a time
sup = strcmp(tag(:, 2), 'supply_side')';
setup = @() addpath(root, fullfile(root, 'scripts'));
out = cell(1, numel(in));
out(~sup) = num2cell(parsim(in(~sup), 'ShowProgress', 'off', 'SetupFcn', setup));
out(sup)  = num2cell(parsim(in(sup),  'ShowProgress', 'off', 'SetupFcn', setup));
m = cellfun(@(o) full_metrics(o, tl), out);

%% Placement
k = find(strcmp(tag(:, 1), 'placement'))';
P = table(tag(k, 2), tag(k, 3), [m(k).Vl_fault]', [m(k).eV]', [m(k).THDv]', [m(k).TDD]', ...
    [m(k).I2]', [m(k).PF]', [m(k).Pdvr_kW]', [m(k).Sdvr_kVA]', [m(k).Vinj_max]', ...
    [m(k).Sdst_kVA]', [m(k).J]', 'VariableNames', {'dstatcom', 'scenario', 'Vl_fault_abc_pu', ...
    'Vl_error_pct', 'THDv_max_pct', 'TDD_pct', 'I2_pct_of_rated', 'PF', 'Pdvr_kW', ...
    'Sdvr_kVA', 'Vinj_max_pu', 'Sdst_kVA', 'cost'});
P.Vl_fault_abc_pu = reshape([m(k).Vl_fault], 3, [])';
writetable(P, fullfile(outd, 'placement_summary.csv')); disp(P);

%% DVR injection limit
kl = find(strcmp(tag(:, 1), 'placement') & strcmp(tag(:, 2), 'load_side'))';
kd = [find(strcmp(tag(:, 1), 'dvr'))' kl];
lim = [cell2mat(tag(strcmp(tag(:, 1), 'dvr'), 2)); 0.5*ones(4, 1)];
vf = reshape([m(kd).Vl_fault], 3, [])';
D = table(lim, tag(kd, 3), min(vf, [], 2), max(vf, [], 2), [m(kd).Vunb_fault]', ...
    [m(kd).Vinj_max]', [m(kd).Sdvr_kVA]', [m(kd).Pdvr_kW]', 'VariableNames', ...
    {'limit_pu', 'scenario', 'Vl_min_pu', 'Vl_max_pu', 'Vl_unb_pct', 'Vinj_max_pu', ...
    'Sdvr_kVA', 'Pdvr_kW'});
D = sortrows(D, {'limit_pu', 'scenario'});
writetable(D, fullfile(outd, 'rating_dvr.csv')); disp(D);

%% D-STATCOM current limit
ks = [find(strcmp(tag(:, 1), 'dst'))' kl(2)];        % kl(2) is the LG fault at 850 A
lim = [cell2mat(tag(strcmp(tag(:, 1), 'dst'), 2)); 850];
S = table(lim, lim/sqrt(2)*480*sqrt(3)/1e3, [m(ks).PF]', [m(ks).Q_kvar]', [m(ks).TDD]', ...
    [m(ks).I2]', [m(ks).THDv]', [m(ks).Sdst_kVA]', [m(ks).Idst_peak]', 'VariableNames', ...
    {'limit_A_peak', 'rating_kVA', 'PF', 'Q_source_kvar', 'TDD_pct', 'I2_pct_of_rated', ...
    'THDv_max_pct', 'Sdst_used_kVA', 'Idst_peak_A'});
writetable(S, fullfile(outd, 'rating_dstatcom.csv')); disp(S);

%% Figures
ink = [0.25 0.25 0.25];
col = [42 120 214; 235 104 52; 27 175 122; 237 161 0] / 255;
names = {'Three-phase-to-ground', 'Single line-to-ground', 'Line-to-line', 'Double line-to-ground'};

fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 820 400]);
ax = axes(fig); hold(ax, 'on');
for s = 1:4
    r = D(strcmp(D.scenario, scen{s, 1}), :);
    plot(ax, r.limit_pu, r.Vl_min_pu, '-o', 'Color', col(s, :), 'LineWidth', 2, ...
        'MarkerFaceColor', col(s, :), 'MarkerSize', 6);
end
yline(ax, 0.9, ':', '0.9 pu sag limit', 'Color', ink, ...
    'LabelHorizontalAlignment', 'left', 'HandleVisibility', 'off');
xlabel(ax, 'DVR injection limit (pu)'); ylabel(ax, 'Lowest load phase voltage in the fault (pu)');
title(ax, 'DVR rating: load voltage against injection limit', 'Color', ink);
legend(ax, names, 'Location', 'eastoutside', 'Box', 'off');
xticks(ax, vlim); ylim(ax, [0.6 1.05]); style(ax, ink);
exportgraphics(fig, fullfile(outd, 'rating_dvr.png'), 'Resolution', 200); close(fig);

fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 760 520]);
tlo = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tlo, 'D-STATCOM rating: source-side quality against current limit', ...
    'FontWeight', 'bold', 'Color', ink);
S = sortrows(S, 'rating_kVA');
ax = nexttile; plot(ax, S.rating_kVA, S.Q_source_kvar, '-o', 'Color', col(1, :), ...
    'LineWidth', 2, 'MarkerFaceColor', col(1, :), 'MarkerSize', 6);
ylabel(ax, 'Reactive power from source (kvar)'); style(ax, ink);
ax = nexttile; plot(ax, S.rating_kVA, S.I2_pct_of_rated, '-o', 'Color', col(1, :), ...
    'LineWidth', 2, 'MarkerFaceColor', col(1, :), 'MarkerSize', 6);
ylabel(ax, 'Negative-sequence current (% of rating)'); xlabel(ax, 'D-STATCOM rating (kVA)');
style(ax, ink);
exportgraphics(fig, fullfile(outd, 'rating_dstatcom.png'), 'Resolution', 200); close(fig);
end

function style(ax, ink)
grid(ax, 'on'); box(ax, 'off');
ax.GridColor = [0.85 0.85 0.85]; ax.GridAlpha = 1;
ax.XColor = ink; ax.YColor = ink; ax.FontSize = 10;
end
