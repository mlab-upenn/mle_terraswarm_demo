function l = isLaterTime(m1, d1, tod1, m2, d2, tod2)
% Check if time1 > time2 (strictly). Each time is represented by month,
% day, time of day (as fractional hours).

% Convert (m,d,tod) to a number then compare
% the coefficients
wd = 32; % wd >= 24
wm = 32*wd;  % >= (31+1)*wd >= 31*wd + 24
l = (m1*wm + d1*wd + tod1) > (m2*wm + d2*wd + tod2);
end