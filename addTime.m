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
    maxd = maxDays(m, leapyear);
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

function md = maxDays(m, leapyear)
% return max number of days for a given month
% No error checking is carried out
switch m
    case {1, 3, 5, 7, 8, 10, 12}
        md = 31;
    case 2
        if leapyear
            md = 29;
        else
            md = 28;
        end
    otherwise
        md = 30;
end
end