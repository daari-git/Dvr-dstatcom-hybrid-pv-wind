function group_plant(mdl, name)
% Groups the top-level blocks of one DG plant (all blocks named '<name> ...')
% into a subsystem called '<name> Plant'. Does nothing if it already exists.
if ~isempty(find_system(mdl, 'SearchDepth', 1, 'Name', [name ' Plant'])), return; end
b = find_system(mdl, 'SearchDepth', 1, 'RegExp', 'on', 'Name', ['^' name ' ']);
h = cellfun(@(x) get_param(x, 'Handle'), b);
Simulink.BlockDiagram.createSubsystem(h, 'Name', [name ' Plant']);
end
