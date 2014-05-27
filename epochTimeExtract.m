function [M, D, TOD, Y] = epochTimeExtract( ET )
%EPOCHTIMEEXTRACT Convert epoch time to year, month, day, hour.
%   [M, D, TOD, Y] = epochTimeExtract( ET )
%extracts the month, day, time of day (in fraction hours), and year from an
%UNIX epoch time value ET.
%
% (C) 2014 by Truong X. Nghiem (nghiem@seas.upenn.edu)

[Y, M, D, H, MN, S] = datevec(epoch2matlab(ET));
TOD = H + MN/60 + S/3600;

end
