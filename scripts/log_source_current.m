function log_source_current(mdl)
% Turns on the current measurement of the block after the 500 kVA
% transformer (label Is634) and logs it as log_Is634. This is the
% source-side current of node 634 and the current through the DVR.
% Does nothing if it is already logged.
if ~isempty(find_system(mdl, 'SearchDepth', 1, 'Name', 'Log Is634')), return; end
set_param([mdl '/XFXFM1'], 'CurrentMeasurement', 'yes', ...
    'SetLabelI', 'on', 'LabelI', 'Is634');
add_block('simulink/Signal Routing/From', [mdl '/Log From Is634'], ...
    'Position', [2000 540 2060 564], 'GotoTag', 'Is634');
add_block('simulink/Sinks/To Workspace', [mdl '/Log Is634'], ...
    'Position', [2120 540 2200 564], 'VariableName', 'log_Is634', ...
    'SaveFormat', 'Timeseries', 'MaxDataPoints', 'inf', 'SampleTime', '-1');
add_line(mdl, 'Log From Is634/1', 'Log Is634/1');
end
