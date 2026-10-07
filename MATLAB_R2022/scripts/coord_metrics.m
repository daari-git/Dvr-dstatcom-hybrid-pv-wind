function [m, feat, names] = coord_metrics(out, sc, tl)
% Outcome of one run of IEEE13_coord.slx, and the features a supervisor
% could measure in the first half cycle after the disturbance is detected.
%
%   m      outcome: fault duration and depth, load and bus voltage penalties,
%          DVR energy and battery state, generation lost, and the cost m.J
%   feat   row vector of features (see names)
%
% Voltage penalty per phase, integrated from the fault start to 0.1 s after
% it is cleared: |v - 1| + 10*max(0.9 - v, 0) + 10*max(v - 1.1, 0), in
% pu.ms. It is small inside the 0.9 to 1.1 pu band and grows fast outside.
% Cost: J = load penalty + 0.2 * bus 675 penalty + 0.05 * generation lost (kJ)

names = {'V1_pu', 'V2_pu', 'V0_pu', 'Va_pu', 'Vb_pu', 'Vc_pu', 'dVmin_pu', ...
    'I1_A', 'I2_A', 'Ppv_kW', 'Pwind_kW', 'Pload_kW', 'Ecap_kJ'};
f0 = 60; vb = 480/sqrt(3); vb2 = 4160/sqrt(3);
m = struct('J', NaN); feat = nan(1, numel(names));
if ~isempty(out.ErrorMessage), return; end

%% Fault duration from the relay
[tr, r] = dbgdata(out.get('log_relay'));
tTrip = max(r(:, 3));
tClr = tl.tStop;
if tTrip >= 0, tClr = tTrip + 0.03; end
m.duration = tClr - sc.tOn;
m.Ifault = max(r(tr >= sc.tOn & tr <= tClr, 1));
tEnd = min(tClr + 0.1, tl.tStop);

%% Voltage penalties and depth
pen = @(v) abs(v - 1) + 10*max(0.9 - v, 0) + 10*max(v - 1.1, 0);
[t, vl] = rmspu(out.get('log_V634'), vb, f0);
k = t >= sc.tOn & t <= tEnd;
m.Jload = 1000 * mean(trapz(t(k), pen(vl(k, :))));
m.Vl_min = min(vl(k, :), [], 'all'); m.Vl_max = max(vl(k, :), [], 'all');
[t2, vbus] = rmspu(out.get('log_V675'), vb2, f0);
k2 = t2 >= sc.tOn & t2 <= tEnd;
m.Jbus = 1000 * mean(trapz(t2(k2), pen(vbus(k2, :))));
m.Vbus_min = min(vbus(k2, :), [], 'all');
[ts, vs] = rmspu(out.get('log_Vs634'), vb, f0);
kf = ts >= sc.tOn + 1/f0 & ts <= tClr;
if ~any(kf), kf = ts >= sc.tOn & ts <= tEnd; end
m.depth = min(vs(kf, :), [], 'all');

%% DVR energy and battery
[td, d] = dbgdata(out.get('log_dvr'));
m.Edvr_kJ = (interp1(td, d(:, 2), tEnd) - interp1(td, d(:, 2), sc.tOn)) / 1e3;
m.batt_empty = double(any(d(:, 8) >= 2));
m.batt_left = d(end, 7);

%% Generation lost during the event
[tp, pv] = dbgdata(out.get('log_pv')); [~, wd] = dbgdata(out.get('log_wind'));
kp = tp >= sc.tOn & tp <= tEnd; pre = tp >= sc.tOn - 0.05 & tp < sc.tOn;
Ppv = mean(pv(pre, 2)); Pwd = mean(wd(pre, 2));
m.Edg_lost_kJ = max((Ppv + Pwd)*(tEnd - sc.tOn) - trapz(tp(kp), pv(kp, 2) + wd(kp, 2)), 0);
m.wind_ceased = double(any(wd(kp, 8) > 0.5));

m.J = m.Jload + 0.2*m.Jbus + 0.05*m.Edg_lost_kJ;

%% Features: half a cycle from detection, at the DVR's supply side
kd = find(td >= sc.tOn - 1e-4 & mod(d(:, 8), 2) >= 1, 1);
tDet = sc.tOn + 0.002;
if ~isempty(kd), tDet = td(kd); end
m.t_detect = tDet - sc.tOn;
v = out.get('log_Vs634'); i = out.get('log_Is634');
tv = v.Time; n = round(0.5/f0/(tv(2) - tv(1)));
i0 = find(tv >= tDet, 1); w = i0:i0 + n - 1;
x = squeeze(v.Data); x = x(w, :) / (vb*sqrt(2));
y = squeeze(i.Data); y = y(w, :);
e = exp(-1j*2*pi*f0*tv(w));
V = 2/n * sum(x .* e, 1); I = 2/n * sum(y .* e, 1) / sqrt(2);
a = exp(1j*2*pi/3); S = [1 a a^2; 1 a^2 a; 1 1 1] / 3;
Vs = abs(S * V.'); Is = abs(S * I.');
h = floor(n/2);
q1 = sqrt(2*mean(x(1:h, :).^2, 1)); q2 = sqrt(2*mean(x(h+1:end, :).^2, 1));
vload = out.get('log_V634'); iload = out.get('log_I634');
kc = vload.Time >= sc.tOn - 1/f0 & vload.Time < sc.tOn;
Pload = mean(sum(squeeze(vload.Data(kc, :)) .* squeeze(iload.Data(kc, :)), 2)) / 1e3;
feat = [Vs(1), Vs(2), Vs(3), sqrt(2*mean(x.^2, 1)), min(q2 - q1), ...
    Is(1), Is(2), Ppv, Pwd, Pload, sc.Ecap];
end

function [t, x] = dbgdata(ts)
t = ts.Time; x = squeeze(ts.Data);
if size(x, 1) ~= numel(t), x = x.'; end
end

function [t, vr] = rmspu(ts, vb, f0)
% Sliding one-cycle rms of each phase, per unit
t = ts.Time; x = squeeze(ts.Data) / vb;
n = round(1/f0/(t(2) - t(1)));
vr = sqrt(movmean(x.^2, [n-1 0], 1));
end
