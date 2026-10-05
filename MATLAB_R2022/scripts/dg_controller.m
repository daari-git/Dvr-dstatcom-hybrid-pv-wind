function [vinv, dbg] = dg_controller(vpcc, ig, res, en, kind)
% Averaged model and control of an inverter-interfaced DG plant.
% The text of this file is copied into the MATLAB Function blocks of the
% PV and wind plants by add_dg.
%
%   vpcc  phase-to-ground voltage at the point of connection (V)
%   ig    plant current, positive into the grid (A)
%   res   resource: irradiance in W/m^2 (PV) or wind speed in m/s (wind)
%   en    1 = plant connected, 0 = track the grid voltage (no current)
%   kind  1 = PV plant, 400 kW at 480 V; 2 = wind plant, 500 kW at 4.16 kV
%
%   vinv  inverter voltage command for the averaged converter (V)
%   dbg   [Pin_kW; P_kW; Q_kvar; Vdc; id; Vpu; aux; ceased]
%         aux is the DC-voltage reference (PV) or rotor speed in pu (wind)
%
% Source side
%   PV    array I-V curve, perturb-and-observe MPPT on the DC-link voltage
%   wind  full-converter turbine: Cp(lambda) aerodynamics, one-mass rotor,
%         optimal-torque MPPT, ideal power limit at rated, DC chopper
% Grid side (both)
%   PLL, DC-link voltage PI, current PI loops, unity power factor,
%   current limit at 1.1 pu, momentary cessation below 0.5 pu voltage.
% There is no switching; the DC link is its power balance.
%#codegen

Ts = 50e-6; w0 = 2*pi*60; N = 333;        % N samples in one cycle
if kind < 1.5
    Vn = 480;  Sr = 450e3; Pr = 400e3; VdcNom = 850;
else
    Vn = 4160; Sr = 550e3; Pr = 500e3; VdcNom = 7500;
end
Vpk  = Vn*sqrt(2/3);                      % 1 pu phase voltage, peak
Imax = 1.1*Sr/(1.5*Vpk);                  % current limit, peak
Zb = Vn^2/Sr; L = 0.1*Zb/w0; R = 0.01*Zb; % coupling filter, as in add_dg
C  = 2*Sr*0.02/VdcNom^2;                  % DC link stores 20 ms of rated power
tRamp = 0.1;                              % soft start, s

KpI = 2*pi*500*L;  KiI = 2*pi*500*R;      % current loops
wdc = 2*pi*20;                            % DC-link voltage loop
KpDc = wdc*C*VdcNom/(1.5*Vpk);  KiDc = KpDc*wdc/4;
KpPll = 178;  KiPll = 15791;              % PLL, 20 Hz bandwidth

% PV array at 25 degC
Voc = 1050; Vmp = 850; Imp = 400e3/Vmp; Isc = 1.07*Imp;
C2 = (Vmp/Voc - 1)/log(1 - Imp/Isc);
C1 = (1 - Imp/Isc)*exp(-Vmp/(C2*Voc));
% Wind turbine. The inertia constant is short so that a wind change shows
% within a simulation of one or two seconds.
vRated = 12; lamOpt = 8.1; cpMax = 0.48; H = 0.5;

persistent theta xPll xId xIq xDc vdc vdcRef buf bsum idx tOn wr ceased chop ...
    pAcc cnt pPrev dirV
if isempty(theta)
    theta = atan2((vpcc(2) - vpcc(3))/sqrt(3), (2*vpcc(1) - vpcc(2) - vpcc(3))/3);
    xPll = 0; xId = 0; xIq = 0; xDc = 0;
    vdc = VdcNom; vdcRef = VdcNom;
    buf = zeros(N, 1); bsum = 0; idx = 1;
    tOn = 0; wr = min(max(res/vRated, 0.3), 1); ceased = 0; chop = 0;
    pAcc = 0; cnt = 0; pPrev = 0; dirV = 1;
end

% Phase-locked loop on the connection-point voltage
[vd, vq] = abc2dq(vpcc, theta);
ePll = vq / max(hypot(vd, vq), 1);
w = w0 + KpPll*ePll + xPll;
[id, iq] = abc2dq(ig, theta);

