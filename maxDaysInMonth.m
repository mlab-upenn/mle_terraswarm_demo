function md = maxDaysInMonth(m, leapyear)
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