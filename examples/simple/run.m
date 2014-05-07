% (C) 2014 by Truong X. Nghiem (nghiem@seas.upenn.edu)
%
% CHANGES:
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
logdata = zeros(MAXSTEPS, 1);

while kStep <= MAXSTEPS
    disp('Tick');
    
    % Read a data packet from E+
    packet = ep.read;
    if isempty(packet)
        error('Could not read outputs from E+.');
    end
    
    % Parse it to obtain building outputs
    [flag, eptime, outputs] = mlepDecodePacket(packet);
    if flag ~= 0, break; end
        
    % Write to inputs of E+
    ep.write(mlepEncodeRealData(VERNUMBER, 0, (kStep-1)*deltaT, []));    

    % Save to logdata
    logdata(kStep, :) = outputs;
    
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
plot([0:(kStep-1)]'*deltaT/3600, logdata);
title('Electricity demand of entire plant');
xlabel('Time (hour)');
ylabel('Demand [W]');
