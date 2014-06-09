function [m, d, tod, nextyear] = addTime(m, d, tod, ts, leapyear)
% Add ts (fraction of hours) to the current time (d, m, tod).
% leapyear is true if the current year is a leap year.
% ts should be small (not more than 24 (hours))
% nextyear = true if the time rolls to next year (however because we don't
% consider the year, (m,d) goes back to beginning of year.
% No error checking is carried out

nextyear = false;
tod = tod + ts;
if tod >= 24
    tod = tod - 24;
    d = d + 1;
    maxd = maxDaysInMonth(m, leapyear);
    if d > maxd
        d = d - maxd;
        m = m + 1;
        if m > 12
            m = m - 12;
            nextyear = true;
        end
    end
end

end
