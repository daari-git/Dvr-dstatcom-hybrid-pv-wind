function r = pq_analyse(ts, t0, f0, base)
% Fundamental phasors, unbalance and THD of a three-phase signal over three
% cycles starting at t0. ts is a timeseries with three columns.
%   r.ph   fundamental rms phasors
%   r.pu   fundamental rms magnitude divided by base
%   r.thd  THD per phase, percent (harmonics 2 to 50)
%   r.unb  negative- to positive-sequence ratio, percent
t = ts.Time; x = squeeze(ts.Data);
Ts = t(2) - t(1);
n  = round(3/f0/Ts);                       % three cycles: integer sample count
i0 = find(t >= t0, 1);
X  = fft(x(i0:i0+n-1, :)) / n * 2;         % peak amplitude per bin
k1 = 3 + 1;                                % fundamental bin (three cycles)
h  = 2:50;
r.ph  = X(k1, :) / sqrt(2);
r.pu  = abs(r.ph) / base;
r.thd = 100 * sqrt(sum(abs(X(3*h + 1, :)).^2, 1)) ./ abs(X(k1, :));
a  = exp(1j*2*pi/3);
p1 = (r.ph(1) + a*r.ph(2) + a^2*r.ph(3)) / 3;
p2 = (r.ph(1) + a^2*r.ph(2) + a*r.ph(3)) / 3;
r.unb = 100 * abs(p2) / abs(p1);
end
