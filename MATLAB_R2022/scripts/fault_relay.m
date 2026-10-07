function [cmd, dbg] = fault_relay(i650, t, cfg)
% Fault timing with an inverse-time overcurrent relay at the substation.
% The text of this file is copied into the MATLAB Function block of
% IEEE13_coord.slx by add_relay.
%
%   i650  substation current (A)
%   t     simulation time (s)
%   cfg   [fault start (s); fault location 1 to 3; pickup current (A rms);
%          time multiplier; breaker time (s); backup clearing time (s)]
%
%   cmd   3-by-1 fault command, 1 = fault applied at that location
%   dbg   [largest phase current (A rms); relay progress 0 to 1;
%          trip time (s, -1 before the trip); fault applied]
%
% The fault starts at cfg(1). The relay follows the IEC standard inverse
% curve, t = TMS * 0.14 / ((I/Ip)^0.02 - 1), so a larger fault current is
% cleared sooner. The fault is removed one breaker time after the trip, or
% after the backup time if the current never reaches pickup.
%#codegen

Ts = 50e-6; N = 333;                      % N samples in one cycle

persistent buf bsum idx acc tTrip
if isempty(buf)
    buf = zeros(N, 3); bsum = zeros(1, 3); idx = 1; acc = 0; tTrip = -1;
end

% One-cycle rms of each phase; the relay acts on the largest
sq = (i650(:)').^2;
bsum = bsum + sq - buf(idx, :);
buf(idx, :) = sq;
idx = mod(idx, N) + 1;
I = sqrt(max(max(bsum), 0) / N);

started = t >= cfg(1);
if started && tTrip < 0
    if I > cfg(3)
        acc = acc + Ts*((I/cfg(3))^0.02 - 1) / (0.14*cfg(4));
    else
        acc = 0;
    end
    if acc >= 1 || t >= cfg(1) + cfg(6), tTrip = t; end
end
applied = started && ~(tTrip >= 0 && t >= tTrip + cfg(5));

cmd = zeros(3, 1);
if applied, cmd(min(max(round(cfg(2)), 1), 3)) = 1; end
dbg = [I; min(acc, 1); tTrip; double(applied)];
end
