function m = full_metrics(out, T)
% Performance of one run of IEEE13_full.slx.
%   T adds two analysis start times to the timeline of full_input:
%   tSteady (devices on, before the fault) and tFault (during the fault).
% m.J is the cost minimised in optimise_gains; lower is better.
f0 = 60; vb = 480/sqrt(3);
m = struct('J', 1e3);
if ~isempty(out.ErrorMessage), return; end

vl = out.get('log_V634'); vs = out.get('log_Vs634'); is = out.get('log_Is634');

% Before the fault: load voltage and source-side current quality
a = pq_analyse(vl, T.tSteady, f0, vb);
c = pq_analyse(is, T.tSteady, f0, 1);
S = sum(a.ph .* conj(c.ph));
m.Vl_steady = a.pu;  m.Vunb_steady = a.unb;  m.THDv = max(a.thd);
m.THDi = max(c.thd); m.Iunb = c.unb;
% The PV plant offsets most of the load, so the source current is small and
% ratios to its fundamental are inflated. Also express the distortion and
% the negative-sequence current against the 500 kVA transformer rating.
Irated = 500e3 / (sqrt(3)*480);
al = exp(1j*2*pi/3);
m.TDD = 100 * max(c.thd/100 .* abs(c.ph)) / Irated;
m.I2 = 100 * abs(c.ph(1) + al^2*c.ph(2) + al*c.ph(3)) / 3 / Irated;
m.PF = real(S)/abs(S); m.P_kW = real(S)/1e3; m.Q_kvar = imag(S)/1e3;

% During the fault
b = pq_analyse(vl, T.tFault, f0, vb);
s = pq_analyse(vs, T.tFault, f0, vb);
m.Vl_fault = b.pu; m.Vunb_fault = b.unb; m.Vs_fault = s.pu;

% Rating each device actually uses: DVR injected voltage and apparent power
% during the fault, D-STATCOM apparent power before it and its peak current
vi = pq_analyse(out.get('log_Vinj'), T.tFault, f0, vb);
id = pq_analyse(out.get('log_Idvr'), T.tFault, f0, 1);
m.Vinj_max = max(vi.pu);
m.Sdvr_kVA = sum(abs(vi.ph) .* abs(id.ph)) / 1e3;
ic = out.get('log_Idst');
r = pq_analyse(ic, T.tSteady, f0, 1);
m.Sdst_kVA = sum(abs(a.ph) .* abs(r.ph)) / 1e3;
x = squeeze(ic.Data);
m.Idst_peak = max(abs(x(ic.Time >= T.tDev + 0.05, :)), [], 'all');

% Load-voltage error from when the devices have settled to the end: mean
% absolute deviation of the sliding one-cycle rms from 1 pu, percent
t = vl.Time; x = squeeze(vl.Data) / vb;
n = round(1/f0/(t(2) - t(1)));
vr = sqrt(movmean(x.^2, [n-1 0], 1));
k = t >= T.tDev + 0.05 & t <= T.tStop;
m.eV = 100 * mean(abs(vr(k, :) - 1), 'all');

[td, d] = dbgdata(out.get('log_dst'));
m.VdcDev = 100 * max(abs(d(td >= T.tDev + 0.05, 1) - 1000)) / 1000;

[td, d] = dbgdata(out.get('log_dvr'));
kf = td >= T.tFault & td < T.tFault + 3/f0;
m.Pdvr_kW = mean(d(kf, 1)) / 1e3;
m.Edvr_kJ = (d(find(td >= T.tOff, 1), 2) - d(find(td >= T.tOn, 1), 2)) / 1e3;

[~, d] = dbgdata(out.get('log_pv'));   m.Ppv_kW = mean(d(kf, 2));
[~, d] = dbgdata(out.get('log_wind')); m.Pwind_kW = mean(d(kf, 2));
m.wind_ceased = max(d(kf, 8));

m.J = 4*m.eV + m.THDv + m.TDD + m.I2 + 100*(1 - m.PF) + 0.2*m.VdcDev;
if ~isfinite(m.J), m.J = 1e3; end
end

function [t, x] = dbgdata(ts)
t = ts.Time; x = squeeze(ts.Data);
if size(x, 1) ~= numel(t), x = x.'; end
end
