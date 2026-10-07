function in = coord_input(sc, strat, tl, gains)
% Simulation input for one run of IEEE13_coord.slx.
%   sc     scenario: fph (faulted phases, e.g. 'ABC'), gnd ('on'/'off'),
%          loc (1 = node 680, 2 = 675, 3 = 632), Rf (fault resistance, ohm),
%          tOn (fault start, s), G (irradiance, W/m^2), wind (m/s),
%          Ecap (usable DVR battery energy, kJ)
%   strat  [DVR target during the disturbance (pu), plant support 0 or 1]
%   tl     timeline: tNL (rectifier on), tDev (devices on), tStop
%   gains  optional: gains.dst = [fI; KpDc; KiDc], gains.dvr = [KpV; KiV];
%          the hand-tuned values are used otherwise
mdl = 'IEEE13_coord';
gd = [1500; 1; 15]; gv = [0.2; 200];
if nargin > 3 && ~isempty(gains), gd = gains.dst(:); gv = gains.dvr(:); end
oo = @(c) char(string(any(sc.fph == c)).replace("true", "on").replace("false", "off"));

in = Simulink.SimulationInput(mdl);
in = in.setModelParameter('StopTime', num2str(tl.tStop));
flt = {'Fault 680', 'Fault 675', 'Fault 632'};
for k = 1:3
    b = [mdl '/' flt{k}];
    in = in.setBlockParameter(b, 'FaultA', oo('A'));
    in = in.setBlockParameter(b, 'FaultB', oo('B'));
    in = in.setBlockParameter(b, 'FaultC', oo('C'));
    in = in.setBlockParameter(b, 'GroundFault', sc.gnd);
    in = in.setBlockParameter(b, 'FaultResistance', num2str(sc.Rf, 8));
end
in = in.setBlockParameter([mdl '/Relay Config'], 'Value', ...
    mat2str([sc.tOn; sc.loc; 700; 0.03; 0.03; 0.6], 8));
in = in.setBlockParameter([mdl '/NL Breaker'], 'SwitchTimes', sprintf('[%g]', tl.tNL));
in = in.setBlockParameter([mdl '/D-STATCOM/DST Breaker'], 'SwitchTimes', sprintf('[%g]', tl.tDev));
in = in.setBlockParameter([mdl '/D-STATCOM/DST Enable'], 'Time', num2str(tl.tDev));
in = in.setBlockParameter([mdl '/D-STATCOM/DST Mode'], 'Value', '1');
in = in.setBlockParameter([mdl '/D-STATCOM/DST Gains'], 'Value', mat2str([gd; 5; 500; 850], 8));
in = in.setBlockParameter([mdl '/DVR/DVR Enable'], 'Time', num2str(tl.tDev));
in = in.setBlockParameter([mdl '/DVR/DVR Gains'], 'Value', ...
    mat2str([gv; 0.5; strat(1); sc.Ecap], 8));
in = in.setBlockParameter([mdl '/PV Plant/PV Resource'], 'Table', sprintf('[%g %g]', sc.G, sc.G));
in = in.setBlockParameter([mdl '/Wind Plant/Wind Resource'], 'Table', sprintf('[%g %g]', sc.wind, sc.wind));
in = in.setBlockParameter([mdl '/PV Plant/PV Support'], 'Value', num2str(strat(2)));
in = in.setBlockParameter([mdl '/Wind Plant/Wind Support'], 'Value', num2str(strat(2)));
end
