function nextStep = spinUpEP(EP, TS, M, D, TOD, FB)
%SPINUPEP Spin up E+ simulation till a given time of year.
%   nextStep = spinUpEP(EP, TS, M, D, TOD, FB)
%spins up an EnergyPlus co-simulation EP (mlepProcess), with timestep TS
%(in minutes), to a given date of year M/D (M: 1-12, D: 1-31) and time of
%day TOD (0.0 to 24.0 as fraction of hours).  A requirement of the
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
%ensure time synchronization with other processes.
%
%The function will stop and give an error if the given time (M, D, TOD) is
%before the current time in EnergyPlus.  To be safe, make sure that the E+
%simulation starts from Jan 1st, 00:00.
%
%(C) 2014 by Truong X. Nghiem (nghiem@seas.upenn.edu)


end

