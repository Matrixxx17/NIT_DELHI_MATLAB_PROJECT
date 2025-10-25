classdef FitSightApp < handle
    % FitSight – AI-Powered Smart Fitness Assistant (programmatic App Designer-style UI)
    %
    % This class builds a uifigure-based app with:
    % - Live camera preview (via webcam if available)
    % - Skeleton overlay (placeholder until pose works)
    % - Reps, angles, intensity, alerts panels
    % - Start/Stop controls and session summary
    %
    % The app is structured to run even if Computer Vision Toolbox is not present,
    % by stubbing pose with a lightweight placeholder (center point only).
    properties (Access = public)
        UIFigure matlab.ui.Figure
        Grid matlab.ui.container.GridLayout
        PreviewAxes matlab.ui.control.UIAxes
        RightPanel matlab.ui.container.Panel
        StartButton matlab.ui.control.Button
        StopButton matlab.ui.control.Button
        MuteToggle matlab.ui.control.StateButton
        ExerciseDropDown matlab.ui.control.DropDown
        HeightField matlab.ui.control.NumericEditField
        WeightField matlab.ui.control.NumericEditField
        GoalDropDown matlab.ui.control.DropDown
        IPCamURLField matlab.ui.control.EditField
        IPCamConnectButton matlab.ui.control.Button
        WebcamDropDown matlab.ui.control.DropDown
        WebcamConnectButton matlab.ui.control.Button
        StatusLabel matlab.ui.control.Label
        RepsLabel matlab.ui.control.Label
        AngleLabel matlab.ui.control.Label
        IntensityLabel matlab.ui.control.Label
        AlertLabel matlab.ui.control.Label
        SummaryTextArea matlab.ui.control.TextArea
        CameraObj % webcam object (if available)
        MobileDev % MATLAB Mobile device object (if available)
        IPCamObj % ipcam object (if configured)
        TimerObj % main loop timer
        IsRunning logical = false
        IsMuted logical = false
        ExerciseType char = 'Squat'
        % State
        PrevKeypoints = []
        RepState struct
        RepCount double = 0
        FrameCount double = 0
        SessionStart datetime
        AlertsBuffer string = ""
        % Performance and alert controls
        PoseStride double = 2 % run pose every N frames
        DownscaleWidth double = 320 % width for pose inference, keeps aspect
        LastPoseKeypoints = []
        LastAlertTs double = 0
        MinAlertInterval double = 1.5 % seconds
        % Live exercise classifier
        ClassifierNet
        ClassifierMeta struct
        ClassifyStride double = 5
        LastPredictedExercise char = ''
        LastPredictedScore double = NaN
        AbortFlag logical = false

    end
    methods (Access = public)
        function self = FitSightApp()
            self.buildUI();
            self.bindEvents();
            self.initCamera();
            self.resetSessionState();
            % Try loading exercise classifier if available
            try
                [net, meta] = loadExerciseClassifier();
                if ~isempty(net)
                    self.ClassifierNet = net; self.ClassifierMeta = meta;
                end
            catch
            end
        end
        function delete(self)
            self.stopSession();
            if ~isempty(self.TimerObj) && isvalid(self.TimerObj)
                stop(self.TimerObj); delete(self.TimerObj);
            end
            if ~isempty(self.CameraObj)
                try; clear(self.CameraObj); catch; end
            end
            if ~isempty(self.UIFigure) && isvalid(self.UIFigure)
                delete(self.UIFigure);
            end
        end
    end
    methods (Access = private)
        function buildUI(self)
            % Vibrant, Fitness-Themed Color Palette
            BG_COLOR = [0.2 0.1 0.3]; % Deep Purple
            ACCENT_COLOR = [0.5 1.0 0.2]; % Lime Green
            TEXT_COLOR = [1 1 1]; % White
            BUTTON_START_COLOR = [0.4 0.9 0.1]; % Bright Green
            BUTTON_STOP_COLOR = [0.9 0.2 0.1]; % Bright Red
            
            % UI Figure
            self.UIFigure = uifigure('Name','FitGuru – Smart Fitness Assistant','Color',BG_COLOR);
            self.UIFigure.Position(3:4) = [1100 650];
            self.Grid = uigridlayout(self.UIFigure,[1 2]);
            self.Grid.ColumnWidth = {'3x','1.2x'};
            self.Grid.RowHeight = {'1x'};
            self.Grid.Padding = [15 15 15 15];
            self.Grid.ColumnSpacing = 20; self.Grid.RowSpacing = 10;
            
            % Live Preview Axes
            self.PreviewAxes = uiaxes(self.Grid);
            self.PreviewAxes.Layout.Row = 1; self.PreviewAxes.Layout.Column = 1;
            self.PreviewAxes.XTick = []; self.PreviewAxes.YTick = [];
            self.PreviewAxes.Box = 'on';
            self.PreviewAxes.Color = [0 0 0];
            self.PreviewAxes.XColor = ACCENT_COLOR; % Green border
            self.PreviewAxes.YColor = ACCENT_COLOR; % Green border
            self.PreviewAxes.LineWidth = 3;
            title(self.PreviewAxes,'Live Preview','FontSize',18);
            
            % Main right panel
            self.RightPanel = uipanel(self.Grid,'Title','','BackgroundColor',BG_COLOR,'BorderType','none');
            self.RightPanel.Layout.Row = 1; self.RightPanel.Layout.Column = 2;
            
            % Use a main vertical grid for the right panel
            mainRightGrid = uigridlayout(self.RightPanel, 'RowHeight', {'fit', 'fit', 'fit', 'fit', '1x'});
            mainRightGrid.Padding = [10 10 10 10];
            mainRightGrid.ColumnWidth = {'1x'};
            mainRightGrid.RowSpacing = 15;
            
            % Session Controls Panel
            sessionPanel = uipanel(mainRightGrid, 'Title', 'Workout Settings', 'BackgroundColor', BG_COLOR);
            sessionPanelGrid = uigridlayout(sessionPanel, [5 2], 'RowHeight', {'fit', 'fit', 'fit', 'fit', 'fit'});
            sessionPanelGrid.RowSpacing = 5;
            sessionPanelGrid.Padding = [10 10 10 10];
            
            uilabel(sessionPanelGrid, 'Text','Exercise:','FontColor',TEXT_COLOR,'FontWeight','bold');
            self.ExerciseDropDown = uidropdown(sessionPanelGrid, 'Items',{'Squat','PushUp','Curl','JumpingJack'}, 'Value','Squat');
            self.ExerciseDropDown.BackgroundColor = [0.15 0.15 0.16];
            self.ExerciseDropDown.FontColor = TEXT_COLOR;
            
            uilabel(sessionPanelGrid, 'Text','Height (cm):','FontColor',TEXT_COLOR,'FontWeight','bold');
            self.HeightField = uieditfield(sessionPanelGrid,'numeric','Value',172,'BackgroundColor',[0.15 0.15 0.16],'FontColor',TEXT_COLOR);
            
            uilabel(sessionPanelGrid,'Text','Weight (kg):','FontColor',TEXT_COLOR,'FontWeight','bold');
            self.WeightField = uieditfield(sessionPanelGrid,'numeric','Value',70,'BackgroundColor',[0.15 0.15 0.16],'FontColor',TEXT_COLOR);
            
            uilabel(sessionPanelGrid,'Text','Goal:','FontColor',TEXT_COLOR,'FontWeight','bold');
            self.GoalDropDown = uidropdown(sessionPanelGrid,'Items',{'Maintain','Lose','Gain'},'Value','Maintain');
            self.GoalDropDown.BackgroundColor = [0.15 0.15 0.16];
            self.GoalDropDown.FontColor = TEXT_COLOR;
            
            self.StartButton = uibutton(sessionPanelGrid,'Text','🚀 Start Workout!','FontWeight','bold','FontSize',14,'BackgroundColor',BUTTON_START_COLOR,'FontColor',[0 0 0],'ButtonPushedFcn',@(s,e) self.startSession());
            self.StartButton.Layout.Column = [1 2];
            self.StopButton = uibutton(sessionPanelGrid,'Text','🛑 End Workout','FontWeight','bold','BackgroundColor',BUTTON_STOP_COLOR,'FontColor',TEXT_COLOR,'Enable','off','ButtonPushedFcn',@(s,e) self.stopSession());
            self.StopButton.Layout.Column = [1 2];
            self.MuteToggle = uibutton(sessionPanelGrid,'state','Text','Mute Alerts','FontWeight','bold','BackgroundColor',[0.4 0.4 0.4],'FontColor',TEXT_COLOR,'ValueChangedFcn',@(s,e) self.onMuteToggle());
            self.MuteToggle.Layout.Column = [1 2];
            
            % Live Stats Panel
            statsPanel = uipanel(mainRightGrid, 'Title', 'Live Stats', 'BackgroundColor', BG_COLOR);
            statsPanelGrid = uigridlayout(statsPanel, [4 1], 'RowHeight', {'fit','fit','fit','fit'});
            statsPanelGrid.RowSpacing = 8;
            statsPanelGrid.Padding = [10 10 10 10];
            
            self.RepsLabel = uilabel(statsPanelGrid,'Text','Reps: 0','FontSize',24,'FontWeight','bold','FontColor',ACCENT_COLOR);
            self.AngleLabel = uilabel(statsPanelGrid,'Text','Angle: -','FontSize',18,'FontWeight','bold','FontColor',TEXT_COLOR);
            self.IntensityLabel = uilabel(statsPanelGrid,'Text','Intensity: -','FontSize',18,'FontWeight','bold','FontColor',TEXT_COLOR);
            self.AlertLabel = uilabel(statsPanelGrid,'Text','Alert: -','FontSize',14,'FontWeight','bold','FontColor',[1 0.85 0.2]);
            
            % Summary & Camera Settings Panel
            summaryAndCameraGrid = uigridlayout(mainRightGrid,'RowHeight',{'fit','1x'});
            summaryAndCameraGrid.Padding = [0 0 0 0];
            summaryAndCameraGrid.RowSpacing = 15;
            
            % Camera Controls Panel
            cameraPanel = uipanel(summaryAndCameraGrid, 'Title', 'Camera Settings', 'BackgroundColor', BG_COLOR);
            cameraPanelGrid = uigridlayout(cameraPanel, [5 1], 'RowHeight', {'fit','fit','fit','fit','fit'});
            cameraPanelGrid.RowSpacing = 4;
            cameraPanelGrid.Padding = [10 10 10 10];
            
            uilabel(cameraPanelGrid,'Text','IP Camera URL:','FontColor',TEXT_COLOR,'FontWeight','bold');
            self.IPCamURLField = uieditfield(cameraPanelGrid,'text','Placeholder','http://192.168.x.x:8080/video','BackgroundColor',[0.15 0.15 0.16],'FontColor',TEXT_COLOR);
            self.IPCamConnectButton = uibutton(cameraPanelGrid,'Text','Connect IP Camera','BackgroundColor',[0.4 0.4 0.4],'FontColor',TEXT_COLOR,'ButtonPushedFcn',@(s,e) self.connectIPCam());
            uilabel(cameraPanelGrid,'Text','PC Webcam:','FontColor',TEXT_COLOR,'FontWeight','bold');
            self.WebcamDropDown = uidropdown(cameraPanelGrid,'Items',{'(refresh...)'},'Value','(refresh...)','BackgroundColor',[0.15 0.15 0.16],'FontColor',TEXT_COLOR);
            self.WebcamConnectButton = uibutton(cameraPanelGrid,'Text','Connect Webcam','BackgroundColor',[0.4 0.4 0.4],'FontColor',TEXT_COLOR,'ButtonPushedFcn',@(s,e) self.connectWebcam());
            
            % Summary Text Area
            self.SummaryTextArea = uitextarea(summaryAndCameraGrid,'Editable','off','BackgroundColor',[0.15 0.15 0.16],'FontColor',TEXT_COLOR,'FontSize',12);
            self.SummaryTextArea.Value = { 'Session summary will appear here.' };
            
            % Status Label
            self.StatusLabel = uilabel(self.UIFigure,'Text','Ready','FontColor',TEXT_COLOR,'FontWeight','bold');
            self.StatusLabel.Position = [15 15 500 20];
            
        end
        function bindEvents(self)
            self.ExerciseDropDown.ValueChangedFcn = @(s,e) self.onExerciseChanged();
        end
        function initCamera(self)
            try
                % Clear any existing webcam connections first
                try
                    clear webcam;
                catch
                end
                
                % Prefer phone camera via MATLAB Mobile if available
                if exist('mobiledev','file') == 2 || exist('mobiledev','class') == 8
                    try
                        self.MobileDev = mobiledev;
                    catch
                        self.MobileDev = [];
                    end
                end
                if ~isempty(self.MobileDev)
                    self.StatusLabel.Text = 'Using MATLAB Mobile camera (enable Camera in the app).';
                else
                    % Don't auto-connect webcam on startup - let user choose
                    cams = webcamlist;
                    try
                        if isempty(cams)
                            self.WebcamDropDown.Items = {'(none found)'};
                            self.WebcamDropDown.Value='(none found)';
                        else
                            self.WebcamDropDown.Items = cams;
                            self.WebcamDropDown.Value = cams{1};
                        end
                    catch
                    end
                    self.StatusLabel.Text = 'Ready. Select and connect a camera.';
                end
            catch err
                self.CameraObj = [];
                self.StatusLabel.Text = sprintf('Camera init failed: %s', err.message);
            end
        end
        function resetSessionState(self)
            self.RepCount = 0; self.FrameCount = 0; self.PrevKeypoints = [];
            self.RepState = struct('Phase','Top','LastTransitionTime',datetime('now'));
            self.AlertsBuffer = "";
            self.SummaryTextArea.Value = { 'Session summary will appear here.' };
            self.updateHUD('-', '-', '-');
        end
        function startSession(self)
            if self.IsRunning; return; end
            self.IsRunning = true; self.SessionStart = datetime('now');
            self.ExerciseType = char(self.ExerciseDropDown.Value);
            self.StartButton.Enable = 'off'; self.StopButton.Enable = 'on';
            self.StatusLabel.Text = '💪 Workout in progress...';
            if isempty(self.TimerObj) || ~isvalid(self.TimerObj)
                self.TimerObj = timer('ExecutionMode','fixedRate','Period',0.06, ...
                    'TimerFcn',@(~,~) self.onTick(), 'ErrorFcn',@(~,e) self.onLoopError(e));
            end
            start(self.TimerObj);
        end
       function stopSession(self)
    % Immediate stop of the workout session (no lag)
    if ~self.IsRunning
        return;
    end
    
    self.StatusLabel.Text = '🛑 Stopping session...';
    drawnow limitrate nocallbacks; % ensure UI updates immediately

    % Signal abort to timer
    self.AbortFlag = true;
    pause(0.05); % small pause to let onTick check flag

    % Stop and delete timer safely
    try
        if ~isempty(self.TimerObj) && isvalid(self.TimerObj)
            stop(self.TimerObj);
            delete(self.TimerObj);
        end
    catch
    end
    self.TimerObj = [];

    % Reset session state
    self.IsRunning = false;
    self.StartButton.Enable = 'on';
    self.StopButton.Enable = 'off';
    
    % Update UI
    self.StatusLabel.Text = '✅ Session stopped instantly.';
    self.finalizeSummary();

    % Reset abort flag for next session
    self.AbortFlag = false;
