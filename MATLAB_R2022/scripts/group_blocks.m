function group_blocks(mdl, prefix, sub)
% Groups the top-level blocks whose names start with '<prefix> ' into a
% subsystem called sub. Does nothing if that subsystem already exists.
if ~isempty(find_system(mdl, 'SearchDepth', 1, 'Name', sub)), return; end
b = find_system(mdl, 'SearchDepth', 1, 'RegExp', 'on', 'Name', ['^' prefix ' ']);
h = cellfun(@(x) get_param(x, 'Handle'), b);
Simulink.BlockDiagram.createSubsystem(h, 'Name', sub);
end
