function build_full(side)
% Builds the combined model: the base-case feeder with the DVR, the
% D-STATCOM, the PV plant and the wind plant together.
%   side  'load' (default) builds IEEE13_full.slx, with the D-STATCOM on the
%         load side of the DVR; 'supply' builds IEEE13_full_supply.slx, with
%         it on the supply side. The PV plant is on the load side in both.
% Run build_basecase first.

if nargin < 1, side = 'load'; end
src = 'IEEE13_basecase';
dst = 'IEEE13_full';
if strcmp(side, 'supply'), dst = 'IEEE13_full_supply'; end
root = fileparts(fileparts(mfilename('fullpath')));

if bdIsLoaded(dst), close_system(dst, 0); end
if bdIsLoaded(src), close_system(src, 0); end
load_system(fullfile(root, [src '.slx']));
save_system(src, fullfile(root, [dst '.slx']));   % loaded model is now dst

if strcmp(side, 'supply')
    add_dvr(dst, 'I634');
else
    add_dvr(dst);
end
add_dstatcom(dst, side);
add_dg(dst);

save_system(dst);
close_system(dst, 0);
fprintf('Built %s\n', fullfile(root, [dst '.slx']));
end
