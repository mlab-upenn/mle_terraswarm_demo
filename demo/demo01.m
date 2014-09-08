% TerraSwarm Demo
% This Demo 01 connects one building (LargeHotel) to S2Sim with accelerated
% time steps (each 1-second time step of S2Sim is considered to be 1 time
% step, typically 10 minutes, of E+. The goals of this demo are:
% - Couple E+ and S2Sim, feed building's load to S2Sim
%
%
% (C) 2014 by Truong X. Nghiem (nghiem@seas.upenn.edu)
%
% CHANGES:
%   2014-06-17  Started from runs2sim.m (example folder).

%% Configuration of S2Sim & E+
s2sim.server = 'seelabc.ucsd.edu';
s2sim.port = 26999;
s2sim.name = 'canyonview_apt';

EPTimeStep = 6;  % the Timestep parameter from the IDF file
deltaT = (60/EPTimeStep)*60;  % time step, in seconds


%% Ping S2Sim to see if it's alive, and check its time & version
disp('Ping S2Sim server and retrieve its version and time...');

[ status, s2sim.major, s2sim.minor ] = promptS2SimVersion( s2sim.server, s2sim.port );

if status ~= 0
    error('Cannot get the version from S2Sim server. S2Sim may not be online.');
end
fprintf('S2Sim Version: %d.%d\n', s2sim.major, s2sim.minor);
    
[ status, ServerTime ] = promptS2SimTime( s2sim.server, s2sim.port );

if status ~= 0
    error('Cannot get the time from S2Sim server.');
end

fprintf('S2Sim Current Time is: %d, which is %s\n',...
    ServerTime, datestr(epoch2matlab(ServerTime)));



%% Create an mlepProcess instance and configure it

ep = mlepProcess;
ep.arguments = {'LargeHotel', 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3'};
ep.acceptTimeout = 20000;
ep.workDir = 'hotel';

VERNUMBER = 2;  % version number of communication protocol (2 for E+ 6.0.0)

ep.setRWTimeout(15000);


%% Start EnergyPlus cosimulation
[status, msg] = ep.start;

if status ~= 0
    error('Could not start EnergyPlus: %s.', msg);
end

disp('Started and connected to E+.');

pause(4);


%% Connect to S2Sim

[status, s2sim.socket, s2sim.id, seq, info ] = connectToS2Sim( s2sim.server, s2sim.port, s2sim.name );
if status ~= 0
    disp('Error while connecting to S2Sim:');
    if status < 0
        fprintf('Connection error: %s.\n', s2sim.socket.message);
    else
        fprintf('S2Sim error: %s.\n', s2sim.id);
    end
    ep.stop;
    return;
end
fprintf('Successfully connected to S2Sim with ID: %d.\n', s2sim.id);
fprintf('Current server time: %d, time step: %d, number of clients: %d, server mode: %d.\n',...
    info.CurrentTime, info.TimeStep, info.NumberClients, info.SystemMode);


%% Simulation with S2Sim & E+
% IMPORTANT NOTE: because of the accelerated simulation mode, we don't spin
% up E+ to match the current system time of S2Sim. There is no need to
% synchronize the time of the server and clients, because they run on
% different time scale.

kStep = 1;  % current simulation step
MAXSTEPS = 1*24*EPTimeStep;  % max simulation time, in steps
timeScale = 2;  % number of S2Sim time steps before we advance one step

% logdata stores the electricity demand of the entire plant
logdata = zeros(MAXSTEPS, 6);

instants = [];
prices = [];

TimeStep = 1/EPTimeStep;  % time step in hours

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
    
     % Save to logdata
    logdata(kStep, :) = outputs(1:6);
    
    % Write to inputs of E+
    % Because we don't input anything to E+, the message is empty
    ep.write(mlepEncodeRealData(VERNUMBER, 0, eptime, []));
    
    % Now that we have the power of the building, use it for S2Sim
    % co-simulation
    curDemand = outputs(6);
    
    % Co-simulation with S2Sim until the next step
    s2simStep = 0;
    while s2simStep < timeScale
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
        
        instants(end+1) = double(rcvData.TimeBegin);
        prices(end+1) = double(rcvData.Prices(1));
        
        % Respond with my demand
        seq = sendDemandToS2Sim( s2sim.socket, s2sim.id, seq, curDemand );
        
        s2simStep = s2simStep + 1;
    end
    
    
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
logdata(logdata(:,4) >= 24, 4) = 0;
figure;
plot(logdata(1, 4) + (0:(size(logdata,1)-1))/EPTimeStep, logdata(:, 6)/1000);
title('Electricity demand of entire plant');
xlabel('Time (hour)');
ylabel('Demand [kW]');

figure;
plot(prices);
title('Electricity Price');
xlabel('Time');
ylabel('Price');
