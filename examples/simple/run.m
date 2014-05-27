% Run simple co-simulation with EnergyPlus locally (no S2Sim).
%
% (C) 2014 by Truong X. Nghiem (nghiem@seas.upenn.edu)
%
% CHANGES:
%   2014-05-24  Added spinning up to a given time.
%   2014-05-06  Truong started

%% Create an mlepProcess instance and configure it

ep = mlepProcess;
ep.arguments = {'LargeHotel', 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3'};
ep.acceptTimeout = 20000;

VERNUMBER = 2;  % version number of communication protocol (2 for E+ 6.0.0)

ep.setRWTimeout(10000);


%% Start EnergyPlus cosimulation
[status, msg] = ep.start;

if status ~= 0
    error('Could not start EnergyPlus: %s.', msg);
end

disp('Started and connected to E+.');

%% The main simulation loop

EPTimeStep = 6;  % the Timestep parameter from the IDF file

deltaT = (60/EPTimeStep)*60;  % time step, in seconds
kStep = 1;  % current simulation step
MAXSTEPS = 1*24*EPTimeStep;  % max simulation time (first number is in days)

% logdata stores the electricity demand of the entire plant
logdata = zeros(MAXSTEPS, 6);

% Spin up E+ to a certain time
disp('Spinning E+ up to given time...');
try
    [nextStep, flag, eptime, outputs] = spinUpEP(ep, 1/EPTimeStep, 1, 10, 5);
catch err
    ep.stop;
    rethrow(err);
end
disp('Finished spinning up E+. Now do simulation...');

% IMPORTANT NOTE: after spinning up, the message from E+ for the current
% time step has already been read. We must write to E+ in order to advance
% in time.

while kStep <= MAXSTEPS
    disp('Tick');
    
    % Save to logdata
    logdata(kStep, :) = outputs;
    
    % Write to inputs of E+
    % Because we don't input anything to E+, the message is empty
    ep.write(mlepEncodeRealData(VERNUMBER, 0, eptime, []));    
    
    % Read a data packet from E+
    packet = ep.read;
    if isempty(packet)
        error('Could not read outputs from E+.');
    end
    
    % Parse it to obtain building outputs
    [flag, eptime, outputs] = mlepDecodePacket(packet);
    if flag ~= 0, break; end
    
    kStep = kStep + 1;
end

% Stop EnergyPlus
ep.stop;

disp(['Stopped with flag ' num2str(flag)]);

% Remove unused entries in logdata
kStep = kStep - 1;
if kStep < MAXSTEPS
    logdata((kStep+1):end,:) = [];
end

% Plot results
fprintf('The current date is %d-%d-%d, which is day %d (1=Sun,...,7=Sat).\n',...
    logdata(1, 3), logdata(1, 2), logdata(1, 1), logdata(1, 5));
logdata(logdata(:,4) >= 24, 4) = 0;
plot(logdata(1, 4) + (0:(size(logdata,1)-1))/EPTimeStep, logdata(:, 6)/1000);
title('Electricity demand of entire plant');
xlabel('Time (hour)');
ylabel('Demand [kW]');
