function build_dstatcom()
% Builds IEEE13_dstatcom.slx: the base-case feeder plus the D-STATCOM at node 634.
% Run build_basecase first.

src = 'IEEE13_basecase';
dst = 'IEEE13_dstatcom';
root = fileparts(fileparts(mfilename('fullpath')));

if bdIsLoaded(dst), close_system(dst, 0); end
if bdIsLoaded(src), close_system(src, 0); end
load_system(fullfile(root, [src '.slx']));
save_system(src, fullfile(root, [dst '.slx']));   % loaded model is now dst

add_dstatcom(dst);

save_system(dst);
close_system(dst, 0);
fprintf('Built %s\n', fullfile(root, [dst '.slx']));
end
