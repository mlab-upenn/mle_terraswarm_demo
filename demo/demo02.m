% TerraSwarm Demo
% This Demo 02 connects one building (LargeOffice) to S2Sim with accelerated
% time steps.  The building has a simple, rule-based DR control.
%
% (C) 2014 by Truong X. Nghiem (nghiem@seas.upenn.edu)
%
% CHANGES:
%   2014-09-08  Started.

%% Configuration of S2Sim & E+
s2sim.server = 'seelabc.ucsd.edu';
s2sim.port = 26999;
s2sim.name = 'canyonview_apt';

IDFmodel = 'LargeOffice';
IDFDir = 'office';
WeatherFile = 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3';

EPTimeStep = 6;  % the Timestep parameter from the IDF file
deltaT = (60/EPTimeStep)*60;  % time step, in seconds


%% EnergyPlus model and DR configuration
% The settings for DR strategy
% The DR rule has two levels of curtailment:
% - Level 0: triggered when price is > THRESHOLD0, which will increase the
%   cooling setpoint by DCOOLSP0 (Celsius), the SAT by DSATSP0 (Celsius),
%   and reduce the lighting level by DLIGHT0 < 0 (0-1, which is \% of
%   full lighting power).
% - Level 1: triggered when price is > THRESHOLD1 >= 0, which will
%   increase the cooling setpoint by DCOOLSP1 (Celsius), the SAT by DSATSP1
%   (Celsius), and reduce the lighting level by DLIGHT1 < 0 (0-1, which is
%   \% of full lighting power).
% There are optional limits on the rates of change of the cooling and SAT
% setpoints, specified by COOLRATELIM and SATRATELIM, i.e. from one time
% step to the next, the setpoints cannot change more than the corresponding
% limit. If these limits are set to inf or very large values, the limits
% are effectively disabled.
DRparams = struct(...
    'THRESHOLD0', 180,...
    'DCOOLSP0', 1, ...
    'DSATSP0', 0,...
    'DLIGHT0', -0.1,...
    'THRESHOLD1', 250,...
    'DCOOLSP1', 2, ...
    'DSATSP1', 0.5,...
    'DLIGHT1', -0.3,...
    'COOLRATELIM', inf,...
    'SATRATELIM', inf...
    );



%% Configure the DR control strategies

% These normal/non-DR schedules are copied from the IDF file
CLGSETP_SCH = SPSchedule(...
    'Weekdays',...
    06,26.7,...
    22,24.0,...
    24,26.7,...
    'Saturday',...
    06,26.7,...
    18,24.0,...
    24,26.7,...
    'AllOtherDays',...
    24,26.7);

SAT_SCH = SPSchedule(...
    'AllDays',...
    24,12.8);

LIGHT_SCH = SPSchedule(...
    'Weekdays',...
    05,0.05,...
    07,0.1,...
    08,0.3,...
    17,0.9,...
    18,0.7,...
    20,0.5,...
    22,0.3,...
    23,0.1,...
    24,0.05,...
    'Saturday',...
    06,0.05,...
    08,0.1,...
    14,0.5,...
    17,0.15,...
    24,0.05,...
    'AllOtherDays',...
    24,0.05);

% EQUIP_SCH = SPSchedule(...
%     'Weekdays',...
%     08,0.40,...
%     12,0.90,...
%     13,0.80,...
%     17,0.90,...
%     18,0.80,...
%     20,0.60,...
%     22,0.50,...
%     24,0.40,...
%     'Saturday',...
%     06,0.30,...
%     08,0.4,...
%     14,0.5,...
%     17,0.35,...
%     24,0.30,...
%     'AllOtherDays',...
%     24,0.30);
% 
% CWLOOP_SCH = SPSchedule(...
%     'AllDays',...
%     24,6.7);


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
ep.arguments = {IDFmodel, WeatherFile};
ep.acceptTimeout = 20000;
ep.workDir = IDFDir;

VERNUMBER = 2;  % version number of communication protocol (2 for E+ 6.0.0)

ep.setRWTimeout(10000);


%% Start EnergyPlus cosimulation
[status, msg] = ep.start;

if status ~= 0
    error('Could not start EnergyPlus: %s.', msg);
end

disp('Started and connected to E+. Wait a few seconds for E+ to warm up.');

pause(6);


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
MAXSTEPS = 3*24*EPTimeStep;  % max simulation time, in steps
timeScale = 10;  % number of S2Sim time steps before we advance one step

% logdata stores the electricity demand of the entire plant
%logdata = zeros(MAXSTEPS, 6);

instants = [];
prices = [];

TimeStep = 1/EPTimeStep;  % time step in hours

dCLGSETP = 0;
dSAT = 0;
dLIGHT = 0;

% Read a data packet from E+
packet = ep.read;
if isempty(packet)
    error('Could not read outputs from E+.');
end

% Parse it to obtain building outputs
[flag, eptime, outputs] = mlepDecodePacket(packet);
if flag ~= 0, break; end

% Save to logdata
%logdata(kStep, :) = outputs(1:6);

