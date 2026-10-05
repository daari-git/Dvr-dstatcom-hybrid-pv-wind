function build_full()
% Builds IEEE13_full.slx: the base-case feeder with the DVR, the D-STATCOM,
% the PV plant and the wind plant together. The D-STATCOM and the PV plant
% are on the load side of the DVR.
% Run build_basecase first.

src = 'IEEE13_basecase';
dst = 'IEEE13_full';
root = fileparts(fileparts(mfilename('fullpath')));

if bdIsLoaded(dst), close_system(dst, 0); end
if bdIsLoaded(src), close_system(src, 0); end
load_system(fullfile(root, [src '.slx']));
save_system(src, fullfile(root, [dst '.slx']));   % loaded model is now dst

add_dvr(dst);
add_dstatcom(dst);
add_dg(dst);

save_system(dst);
close_system(dst, 0);
fprintf('Built %s\n', fullfile(root, [dst '.slx']));
end
