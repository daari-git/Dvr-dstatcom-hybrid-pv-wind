function build_coord()
% Builds IEEE13_coord.slx: the combined model (DVR, D-STATCOM, PV and wind)
% with relay-timed faults at three locations. This is the model for the
% coordination strategies and the dataset. Run build_basecase first.

src = 'IEEE13_basecase';
dst = 'IEEE13_coord';
root = fileparts(fileparts(mfilename('fullpath')));

if bdIsLoaded(dst), close_system(dst, 0); end
if bdIsLoaded(src), close_system(src, 0); end
load_system(fullfile(root, [src '.slx']));
save_system(src, fullfile(root, [dst '.slx']));   % loaded model is now dst

add_dvr(dst);
add_dstatcom(dst);
add_dg(dst);
add_relay(dst);

save_system(dst);
close_system(dst, 0);
fprintf('Built %s\n', fullfile(root, [dst '.slx']));
end
