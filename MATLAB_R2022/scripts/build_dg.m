function build_dg()
% Builds IEEE13_dg.slx: the base-case feeder plus the PV and wind plants,
% with no DVR or D-STATCOM. Run build_basecase first.

src = 'IEEE13_basecase';
dst = 'IEEE13_dg';
root = fileparts(fileparts(mfilename('fullpath')));

if bdIsLoaded(dst), close_system(dst, 0); end
if bdIsLoaded(src), close_system(src, 0); end
load_system(fullfile(root, [src '.slx']));
save_system(src, fullfile(root, [dst '.slx']));   % loaded model is now dst

add_dg(dst);

save_system(dst);
close_system(dst, 0);
fprintf('Built %s\n', fullfile(root, [dst '.slx']));
end