% Extract interested outputs
% Date and time information from E+
% 1: month, 2: day of month, 3: time of day, 4: day of week (1-7),
% 5: holiday (0: not holiday, >0: holiday)
curMonth = outputs(1);
curDay = outputs(2);
%curTime = outputs(3);
curDoW = outputs(4);
curHoliday = outputs(5);

curTime = rem(eptime, 86400) / 3600;

if curTime >= 24
    curTime = curTime - 24;
end

if curHoliday > 0
    curDayType = 0;
else
    curDayType = curDoW;
end

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

curPrice = double(rcvData.Prices(1));

instants(end+1) = double(rcvData.TimeBegin);
prices(end+1) = curPrice;

hWaitBar = waitbar(0, 'Simulating the building with S2Sim...');

while kStep <= MAXSTEPS
    % disp('Tick');
    waitbar(kStep / MAXSTEPS);
    
    % Adjust the setpoints if DR is triggered
    if curPrice > DRparams.THRESHOLD1
        % Activate level 1
        dCLGSETP = min(dCLGSETP+DRparams.COOLRATELIM, DRparams.DCOOLSP1);
        dSAT = min(dSAT+DRparams.SATRATELIM, DRparams.DSATSP1);
        dLIGHT = DRparams.DLIGHT1;
    elseif curPrice > DRparams.THRESHOLD0
        % Activate level 0
        dCLGSETP = min(dCLGSETP+DRparams.COOLRATELIM, DRparams.DCOOLSP0);
        dSAT = min(dSAT+DRparams.SATRATELIM, DRparams.DSATSP0);
        dLIGHT = DRparams.DLIGHT0;
    else
        % Deactivate DR --> returns to normal
        dCLGSETP = max(dCLGSETP-DRparams.COOLRATELIM, 0);
        dSAT = max(dSAT-DRparams.SATRATELIM, 0);
        dLIGHT = 0;
    end
    
    % Compute control values
    CLGSETP = CLGSETP_SCH.GetValue(curDayType, curTime) + dCLGSETP;
    SAT = SAT_SCH.GetValue(curDayType, curTime) + dSAT;
    LIGHT = LIGHT_SCH.GetValue(curDayType, curTime) + dLIGHT;
        
    % Write to inputs of E+
    ep.write(mlepEncodeRealData(VERNUMBER, 0, eptime, [CLGSETP, SAT, LIGHT]));
    
    % Read a data packet from E+
    packet = ep.read;
    if isempty(packet)
        error('Could not read outputs from E+.');
    end
    
    % Parse it to obtain building outputs
    [flag, eptime, outputs] = mlepDecodePacket(packet);
    if flag ~= 0, break; end
    
    % Save to logdata
    %logdata(kStep, :) = outputs(1:6);
    
    % Extract interested outputs
    % Date and time information from E+
    % 1: month, 2: day of month, 3: time of day, 4: day of week (1-7),
    % 5: holiday (0: not holiday, >0: holiday)
    curMonth = outputs(1);
    curDay = outputs(2);
    %curTime = outputs(3);
    curDoW = outputs(4);
    curHoliday = outputs(5);
    
    curTime = rem(eptime, 86400) / 3600;    
    
    if curTime >= 24
        curTime = curTime - 24;
    end
    
    if curHoliday > 0
        curDayType = 0;
    else
        curDayType = curDoW;
    end
    
    
    % Now that we have the power of the building, use it for S2Sim
    % co-simulation
    curDemand = outputs(6);
    
    % Co-simulation with S2Sim until the next step
    s2simStep = 0;
    while s2simStep < timeScale
        % Respond with my demand
        seq = sendDemandToS2Sim( s2sim.socket, s2sim.id, seq, curDemand );
        
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
        
        curPrice = double(rcvData.Prices(1));
        
        instants(end+1) = double(rcvData.TimeBegin);
        prices(end+1) = curPrice;

        
        s2simStep = s2simStep + 1;
    end
    
    kStep = kStep + 1;
end

%% Finalization, quit

close(hWaitBar);

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

% Wait a few seconds for E+ to finish
pause(3);

cd(IDFDir);
OutputFile = 'Output/LargeOffice.csv';

VARS = mlepLoadEPResults(OutputFile, 'vars');
allObjs = {VARS.object};
allVars = {VARS.name};

LoadVar = findEPResultVar('Whole Building', 'Facility Total Electric Demand Power', allObjs, allVars);
CLGSETPVar = findEPResultVar('CLGSETP_SCH', 'Schedule Value', allObjs, allVars);
LIGHTVar = findEPResultVar('BLDG_LIGHT_SCH', 'Schedule Value', allObjs, allVars);
SATVar = findEPResultVar('Seasonal-Reset-Supply-Air-Temp-Sch', 'Schedule Value', allObjs, allVars);

[VARS, DATA, TS] = mlepLoadEPResults(OutputFile, [LoadVar, CLGSETPVar, LIGHTVar, SATVar]);

figure;

subplot(411)
plot(prices)
ylabel('Price');

subplot(412)
plot(DATA(:,1))
ylabel('Load');

subplot(413)
plot(DATA(:,[2,4]))
ylabel('COOL & SAT');

subplot(414)
plot(DATA(:,3))
ylabel('LIGHT');