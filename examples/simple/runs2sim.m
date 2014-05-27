% Run simple co-simulation with S2Sim.
% Based on run.m
%
% (C) 2014 by Truong X. Nghiem (nghiem@seas.upenn.edu)
%
% CHANGES:
%   2014-05-25  Started from run.m

%% Configuration of S2Sim & E+
s2sim.server = 'seelabc.ucsd.edu';
s2sim.port = 26999;
s2sim.name = 'canyonview_apt';

EPTimeStep = 6;  % the Timestep parameter from the IDF file
deltaT = (60/EPTimeStep)*60;  % time step, in seconds


%% Create an mlepProcess instance and configure it

ep = mlepProcess;
ep.arguments = {'LargeHotel', 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3'};
ep.acceptTimeout = 20000;

VERNUMBER = 2;  % version number of communication protocol (2 for E+ 6.0.0)

ep.setRWTimeout(15000);


%% Start EnergyPlus cosimulation
[status, msg] = ep.start;

if status ~= 0
    error('Could not start EnergyPlus: %s.', msg);
end

disp('Started and connected to E+.');

%% Ping S2Sim to see if it's alive, and check its time & version
disp('Ping S2Sim server and retrieve its version and time...');

[ status, s2sim.major, s2sim.minor ] = promptS2SimVersion( s2sim.server, s2sim.port );

if status ~= 0
    ep.stop;
    error('Cannot get the version from S2Sim server. S2Sim may not be online.');
end
fprintf('S2Sim Version: %d.%d\n', s2sim.major, s2sim.minor);
    
[ status, ServerTime ] = promptS2SimTime( s2sim.server, s2sim.port );

if status ~= 0
    ep.stop;
    error('Cannot get the time from S2Sim server.');
end

fprintf('S2Sim Current Time is: %d, which is %s\n',...
    ServerTime, datestr(epoch2matlab(ServerTime)));

% If it's too close to end of year, then stop the simulation because we may
% not able to catch up with S2Sim
[S2M, S2D, S2TOD] = epochTimeExtract(ServerTime);
if S2M == 12 && S2D == 31 && S2TOD >= (23 + 59/60)
    disp('S2Sim time is too close to end of year. Simulation will not continue. Please wait a few minutes and rerun.');
    ep.stop;
    return;
end


%% Spin up E+ to S2Sim time
disp('Spinning E+ up to S2Sim simulation time...');

spinUpTrials = 1;
MAXSPINUPTRIALS = 5;

while spinUpTrials <= MAXSPINUPTRIALS
    try
        [nextStep, flag, eptime, outputs] = spinUpEP(ep, 1/EPTimeStep, S2M, S2D, S2TOD);
    catch err
        ep.stop;
        rethrow(err);
    end
    
    % Get server time again to synchronize
    [ status, ServerTime ] = promptS2SimTime( s2sim.server, s2sim.port );
    
    if status ~= 0
        ep.stop;
        error('Cannot get the time from S2Sim server.');
    end
    
    [S2M, S2D, S2TOD] = epochTimeExtract(ServerTime);
    
    % Check if next time step is after the server time
    if isLaterTime(nextStep.M, nextStep.D, nextStep.TOD, S2M, S2D, S2TOD)
        break;
    end
    
    % Send inputs to E+ because spinUpEP didn't do that
    ep.write(mlepEncodeRealData(ep.version, 0, eptime, []));
    
    spinUpTrials = spinUpTrials + 1;
end

if spinUpTrials > MAXSPINUPTRIALS
    ep.stop;
    error('Could not spin up E+ to catch up with S2Sim.');
end

disp('Finished spinning up E+. Now do simulation...');


%% Connect to S2Sim

[status, s2sim.socket, s2sim.id, seq, info ] = connectToS2Sim( s2sim.server, s2sim.port, s2sim.name );
if status ~= 0
    disp('Error while connecting to S2Sim:');
    if status < 0
        fprintf('Connection error: %s.\n', socket.message);
    else
        fprintf('S2Sim error: %s.\n', s2sim.id);
    end
    return;
end
fprintf('Successfully connected to S2Sim with ID: %d.\n', s2sim.id);
fprintf('Current server time: %d, time step: %d, number of clients: %d, server mode: %d.\n',...
    info.CurrentTime, info.TimeStep, info.NumberClients, info.SystemMode);


%% Simulation with S2Sim & E+
% IMPORTANT NOTE: after spinning up, the message from E+ for the current
% time step has already been read. We must write to E+ in order to advance
% in time.

kStep = 1;  % current simulation step
MAXSTEPS = 2; %1*EPTimeStep;  % max simulation time, in steps

% logdata stores the electricity demand of the entire plant
logdata = zeros(MAXSTEPS, 6);

TimeStep = 1/EPTimeStep;  % time step in hours

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
    
    % Now that we have the power of the building, use it for S2Sim
    % co-simulation
    curDemand = outputs(6);
    
    seq = sendDemandToS2Sim( s2sim.socket, s2sim.id, seq, curDemand );
    
    % Co-simulation with S2Sim until the next step
    while true
        % Wait until we receive a SetPrice message
        [success, rcvMsg, seq] = getMsgFromS2Sim(s2sim.socket, 'SetPrice');
        if success < 0
            disconnectFromS2Sim(s2sim.socket);
            ep.stop;
            error('We have been waiting for a while but did not receive the SetPrice message.');
        elseif success > 0
            disconnectFromS2Sim(s2sim.socket);
            ep.stop;
            error('Error while receiving messages: %s', rcvMsg);
        end
        
        rcvData = rcvMsg.Data;
        
        % Extract the current server time
        [S2M, S2D, S2TOD, S2Y] = epochTimeExtract(double(rcvData.TimeBegin));
        
        % Compare it with next step and advance E+ step if it's due
        % WARNING: there is a potential bug here: if nextStep is at the
        % very end of the year, and somehow S2Sim time progresses beyond
        % that point and is reset to the year's beginning, then this will
        % break apart. The resolution could be to use the year in the time
        % calculations.
        if ~isLaterTime(nextStep.M, nextStep.D, nextStep.TOD, S2M, S2D, S2TOD)
            break;
        end
        
        % Respond with my demand
        seq = sendDemandToS2Sim( s2sim.socket, s2sim.id, seq, curDemand );
    end
    
    % Update nextStep
    [nextStep.M, nextStep.D, nextStep.TOD] = addTime(S2M, S2D, S2TOD, 1/EPTimeStep, isLeapYear(S2Y));
    
    kStep = kStep + 1;
end

%% Finalization, quit

%Stop EnergyPlus
ep.stop;

disp(['Stopped with flag ' num2str(flag)]);

disconnectFromS2Sim(s2sim.socket);

% Remove unused entries in logdata
kStep = kStep - 1;
if kStep < MAXSTEPS
    logdata((kStep+1):end,:) = [];
end

%% Plot results
% fprintf('The current date is %d-%d-%d, which is day %d (1=Sun,...,7=Sat).\n',...
%     logdata(1, 3), logdata(1, 2), logdata(1, 1), logdata(1, 5));
% logdata(logdata(:,4) >= 24, 4) = 0;
% plot(logdata(1, 4) + (0:(size(logdata,1)-1))/EPTimeStep, logdata(:, 6)/1000);
% title('Electricity demand of entire plant');
% xlabel('Time (hour)');
% ylabel('Demand [kW]');
