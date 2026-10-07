function [strat, names] = coord_strategies()
% The coordination strategies a supervisor chooses between.
% Columns: DVR load-voltage target during the disturbance (pu); PV and wind
% plant support (0 = unity power factor and cessation below 0.5 pu,
% 1 = stay connected and inject reactive current).
strat = [1.0 0
         0.9 0
         1.0 1
         0.9 1];
names = {'full restoration', 'economy restoration', ...
    'full restoration + plant support', 'economy restoration + plant support'};
end
