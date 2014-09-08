classdef SPSchedule
%SPSchedule EnergyPlus Schedules
%   This class represents a schedule, similar to those defined in
%   EnergyPlus.  Methods are defined to return the value of the
%   schedule at a specified time on a specified day.
%
% (C) 2014 by Truong X. Nghiem (truong.nghiem@gmail.com)
    
    properties (SetAccess=protected)
        % These are the schedules for each type of days
        % Each is a n-by-2 matrix: the first column contains the
        % time of day (0-24) in ascending order, the second column
        % contains the values.
        WeekDays = [];
        Saturday = [];
        Sunday = [];
        Holidays = [];
        OtherDays = [];
    end
    
    methods
        function obj = SPSchedule(varargin)
        % Constructor of the form:
        % obj = SPSchedule('WeekDays', 6, 28, 18, 24, 24, 28,
        %                  'Saturday', 24, 28, 'AllOthers', 24,
        %                  28);
        % Currently supported day types are:
        % WeekDays, Saturday, Sunday, Weekends, AllOtherDays,
        % Holidays, AllDays
        
            if nargin > 0
                % Find type names
                typeidx = find(cellfun('isclass', varargin, ...
                                       'char'));
                nTypes = length(typeidx);
                
                % The first input argument must be a day type
                assert(nTypes > 0 && typeidx(1) == 1,...
                       'Day types must be provided.');

                typeidx = [typeidx, nargin+1];
                for ii = 1:nTypes
                    % For each type, call SetSched to set the
                    % schedule
                    args = varargin(typeidx(ii)+1:typeidx(ii+1)-1);
                    obj = obj.SetSched(varargin{typeidx(ii)}, ...
                                       args{:});
                end
            end
        end
        
        function obj = SetSched(obj, type, varargin)
        % Set the schedule for certain type of days.
            assert(isa(type, 'char'),...
                   'Day type must be a supported string.');
            switch lower(type)
              case 'weekdays'
                obj.WeekDays = obj.GetSchedMatrix(varargin{:});
              case 'saturday'
                obj.Saturday = obj.GetSchedMatrix(varargin{:});
              case 'sunday'
                obj.Sunday = obj.GetSchedMatrix(varargin{:});
              case 'weekends'
                obj.Saturday = obj.GetSchedMatrix(varargin{:});
                obj.Sunday = obj.Saturday;
              case 'holidays'
                obj.Holidays = obj.GetSchedMatrix(varargin{:});
              case 'allotherdays'
                obj.OtherDays = obj.GetSchedMatrix(varargin{:});
              case 'alldays'
                % Set all days to this schedule by resetting all
                % schedules except for OtherDays
                obj.OtherDays = obj.GetSchedMatrix(varargin{:});
                obj.WeekDays = [];
                obj.Saturday = [];
                obj.Sunday = [];
                obj.Holidays = [];
              otherwise
                error('Day type %s is not supported.', type);
            end
        end
        
        function sp = GetValue(obj, day, T)
        % Get the SP value for a day at a given time T
        % day: 0=holiday, 1=sunday, 2=monday,..., 7=saturday
        % T: hour between 0 and 24
            
            assert(T >= 0 && T < 24,...
                   'Time of day must be >= 0 and < 24');
            
            if day >= 2 && day <= 6
                sched = obj.WeekDays;
            elseif day == 1
                sched = obj.Sunday;
            elseif day == 7
                sched = obj.Saturday;
            elseif day == 0
                sched = obj.Holidays;
            else
                error('Invalid day %d', day);
            end
            
            if isempty(sched)
                % No schedule -> use OtherDays
                assert(~isempty(obj.OtherDays),...
                       'No schedule found.');
                
                sched = obj.OtherDays;
            end
                
            % Find the entry applicable to T
            idx = find(T < sched(:,1), 1);
            assert(~isempty(idx), 'Incorrect schedule');
            sp = sched(idx, 2);
        end
    end
    
    methods (Access=protected, Static)
        function sched = GetSchedMatrix(varargin)
        % Convert a sequence of input arguments to a schedule
        % matrix
            if nargin == 0
                sched = [];
            elseif nargin == 1
                % Must be a single matrix to be used directly
                sched = varargin{1};
                
                if isempty(sched)
                    return;
                end
                
                assert(isa(sched, 'double') && 2 == size(sched,2), ...
                       ['A single input argument must be a 2-column ' ...
                        'matrix.']);
                
                % Elements in the first column must be unique and
                % sorted, and between 0 and 24.
                instants = sched(:, 1);
                assert(all(instants > 0 & instants <= 24),...
                       'Time instants must be between 0 and 24.');                
                assert(all(diff(instants) > 0.01),...
                       ['Time instants must be sorted in increasing ' ...
                        'order.']);
                
                % The last entry must be for instant 24
                assert(instants(end) == 24,...
                       'Schedule must cover entire 24 hours.');
            elseif rem(nargin, 2) == 0
                % An even number of values: collect them to a
                % matrix and call this function again
                sched = SPSchedule.GetSchedMatrix(reshape(cell2mat(varargin), 2, []).');
            else
                error('Incorrect input for a schedule.');
            end
        end
        
    end
    
end

