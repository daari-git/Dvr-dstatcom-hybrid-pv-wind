function build_panels(folder)
% Prepares the step models to be run from the Simulink Run button, without
% any script: sets a default scenario in each and adds the results panel
% (add_panel), then saves them. The feeder and device layout is not
% changed; the panel goes below it.
% Default scenario: single line-to-ground fault on phase A at node 680 from
% 0.6 s to 0.8 s, rectifier load from 0.3 s, DVR and D-STATCOM (load
% compensation) from 0.4 s, stop at 1.0 s. The combined model gets the PSO
% gains. The run scripts set their own scenario, so they are not affected.
%   build_panels           the models in the project folder
%   build_panels(folder)   the copies in another folder

root = fileparts(fileparts(mfilename('fullpath')));
if nargin < 1, folder = root; end
models = {'IEEE13_basecase', 'IEEE13_dstatcom', 'IEEE13_dvr', 'IEEE13_dg', 'IEEE13_full'};
x = readmatrix(fullfile(root, 'results', 'optim_pso_best.csv'));

for k = 1:numel(models)
    m = models{k};
    if bdIsLoaded(m), close_system(m, 0); end
    load_system(fullfile(folder, [m '.slx']));
    set_param([m '/Fault 680'], 'FaultA', 'on', 'FaultB', 'off', 'FaultC', 'off', ...
        'GroundFault', 'on', 'SwitchTimes', '[0.6 0.8]');
    set_param([m '/NL Breaker'], 'SwitchTimes', '[0.3]');
    if ~isempty(find_system(m, 'SearchDepth', 1, 'Name', 'D-STATCOM'))
        set_param([m '/D-STATCOM/DST Breaker'], 'SwitchTimes', '[0.4]');
        set_param([m '/D-STATCOM/DST Enable'], 'Time', '0.4');
        set_param([m '/D-STATCOM/DST Mode'], 'Value', '1');
    end
    if ~isempty(find_system(m, 'SearchDepth', 1, 'Name', 'DVR'))
        set_param([m '/DVR/DVR Enable'], 'Time', '0.4');
    end
    if strcmp(m, 'IEEE13_full')
        set_param([m '/D-STATCOM/DST Gains'], 'Value', mat2str([x(1:3) 5 500 850]', 6));
        set_param([m '/DVR/DVR Gains'], 'Value', mat2str([x(4:5) 0.5]', 6));
    end
    set_param(m, 'StopTime', '1.0');
    add_panel(m);
    save_system(m);
    close_system(m, 0);
    fprintf('Panel added to %s\n', m);
end
end
