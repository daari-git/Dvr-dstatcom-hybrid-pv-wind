function export_r2022()
% Refreshes the MATLAB_R2022 folder: the five models saved in R2022a format
% (which R2022a and R2022b can open), with a copy of the benchmark model,
% the scripts and the optimised gains. Run it after the models or scripts
% change, from a MATLAB release newer than R2022a.

root = fileparts(fileparts(mfilename('fullpath')));
dst = fullfile(root, 'MATLAB_R2022');
if ~exist(fullfile(dst, 'results'), 'dir'), mkdir(fullfile(dst, 'results')); end

models = {'IEEE13_basecase', 'IEEE13_dstatcom', 'IEEE13_dvr', 'IEEE13_dg', 'IEEE13_full'};
for k = 1:numel(models)
    m = models{k};
    if bdIsLoaded(m), close_system(m, 0); end
    load_system(fullfile(root, [m '.slx']));
    Simulink.exportToVersion(m, fullfile(dst, [m '.slx']), 'R2022A', 'BreakUserLinks', false);
    close_system(m, 0);
    fprintf('Exported %s\n', m);
end
copyfile(fullfile(root, 'IEEE13bus_v2019b_Discrete.slx'), dst);
copyfile(fullfile(root, 'scripts'), fullfile(dst, 'scripts'));
best = dir(fullfile(root, 'results', 'optim_*_best.csv'));
for k = 1:numel(best)
    copyfile(fullfile(best(k).folder, best(k).name), fullfile(dst, 'results'));
end
end
