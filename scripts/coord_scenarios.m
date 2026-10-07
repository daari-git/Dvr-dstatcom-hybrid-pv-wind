function [S, tl] = coord_scenarios(n, seed)
% Random fault scenarios for IEEE13_coord.slx, and the common timeline.
%   fault type      three-phase-to-ground, single line-to-ground (A),
%                   line-to-line (B-C), double line-to-ground (B-C)
%   location        node 680, 675 or 632
%   resistance      0.01 to 5 ohm, log-uniform (sets the sag depth)
%   start           anywhere within one cycle
%   irradiance      100 to 1000 W/m^2;  wind speed 6 to 12.5 m/s
%   battery         4 to 20 kJ usable in the DVR
rng(seed);
tl = struct('tNL', 0.3, 'tDev', 0.35, 'tStop', 1.3);
types = {'ABC', 'on'; 'A', 'on'; 'BC', 'off'; 'BC', 'on'};
S = struct('fph', {}, 'gnd', {}, 'loc', {}, 'Rf', {}, 'tOn', {}, 'G', {}, 'wind', {}, 'Ecap', {});
for k = 1:n
    ty = randi(4);
    S(k).fph = types{ty, 1}; S(k).gnd = types{ty, 2};
    S(k).loc = randsample(3, 1, true, [0.4 0.3 0.3]);
    S(k).Rf = 10^(log10(0.01) + rand*(log10(5) - log10(0.01)));
    S(k).tOn = 0.55 + rand/60;
    S(k).G = 100 + 900*rand;
    S(k).wind = 6 + 6.5*rand;
    S(k).Ecap = 4 + 16*rand;
end
end
