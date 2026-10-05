function in = full_input(fph, gnd, T, gDst, gDvr)
% Simulation input for one run of IEEE13_full.slx.
%   fph   faulted phases, e.g. 'ABC', 'A', 'BC'
%   gnd   'on' or 'off': fault involves ground
%   T     timeline in seconds: tNL (rectifier on), tDev (DVR and D-STATCOM
%         on), tOn and tOff (fault window), tStop
%   gDst  D-STATCOM gains [current-loop bandwidth (Hz); KpDc; KiDc; KpV; KiV]
%   gDvr  DVR gains [KpV; KiV]
mdl = 'IEEE13_full';
oo = @(c) char(string(any(fph == c)).replace("true", "on").replace("false", "off"));
in = Simulink.SimulationInput(mdl);
in = in.setModelParameter('StopTime', num2str(T.tStop));
in = in.setBlockParameter([mdl '/Fault 680'], 'FaultA', oo('A'));
in = in.setBlockParameter([mdl '/Fault 680'], 'FaultB', oo('B'));
in = in.setBlockParameter([mdl '/Fault 680'], 'FaultC', oo('C'));
in = in.setBlockParameter([mdl '/Fault 680'], 'GroundFault', gnd);
in = in.setBlockParameter([mdl '/Fault 680'], 'SwitchTimes', sprintf('[%g %g]', T.tOn, T.tOff));
in = in.setBlockParameter([mdl '/NL Breaker'], 'SwitchTimes', sprintf('[%g]', T.tNL));
in = in.setBlockParameter([mdl '/D-STATCOM/DST Breaker'], 'SwitchTimes', sprintf('[%g]', T.tDev));
in = in.setBlockParameter([mdl '/D-STATCOM/DST Enable'], 'Time', num2str(T.tDev));
in = in.setBlockParameter([mdl '/D-STATCOM/DST Mode'], 'Value', '1');
in = in.setBlockParameter([mdl '/D-STATCOM/DST Gains'], 'Value', mat2str(gDst(:), 8));
in = in.setBlockParameter([mdl '/DVR/DVR Enable'], 'Time', num2str(T.tDev));
in = in.setBlockParameter([mdl '/DVR/DVR Gains'], 'Value', mat2str(gDvr(:), 8));
end
