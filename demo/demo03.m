function varargout = demo03(varargin)
% DEMO03 MATLAB code for demo03.fig
%      DEMO03, by itself, creates a new DEMO03 or raises the existing
%      singleton*.
%
%      H = DEMO03 returns the handle to a new DEMO03 or the handle to
%      the existing singleton*.
%
%      DEMO03('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in DEMO03.M with the given input arguments.
%
%      DEMO03('Property','Value',...) creates a new DEMO03 or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before demo03_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to demo03_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help demo03

% Last Modified by GUIDE v2.5 17-Sep-2014 14:01:50

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @demo03_OpeningFcn, ...
                   'gui_OutputFcn',  @demo03_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before demo03 is made visible.
function demo03_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to demo03 (see VARARGIN)

% Choose default command line output for demo03
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes demo03 wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = demo03_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;



function edit1_Callback(hObject, eventdata, handles)
% hObject    handle to edit1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit1 as text
%        str2double(get(hObject,'String')) returns contents of edit1 as a double


% --- Executes during object creation, after setting all properties.
function edit1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function s2simAddr_Callback(hObject, eventdata, handles)
% hObject    handle to s2simAddr (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of s2simAddr as text
%        str2double(get(hObject,'String')) returns contents of s2simAddr as a double


% --- Executes during object creation, after setting all properties.
function s2simAddr_CreateFcn(hObject, eventdata, handles)
% hObject    handle to s2simAddr (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function s2simPort_Callback(hObject, eventdata, handles)
% hObject    handle to s2simPort (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of s2simPort as text
%        str2double(get(hObject,'String')) returns contents of s2simPort as a double


% --- Executes during object creation, after setting all properties.
function s2simPort_CreateFcn(hObject, eventdata, handles)
% hObject    handle to s2simPort (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function s2simName_Callback(hObject, eventdata, handles)
% hObject    handle to s2simName (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of s2simName as text
%        str2double(get(hObject,'String')) returns contents of s2simName as a double


% --- Executes during object creation, after setting all properties.
function s2simName_CreateFcn(hObject, eventdata, handles)
% hObject    handle to s2simName (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in btnTestS2Sim.
function btnTestS2Sim_Callback(hObject, eventdata, handles)
% hObject    handle to btnTestS2Sim (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
s2simAddr = get(handles.s2simAddr, 'String');
s2simPort = str2double(get(handles.s2simPort, 'String'));
s2simName = get(handles.s2simName, 'String');

[ status, s2simMajor, s2simMinor ] = promptS2SimVersion( s2simAddr, s2simPort );

if status == 0
    [ status, ServerTime ] = promptS2SimTime( s2simAddr, s2simPort );
end
    
if status ~= 0
    msgbox(sprintf('S2Sim Server not responding at address %s:%d', s2simAddr, s2simPort));
else
    msgbox(sprintf('S2Sim at %s:%d has version %d.%d and time %d, which is %s.', ...
        s2simAddr, s2simPort, s2simMajor, s2simMinor, ServerTime, datestr(epoch2matlab(ServerTime))));
end