end

        function onMuteToggle(self)
            self.IsMuted = logical(self.MuteToggle.Value);
            if self.IsMuted
                self.MuteToggle.Text = '🔇 Alerts Muted';
            else
                self.MuteToggle.Text = '🔊 Alerts On';
            end
        end
        function onExerciseChanged(self)
            self.ExerciseType = char(self.ExerciseDropDown.Value);
            self.resetSessionState();
        end
        function connectIPCam(self)
            url = strtrim(self.IPCamURLField.Value);
            if isempty(url); return; end
            try
                self.IPCamObj = ipcam(url);
                self.StatusLabel.Text = 'IP camera connected.';
                % Prefer IP cam when connected
                if ~isempty(self.CameraObj); try; clear(self.CameraObj); catch; end; self.CameraObj = []; end
                self.MobileDev = [];
            catch err
                self.IPCamObj = [];
                self.StatusLabel.Text = sprintf('IP cam connect failed: %s', err.message);
            end
        end
        function refreshCameraList(self)
            try
                cams = webcamlist;
                if isempty(cams)
                    self.WebcamDropDown.Items = {'(no cameras found)'};
                    self.WebcamDropDown.Value = '(no cameras found)';
                    self.StatusLabel.Text = 'No webcams detected.';
                else
                    self.WebcamDropDown.Items = cams;
                    self.WebcamDropDown.Value = cams{1};
                    self.StatusLabel.Text = sprintf('Found %d camera(s). Select and connect.', length(cams));
                end
            catch err
                self.StatusLabel.Text = sprintf('Refresh failed: %s', err.message);
            end
        end
        function connectWebcam(self)
            try
                % Clear ALL existing connections first
                if ~isempty(self.CameraObj)
                    try
                        clear(self.CameraObj);
                    catch
                    end
                    self.CameraObj = [];
                end
                if ~isempty(self.IPCamObj)
                    try
                        clear(self.IPCamObj);
                    catch
                    end
                    self.IPCamObj = [];
                end
                self.MobileDev = [];
                
                % Clear any global webcam connections
                try
                    clear webcam;
                catch
                end
                
                % Wait a moment for cleanup
                pause(1.0);
                
                % Get available cameras
                cams = webcamlist;
                if isempty(cams)
                    self.StatusLabel.Text = 'No webcams found.';
                    return;
                end
                
                % Update dropdown with current camera list
                self.WebcamDropDown.Items = cams;
                
                % Find selected camera
                val = char(self.WebcamDropDown.Value);
                idx = find(strcmp(cams, val), 1);
                if isempty(idx) || idx > length(cams)
                    idx = 1; % fallback to first
                    self.WebcamDropDown.Value = cams{1};
                end
                
                % Try to connect
                self.CameraObj = webcam(idx);
                
                % Test the connection with error handling
                try
                    testImg = snapshot(self.CameraObj);
                    if isempty(testImg) || size(testImg,3) ~= 3
                        clear(self.CameraObj);
                        self.CameraObj = [];
                        self.StatusLabel.Text = 'Webcam connected but no valid frames.';
                    else
                        self.StatusLabel.Text = sprintf('Camera initialized: %s', self.CameraObj.Name);
                    end
                catch testErr
                    clear(self.CameraObj);
                    self.CameraObj = [];
                    self.StatusLabel.Text = sprintf('Camera test failed: %s', testErr.message);
                end
                
            catch err
                self.CameraObj = [];
                self.StatusLabel.Text = sprintf('Webcam connect failed: %s', err.message);
            end
        end
        function onLoopError(self, e)
            try
                if isfield(e, 'Data') && isfield(e.Data, 'Message')
                    self.StatusLabel.Text = sprintf('Loop error: %s', e.Data.Message);
                else
                    self.StatusLabel.Text = sprintf('Loop error: %s', e.message);
                end
            catch
                self.StatusLabel.Text = 'Loop error occurred';
            end
        end
        function onTick(self)
            % Immediately exit if the session is not running
             if self.AbortFlag ; return; end;
            if ~self.IsRunning; return; end
            
            try
                self.FrameCount = self.FrameCount + 1;
                % Acquire frame
                frame = self.getFrame();
                if isempty(frame)
                    % Show debug info
                    self.StatusLabel.Text = sprintf('No frame (count: %d)', self.FrameCount);
                    return;
                end
                % Debug: show frame info occasionally
                if mod(self.FrameCount, 30) == 1
                    self.StatusLabel.Text = sprintf('Frame %d: %s', self.FrameCount, num2str(size(frame)));
                end
                % Optional: classify exercise every N frames
                try
                    if ~isempty(self.ClassifierNet) && mod(self.FrameCount, max(1,self.ClassifyStride)) == 0
                        imgForNet = frame;
                        try
                            if isfield(self.ClassifierMeta,'inputSize') && numel(self.ClassifierMeta.inputSize) >= 2
                                target = self.ClassifierMeta.inputSize(1:2);
                                imgForNet = imresize(frame, target);
                            end
                        catch
                        end
                        [lbl, scores] = classify(self.ClassifierNet, imgForNet);
                        self.LastPredictedExercise = char(string(lbl));
                        if exist('scores','var') && ~isempty(scores)
                            try
                                if isfield(self.ClassifierMeta,'classes')
                                    [~, idx] = max(scores);
                                    self.LastPredictedScore = scores(idx);
                                else
                                    self.LastPredictedScore = max(scores);
                                end
                            catch
                                self.LastPredictedScore = NaN;
                            end
                        end
                    end
                catch
                end
            % Pose detection (with graceful fallback) using stride and downscale
            try
                if mod(self.FrameCount, max(1,self.PoseStride)) == 0
                    % Downscale frame keeping aspect for faster inference
                    scale = self.DownscaleWidth / size(frame,2);
                    small = imresize(frame, scale);
                    kpSmall = detectPose(small);
                    % Scale keypoints back to original resolution
                    if isfield(kpSmall,'points') && ~isempty(kpSmall.points)
                        kpSmall.points = kpSmall.points ./ scale; % invert since small = frame*scale
                    end
                    keypoints = kpSmall;
                    self.LastPoseKeypoints = kpSmall;
                else
                    % Reuse last pose to keep UI smooth
                    keypoints = self.LastPoseKeypoints;
                    if isempty(keypoints)
                        keypoints = detectPose(frame); % first frames
                        self.LastPoseKeypoints = keypoints;
                    end
                end
                if ~isempty(self.PrevKeypoints)
                    keypoints = smoothKeypoints(keypoints, self.PrevKeypoints);
                end
                self.PrevKeypoints = keypoints;
            catch poseErr
                    self.StatusLabel.Text = sprintf('Pose error: %s', poseErr.message);
                    keypoints = struct('names',{{'center'}}, 'points',[320, 240], 'scores',0.1);
                end
                % Angle computation (focus on knee for squat; elbow for push-up/curl proxy)
                try
                    angles = computeAngles(keypoints);
                catch angleErr
                    self.StatusLabel.Text = sprintf('Angle error: %s', angleErr.message);
                    angles = struct();
                end
                % Rep counting
                try
            [self.RepState, self.RepCount] = updateRepCounter(angles, self.RepState, self.RepCount, self.ExerciseType);
                catch repErr
                    self.StatusLabel.Text = sprintf('Rep error: %s', repErr.message);
                end
                % Form rules & alerts
            try
                [alerts, ~, predictedExercise] = evaluateFormRules(angles, keypoints, self.ExerciseType);
                % Merge CNN prediction if available
                try
                    if ~isempty(self.LastPredictedExercise)
                        predictedExercise = self.LastPredictedExercise;
                        if ~strcmpi(predictedExercise, self.ExerciseType)
                            alerts(end+1) = sprintf('Wrong exercise? Looks like %s', predictedExercise); %#ok<AGROW>
                        elseif ~isnan(self.LastPredictedScore) && self.LastPredictedScore < 0.6
                            alerts(end+1) = "Form unclear: low confidence"; %#ok<AGROW>
                        end
                    end
                catch
                end
                alertText = join(string(alerts), "; ");
                if strlength(alertText) > 0
                    % Rate limit alerts
                    nowT = tic; %#ok<TNMLP>
                    t = toc(nowT); %#ok<NASGU>
                    if self.LastAlertTs == 0 || (etime(clock, datevec(self.SessionStart)) - self.LastAlertTs) > self.MinAlertInterval
                        self.AlertsBuffer = alertText;
                        self.LastAlertTs = etime(clock, datevec(self.SessionStart));
                        if ~self.IsMuted
                            try; beep; catch; end
                        end
                    end
                end
            catch alertErr
                    self.StatusLabel.Text = sprintf('Alert error: %s', alertErr.message);
                    alerts = {};
                end
                % Intensity (quick running estimate)
                try
                    intensity = computeIntensity(self.RepCount);
                catch intensityErr
                    self.StatusLabel.Text = sprintf('Intensity error: %s', intensityErr.message);
                    intensity = 0;
                end
                % Render - this is the key part
                try
                    drawOverlay(self.PreviewAxes, frame, keypoints, angles, alerts);
                catch renderErr
                    self.StatusLabel.Text = sprintf('Render error: %s', renderErr.message);
                end
                % Update HUD
                try
                    keyAngle = selectPrimaryAngleForHUD(angles, self.ExerciseType);
                    self.updateHUD(num2str(self.RepCount), sprintf('%.0f°', keyAngle), sprintf('%.1f/10', intensity));
                    self.AlertLabel.Text = sprintf('🚨 Alert: %s', char(self.AlertsBuffer));
                    % If we have a predicted exercise and it mismatches, reflect in status subtly
                    try
                        if exist('predictedExercise','var') && ~isempty(predictedExercise) && ~strcmpi(predictedExercise, self.ExerciseType)
                            self.StatusLabel.Text = sprintf('Selected: %s  Detected: %s', self.ExerciseType, predictedExercise);
                        end
                    catch
                    end
                catch hudErr
                    self.StatusLabel.Text = sprintf('HUD error: %s', hudErr.message);
                end
                
            catch mainErr
                self.StatusLabel.Text = sprintf('Main loop error: %s', mainErr.message);
            end
        end
        function frame = getFrame(self)
            try
                if ~isempty(self.IPCamObj)
                    frame = snapshot(self.IPCamObj);
                elseif ~isempty(self.MobileDev)
                    frame = snapshot(self.MobileDev);
                elseif ~isempty(self.CameraObj)
                    frame = snapshot(self.CameraObj);
                else
                    frame = uint8(zeros(480, 640, 3));
                    frame(:, :, 2) = 40; % dim placeholder
                end
                
                % Ensure frame is valid and has expected format
                if isempty(frame) || size(frame,3) ~= 3
                    frame = uint8(zeros(480, 640, 3));
                    frame(:, :, 2) = 40; % dim placeholder
                else
                    % Resize to consistent dimensions to avoid imshow errors
                    targetSize = [480, 640];
                    if size(frame,1) ~= targetSize(1) || size(frame,2) ~= targetSize(2)
                        try
                            frame = imresize(frame, targetSize);
                        catch
                            % If resize fails, use placeholder
                            frame = uint8(zeros(480, 640, 3));
                            frame(:, :, 2) = 40;
                        end
                    end
                end
            catch
                frame = uint8(zeros(480, 640, 3));
                frame(:, :, 2) = 40; % dim placeholder
            end
        end
        function updateHUD(self, reps, angle, intensity)
            self.RepsLabel.Text = ['Reps: ' reps];
            self.AngleLabel.Text = ['Angle: ' angle];
            self.IntensityLabel.Text = ['Intensity: ' intensity];
        end
        function finalizeSummary(self)
            % Calculate duration without seconds() function
            durationSec = etime(clock, datevec(self.SessionStart));
            % Use user inputs for diet recommendation
            heightCm = 172; weightKg = 70; goal = 'Maintain';
            try
                % Check if the fields have valid values
                if ~isempty(self.HeightField.Value)
                    heightCm = max(120, min(230, self.HeightField.Value));
                end
                if ~isempty(self.WeightField.Value)
                    weightKg = max(35, min(200, self.WeightField.Value));
                end
                if ~isempty(self.GoalDropDown); goal = char(self.GoalDropDown.Value); end
            catch
                % Use defaults if any error occurs
            end
            % Recompute quick intensity proxy
            intensity = computeIntensity(self.RepCount);
            diet = recommendDiet(weightKg, heightCm, goal, self.RepCount, durationSec / 60.0);
            % Format duration as MM:SS
            minutes = floor(durationSec / 60);
            seconds = mod(durationSec, 60);
            durationStr = sprintf('%02d:%02d', minutes, seconds);
            lines = {
                '💪 **Workout Summary** 💪',
                '--------------------------------',
                sprintf('Exercise: **%s**', self.ExerciseType),
                sprintf('Duration: **%s**', durationStr),
                sprintf('Reps: **%d**', self.RepCount),
                sprintf('Intensity: **%.1f/10**', intensity),
                ' ',
                '🍽️ **Diet Recommendation** 🍽️',
                '--------------------------------',
                sprintf('Goal: %s', goal),
                sprintf('Calories: **%dkcal**', round(diet.kcal)),
                sprintf('Protein: **%dg**', round(diet.protein_g)),
                sprintf('Carbs: **%dg**', round(diet.carbs_g)),
                sprintf('Fats: **%dg**', round(diet.fats_g))
                };
            self.SummaryTextArea.Value = lines;
            summary = struct('exercise', self.ExerciseType, 'durationSec', durationSec, ...
                'reps', self.RepCount, 'intensity', intensity, 'diet', diet, 'timestamp', datetime('now'), ...
                'heightCm', heightCm, 'weightKg', weightKg, 'goal', goal);
            try
                saveSession(summary, fullfile(pwd,'sessions'));
            catch
                % ignore save errors in demo
            end
        end
    end
end
function angle = selectPrimaryAngleForHUD(angles, exerciseType)
% Selects a representative angle for quick HUD display.
    switch lower(exerciseType)
        case 'squat'
            if isfield(angles,'kneeLeft'); angle = angles.kneeLeft; elseif isfield(angles,'kneeRight'); angle = angles.kneeRight; else; angle = NaN; end
        case 'pushup'
            if isfield(angles,'elbowLeft'); angle = angles.elbowLeft; elseif isfield(angles,'elbowRight'); angle = angles.elbowRight; else; angle = NaN; end
        case 'curl'
            if isfield(angles,'elbowRight'); angle = angles.elbowRight; elseif isfield(angles,'elbowLeft'); angle = angles.elbowLeft; else; angle = NaN; end
        otherwise
            angle = NaN;
    end
    if isnan(angle); angle = 0; end
end