function [nextStep, flag, simtime, outputs] = spinUpEP(EP, TS, M, D, TOD, FB)
%SPINUPEP Spin up E+ simulation till a given time of year.
%   [nextStep, flag, simtime, outputs] = spinUpEP(EP, TS, M, D, TOD, FB)
%spins up an EnergyPlus co-simulation EP (mlepProcess), with timestep TS
%(in hours, 0-1), to a given date of year M/D (M: 1-12, D: 1-31) and time
%of day TOD (0.0 to 24.0 as fraction of hours).  A requirement of the
%co-simulation is that it must export the following variables at the exact
%indices:
% 1. currentYear
% 2. currentMonth
% 3. currentDayOfMonth
% 4. currentTimeOfDay
%See the examples for how to create and export these variables using EMS
%and external interface.
%
%Optionally, a feedback function FB can be provided to compute the inputs
%to EnergyPlus given the current outputs from EnergyPlus:
%   u = FB(y)
%where y is the vector of values received from EnergyPlus (including the
%first 4 aforementioned variables).  The return values u must be a vector
%of doubles that will be sent to EnergyPlus as-is, therefore it must have
%the appropriate length.  If FB is omitted, the function will send an empty
%vector to EnergyPlus at each timestep, i.e. EnergyPlus must not expect any
%input values.
%
%The output nextStep is a structure of fields (M, D, TOD) that specifies
%the next time step of the co-simulation.  It can be used by the caller to
%ensure time synchronization with other processes.  If spinning up is
%successful, nextStep is strictly later than (M, D, TOD) while the current
%time step of EnergyPlus is no later than (M, D, TOD), i.e.
%       current-time-step <= (M, D, TOD) < nextStep
%
%After spinning up, the message from E+ for the current time step has
%already been read.  Its results are given in the outputs: flag is the flag
%in the message, simtime is the simulation time in E+, outputs is the
%vector of outputs from E+ (including the time values above).  So the
%caller code should start writing to E+ instead of reading from E+ (which
%will result in time-out error).
%
%The function will stop and give an error if the given time (M, D, TOD) is
%before the current time in EnergyPlus.  To be safe, make sure that the E+
%simulation starts from Jan 1st, 00:00.
%
%(C) 2014 by Truong X. Nghiem (nghiem@seas.upenn.edu)

% Check input arguments
narginchk(5, 6);

assert(isa(EP, 'mlepProcess'), 'EP must be an object of class mlepProcess.');
assert(EP.isRunning, 'EP-cosim object must be already running (use method start).');

assert(0 < TS && TS <= 1, 'Timestep TS must be between (0, 1].');

assert(rem(M, 1) == 0 && 1 <= M && M <= 12, 'Month M must be a whole number between 1 and 12.');
assert(rem(D, 1) == 0 && 1 <= D && D <= maxDays(M, true), 'Day of month D must be a whole number and valid for the given month.');
assert(0 <= TOD && TOD < 24, 'Time of day TOD must be between 0 and 24.');

hasFB = nargin > 5 && ~isempty(FB);
if hasFB
    assert(isa(FB, 'function_handle'), 'Feedback function FB must be a function handle.');
end


%% Main algorithm: Spin up E+

% Initialize these variables here to be updated by nested function(s)
EPY = 0; EPM = 0; EPD = 0; EPTOD = 0;

% First read from E+ to determine current time and year
[flag, simtime, outputs] = readFromEP;
if flag ~= 0
    % E+ quits
    error('spinUpEP:EPQuit', 'EnergyPlus terminates prematurely with flag = %d.', flag);
end

% If EP's year is not a leap year but M = 2, D = 29 then adjust D because
% Feb 29th does not exist.
leapyear = isLeapYear(EPY);
if M == 2 && D == 29 && ~leapyear
    warning('spinUpEP:noFeb29', 'There is no Feb 29th for the year in EnergyPlus. Adjusted to Feb 28th instead.');
    D = 28;
end

if isLaterTime(EPM, EPD, EPTOD, M, D, TOD)
    error('spinUpEP:InvalidTime', 'EnergyPlus'' current time is later than the desired time.');
end

inputs = [];  % the inputs to E+ (default to [] if no feedback)

nextStep = struct('M', 0, 'D', 0, 'TOD', 0);
[nextStep.M, nextStep.D, nextStep.TOD] = addTime(EPM, EPD, EPTOD, TS, leapyear);

while ~isLaterTime(nextStep.M, nextStep.D, nextStep.TOD, M, D, TOD)
    if hasFB
        inputs = FB(outputs);
    end
    
    % Write to inputs of E+
    EP.write(mlepEncodeRealData(EP.version, 0, simtime, inputs));
    
    % Read from E+
    [flag, simtime, outputs] = readFromEP;
    if flag ~= 0
        % E+ quits
        error('spinUpEP:EPQuit', 'EnergyPlus terminates prematurely with flag = %d.', flag);
    end

    [nextStep.M, nextStep.D, nextStep.TOD] = addTime(EPM, EPD, EPTOD, TS, leapyear);
end

% At this point, we should have nextStep exceeding desired time. We can
% return now.

    % Helper functions
    function [flag, simtime, outputs] = readFromEP
        packet = EP.read;
        if isempty(packet)
            error('spinUpEP:commError', 'Could not read outputs from E+.');
        end
        
        % Parse it to obtain building outputs
        [flag, simtime, outputs] = mlepDecodePacket(packet);
        EPY = outputs(1);
        EPM = outputs(2);
        EPD = outputs(3);
        EPTOD = outputs(4);
    end

end

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

function ly = isLeapYear(y)
ly = (rem(y, 4) == 0) && (rem(y, 100) ~= 0 || rem(y, 400) == 0);
end

function l = isLaterTime(m1, d1, tod1, m2, d2, tod2)
% Check if time1 > time2 (strictly)
% Convert (m,d,tod) to a number then compare
% the coefficients
wd = 32; % wd >= 24
wm = 32*wd;  % >= (31+1)*wd >= 31*wd + 24
l = (m1*wm + d1*wd + tod1) > (m2*wm + d2*wd + tod2);
end