% One-cycle average of the voltage magnitude for the ride-through logic
bsum = bsum + vd - buf(idx);
buf(idx) = vd;
idx = mod(idx, N) + 1;
vpu = (bsum / N) / Vpk;

% Wind turbine rotor (runs whether or not the plant is connected)
pGen = 0;
if kind > 1.5
    v = max(res, 0) / vRated;
    li = 1/(lamOpt*wr/max(v, 0.05)) - 0.035;
    cp = max(0.5176*(116*li - 5)*exp(-21*li) + 0.0068/(li + 0.035), 0);
    pAero = min(cp/cpMax*v^3, 1);
    tGen = min(wr^2, 1);
    wr = max(wr + Ts*(pAero/wr - tGen)/(2*H), 0.2);
    pGen = tGen*wr*Pr;
end

if en < 0.5
    vinv = vpcc;
    xId = 0; xIq = 0; xDc = 0; vdc = VdcNom; vdcRef = VdcNom; tOn = 0;
    pin = 0; idRef = 0;
else
    tOn = tOn + Ts;
    ramp = min(tOn/tRamp, 1);
    if kind < 1.5
        ipv = max(Isc*max(res, 0)/1000*ramp*(1 - C1*(exp(vdc/(C2*Voc)) - 1)), 0);
        pin = vdc*ipv;
    else
        pin = ramp*pGen;
    end

    % Momentary cessation below 0.5 pu, resume above 0.6 pu
    if vpu < 0.5
        ceased = 1;
    elseif vpu > 0.6
        ceased = 0;
    end

    % Perturb-and-observe MPPT every two cycles, frozen in abnormal voltage
    if kind < 1.5 && ramp >= 1 && vpu > 0.88
        pAcc = pAcc + pin; cnt = cnt + 1;
        if cnt >= 2*N
            pAvg = pAcc / cnt;
            if pAvg < pPrev, dirV = -dirV; end
            vdcRef = min(max(vdcRef + 3*dirV, 760), 1000);
            pPrev = pAvg; pAcc = 0; cnt = 0;
        end
    end

    % DC-link voltage PI gives the active current; unity power factor
    if ceased > 0.5
        idRef = 0;
    else
        eDc = vdc - vdcRef;
        u = KpDc*eDc + xDc;
        idRef = min(max(u, 0), Imax);
        if u == idRef, xDc = xDc + KiDc*eDc*Ts; end
    end
    iqRef = 0;

    % Current PI loops with voltage feed-forward and cross-coupling terms
    eD = idRef - id; eQ = iqRef - iq;
    vdCmd = vd + KpI*eD + xId - w*L*iq;
    vqCmd = vq + KpI*eQ + xIq + w*L*id;
    vlim = vdc / sqrt(3);
    vm = hypot(vdCmd, vqCmd);
    if vm > vlim
        vdCmd = vdCmd*vlim/vm; vqCmd = vqCmd*vlim/vm;
    else
        xId = xId + KiI*eD*Ts; xIq = xIq + KiI*eQ*Ts;
    end

    % The output reaches the network one sample later: advance the angle
    vinv = dq2abc(vdCmd, vqCmd, theta + 1.5*w*Ts);

    % DC link. The wind plant burns surplus power in a chopper; the PV
    % array limits itself as the voltage rises toward open circuit.
    if kind > 1.5
        if vdc > 1.10*VdcNom, chop = 1; elseif vdc < 1.05*VdcNom, chop = 0; end
        if chop > 0.5, pin = 0; end
    end
    pac = 1.5*(vdCmd*id + vqCmd*iq);
    vdc = max(vdc + Ts*(pin - pac)/(C*vdc), 0.5*VdcNom);
end

if kind < 1.5, aux = vdcRef; else, aux = wr; end
dbg = [pin/1e3; 1.5*(vd*id + vq*iq)/1e3; 1.5*(vq*id - vd*iq)/1e3; ...
    vdc; id; vpu; aux; ceased];

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
