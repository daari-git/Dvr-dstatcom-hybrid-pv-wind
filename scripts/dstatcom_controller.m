function [vinv, dbg] = dstatcom_controller(vpcc, iL, ic, en, mode, g)
% D-STATCOM control in the synchronous reference frame with PI regulators.
% The text of this file is copied into the MATLAB Function block of
% IEEE13_dstatcom.slx by build_dstatcom.
%
%   vpcc  phase-to-ground voltage at the point of connection (V)
%   iL    load current (A)
%   ic    D-STATCOM current, positive into the point of connection (A)
%   en    1 = controller active, 0 = track the grid voltage (no current)
%   mode  1 = cancel load reactive power, harmonics and unbalance
%         2 = regulate the voltage magnitude, plus harmonics and unbalance
%   g     [current-loop bandwidth (Hz); KpDc; KiDc; KpV; KiV; Imax (A peak)]
%         hand-tuned baseline: [1500; 1; 15; 5; 500; 850]
%
%   vinv  inverter voltage command for the averaged converter (V)
%   dbg   [Vdc; idRef; iqRef; id; iq; Vd; theta; f]
%
% The converter is an averaged model: no switching, and the DC link is
% represented by its power balance, C*Vdc*dVdc/dt = -Pac.
%#codegen

Ts = 50e-6; w0 = 2*pi*60;
L = 0.2e-3; R = 5e-3; C = 10e-3;          % coupling filter and DC capacitor
VdcRef = 1000;                            % V
Imax = g(6);                              % current limit; 850 A peak is about 500 kVA
Vref = 480*sqrt(2/3);                     % V peak, 1 pu phase voltage
N = 333;                                  % samples in one fundamental cycle

KpI = 2*pi*g(1)*L;  KiI = 2*pi*g(1)*R;    % current loops
KpDc = g(2);        KiDc = g(3);          % DC-link voltage loop, A/V
KpV = g(4);         KiV = g(5);           % AC voltage loop, A/V
KpPll = 178;        KiPll = 15791;        % PLL, 20 Hz bandwidth

persistent theta xPll xId xIq xDc xV vdc buf bsum idx
if isempty(theta)
    theta = atan2((vpcc(2) - vpcc(3))/sqrt(3), (2*vpcc(1) - vpcc(2) - vpcc(3))/3);
    xPll = 0; xId = 0; xIq = 0; xDc = 0; xV = 0; vdc = VdcRef;
    buf = zeros(N, 4); buf(:, 4) = VdcRef;
    bsum = [0; 0; 0; N*VdcRef];
    idx = 1;
end

% Phase-locked loop on the connection-point voltage
[vd, vq] = abc2dq(vpcc, theta);
vmag = max(hypot(vd, vq), 1);
ePll = vq / vmag;
w = w0 + KpPll*ePll + xPll;

[iLd, iLq] = abc2dq(iL, theta);
[icd, icq] = abc2dq(ic, theta);

% One-cycle moving averages: fundamental active and reactive load current,
% voltage magnitude and DC-link voltage
s = [iLd; iLq; vd; vdc];
bsum = bsum + s - buf(idx, :)';
buf(idx, :) = s';
idx = mod(idx, N) + 1;
avg = bsum / N;

if en < 0.5
    vinv = vpcc;
    xId = 0; xIq = 0; xDc = 0; xV = 0;
    idRef = 0; iqRef = 0;
else
    % DC-link voltage PI: active current drawn from the grid
    eDc = VdcRef - avg(4);
    idc = sat(KpDc*eDc + xDc, 0.3*Imax);
    xDc = sat(xDc + KiDc*eDc*Ts, 0.3*Imax);

    idRef = (iLd - avg(1)) - idc;
    if mode < 1.5
        iqRef = iLq;
    else
        % AC voltage PI: negative q current injects reactive power
        eV = Vref - avg(3);
        iqv = sat(KpV*eV + xV, Imax);
        xV = sat(xV + KiV*eV*Ts, Imax);
        iqRef = (iLq - avg(2)) - iqv;
    end
    m = hypot(idRef, iqRef);
    if m > Imax
        idRef = idRef*Imax/m; iqRef = iqRef*Imax/m;
    end

    % Current PI loops with voltage feed-forward and cross-coupling terms
    eD = idRef - icd; eQ = iqRef - icq;
    vdCmd = vd + KpI*eD + xId - w*L*icq;
    vqCmd = vq + KpI*eQ + xIq + w*L*icd;
    vlim = vdc / sqrt(3);
    vm = hypot(vdCmd, vqCmd);
    if vm > vlim
        vdCmd = vdCmd*vlim/vm; vqCmd = vqCmd*vlim/vm;
    else
        xId = xId + KiI*eD*Ts; xIq = xIq + KiI*eQ*Ts;
    end

    % The output reaches the network one sample later: advance the angle
    vinv = dq2abc(vdCmd, vqCmd, theta + 1.5*w*Ts);

    pac = 1.5*(vdCmd*icd + vqCmd*icq);
    vdc = max(vdc - Ts*pac/(C*vdc), 100);
end

dbg = [vdc; idRef; iqRef; icd; icq; vd; theta; w/(2*pi)];

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

function y = sat(u, lim)
y = min(max(u, -lim), lim);
end
