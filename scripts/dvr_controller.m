function [vinj, dbg] = dvr_controller(vs, vl, il, en, g)
% DVR control: feed-forward of the missing supply voltage plus PI trim of
% the load voltage in the synchronous reference frame.
% The text of this file is copied into the MATLAB Function block of
% IEEE13_dvr.slx by build_dvr.
%
%   vs    supply-side phase-to-ground voltage (V)
%   vl    load-side phase-to-ground voltage (V)
%   il    current through the DVR (A)
%   en    1 = controller active, 0 = inject nothing
%   g     [KpV; KiV; injection limit (pu); load-voltage target during a
%         disturbance (pu); usable battery energy (kJ)]
%         baseline [0.2; 200; 0.5; 1; 1e6]: full restoration, unlimited energy
%
%   vinj  series voltage command for the averaged converter (V)
%   dbg   [Pinj; Einj; trimD; trimQ; vLd; vLq; battery left (0 to 1);
%         flags: 1 = disturbance detected, 2 = battery empty, 3 = both]
%
% The converter is an averaged model with no switching. The battery is an
% energy store: when it is empty the DVR stops injecting.
%#codegen

Ts = 50e-6; w0 = 2*pi*60;
Vref = 480*sqrt(2/3);                     % V peak, 1 pu phase voltage
Vmax = g(3)*Vref;                         % injection limit per phase
N = 333;                                  % samples in one fundamental cycle

KpV = g(1);  KiV = g(2);                  % load-voltage loops
Ecap = g(5)*1e3;                          % usable battery energy, J
KpPll = 44;  KiPll = 987;                 % PLL, 5 Hz bandwidth

persistent theta xPll xD xQ buf bsum idx E Eb hold empty
if isempty(theta)
    theta = atan2((vs(2) - vs(3))/sqrt(3), (2*vs(1) - vs(2) - vs(3))/3);
    xPll = 0; xD = 0; xQ = 0; E = 0;
    Eb = Ecap; hold = 0; empty = 0;
    buf = zeros(N, 1); bsum = 0; idx = 1;
end

% Slow PLL on the supply voltage. The one-cycle average removes the ripple
% from unbalance, so the angle holds its pre-fault phase through a sag.
[vsd, vsq] = abc2dq(vs, theta);
bsum = bsum + vsq - buf(idx);
buf(idx) = vsq;
idx = mod(idx, N) + 1;
ePll = (bsum / N) / Vref;
w = w0 + KpPll*ePll + xPll;

[vld, vlq] = abc2dq(vl, theta);

% Disturbance detection: the supply vector leaves its nominal position by
% more than 0.1 pu. It is held for one cycle so that the ripple of an
% unbalanced fault does not release it.
if hypot(vsd - Vref, vsq) > 0.1*Vref
    hold = N;
elseif hold > 0
    hold = hold - 1;
end
Vtgt = Vref;
if hold > 0, Vtgt = g(4)*Vref; end

if en < 0.5 || empty > 0.5
    vinj = zeros(3, 1);
    xD = 0; xQ = 0; trimD = 0; trimQ = 0;
else
    eD = Vtgt - vld; eQ = -vlq;
    trimD = KpV*eD + xD;
    trimQ = KpV*eQ + xQ;

    % The output reaches the network one sample later: advance the angle.
    % The zero-sequence part of the supply voltage is removed directly.
    v0 = (vs(1) + vs(2) + vs(3)) / 3;
    u = dq2abc(Vtgt - vsd + trimD, -vsq + trimQ, theta + 1.5*w*Ts) - v0;
    vinj = min(max(u, -Vmax), Vmax);
    if all(abs(u) <= Vmax)
        xD = xD + KiV*eD*Ts; xQ = xQ + KiV*eQ*Ts;
    end
end

p = vinj' * il;
E = E + p*Ts;
Eb = min(Eb - p*Ts, Ecap);
if Eb <= 0, empty = 1; end
dbg = [p; E; trimD; trimQ; vld; vlq; max(Eb, 0)/Ecap; (hold > 0) + 2*empty];

xPll = xPll + KiPll*ePll*Ts;
theta = mod(theta + w*Ts, 2*pi);
end

function [d, q] = abc2dq(x, th)
al = (2*x(1) - x(2) - x(3)) / 3;
be = (x(2) - x(3)) / sqrt(3);
d =  al*cos(th) + be*sin(th);
q = -al*sin(th) + be*cos(th);
end

function x = dq2abc(d, q, th)
al = d*cos(th) - q*sin(th);
be = d*sin(th) + q*cos(th);
x = [al; -al/2 + sqrt(3)/2*be; -al/2 - sqrt(3)/2*be];
end
