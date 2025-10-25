classdef newww < matlab.apps.AppBase
    % ============================================================
    % FINAL FITNESS TRACKER APP - BRIGHT SPORT MODE UI
    % ============================================================

    properties (Access = public)
        UIFigure matlab.ui.Figure
        StatusLabel matlab.ui.control.Label
        MetricLabels matlab.ui.control.Label
        ValueLabels matlab.ui.control.Label
        ProgressAxes matlab.ui.control.UIAxes
    end

    methods (Access = private)
        % ============================================================
        % MAIN TRACKING LOGIC
        % ============================================================
        function runTracker(app)
            try
                % --- CONFIGURATION ---
                DEVICE_NAME = "Redmi Note 12 5G";
                TRACKING_DURATION_S = 10;
                FS = 10; G = 9.81;
                USER_WEIGHT_KG = 75;
                MET_AT_REST = 1.0; MET_WALKING = 3.0;
                TARGET_ACTIVE_TIME_S = 3600;
                MAX_DAS = 10; MAX_CFS = 15;
                accumulated_active_time_s = 0;

                % --- CLEAN EXISTING CONNECTIONS ---
                existingM = evalin('base','whos');
                if any(strcmp({existingM.class}, 'mobiledev'))
                    try
                        Mprev = evalin('base','M');
                        delete(Mprev);
                    catch
                    end
                    evalin('base','clear M');
                end

                % --- CONNECT TO MOBILE DEVICE ---
                app.updateLabel("Status","Connecting...");
                M = mobiledev(DEVICE_NAME);
                pause(1);

                cleanupObj = onCleanup(@() app.safeDeleteMobile(M));

                % --- START LOGGING ---
                app.updateLabel("Status","Recording...");
                app.StatusLabel.Text = "📱 Collecting sensor data... Keep moving!";
                M.AccelerationSensorEnabled = 1;
                M.PositionSensorEnabled = 1;
                M.Logging = 1;
                pause(TRACKING_DURATION_S);
                M.Logging = 0;

                % --- RETRIEVE DATA ---
                [a, ~] = accellog(M);
                [lat, lon, ~, ~, ~, ~, ~] = poslog(M);
                discardlogs(M);

                % --- PROCESS DATA ---
                if isempty(a)
                    final_state = '❌ No Data';
                    steps = 0; Active_Time_s_period = 0;
                    TotalDistance_Report = 0; total_calories = 0; peak_speed = 0;
                else
                    dynamic_a = a;
                    dynamic_a(:,3) = a(:,3) - G;
                    dynamic_mag = sqrt(sum(dynamic_a.^2, 2));
                    [~, locs] = findpeaks(dynamic_mag, ...
                        'MinPeakProminence', 0.5, ...
                        'MinPeakDistance', 0.2*FS, ...
                        'MinPeakHeight', 0.8);
                    steps = length(locs);

                    if steps > 5
                        final_state = '🚶‍♂️ Walking'; MET_Value = MET_WALKING;
                    elseif steps > 0
                        final_state = '🕺 Light Activity';
                        MET_Value = MET_AT_REST + (MET_WALKING - MET_AT_REST)/2;
                    else
                        final_state = '🪑 Rest'; MET_Value = MET_AT_REST;
                    end

                    Active_Time_s_period = strcmp(final_state,'🚶‍♂️ Walking') * TRACKING_DURATION_S;
                    total_calories = (MET_Value * USER_WEIGHT_KG / 3600) * TRACKING_DURATION_S;
                    TotalDistance_Report = steps * 0.75;
                    peak_speed = TotalDistance_Report / TRACKING_DURATION_S;
                end

                % --- SCORING ---
                DailyActiveTimeSeconds = accumulated_active_time_s + Active_Time_s_period;
                DAS_raw = (DailyActiveTimeSeconds / TARGET_ACTIVE_TIME_S) * 10;
                DAS = min(MAX_DAS, DAS_raw);
                Distance_Score = min(5, (TotalDistance_Report / 1000) * 5);
                CFS = round(DAS + Distance_Score, 2);

                % --- UPDATE UI ---
                app.updateLabel("Speed (m/s)",sprintf("%.2f",peak_speed));
                app.updateLabel("DAS",sprintf("%.2f",DAS));
                app.updateLabel("CFS",sprintf("%.2f",CFS));
                app.updateLabel("Status",final_state);
                app.updateLabel("Steps",num2str(steps));
                app.updateLabel("Calories (kcal)",sprintf("%.2f",total_calories));
                app.updateLabel("Distance (m)",sprintf("%.2f",TotalDistance_Report));
                app.StatusLabel.Text = "✅ Tracking complete! Results below.";

                % --- Animate progress ring ---
                cla(app.ProgressAxes);
                hold(app.ProgressAxes, 'on');
                theta = linspace(0,2*pi,100);
                fill(app.ProgressAxes, cos(theta), sin(theta), [0.9 0.9 0.9], 'EdgeColor','none');
                progress = min(1, CFS / MAX_CFS);
                patch(app.ProgressAxes, ...
                    [0 cos(theta(theta<=progress*2*pi))], ...
                    [0 sin(theta(theta<=progress*2*pi))], ...
                    [0.1 0.8 0.4], 'EdgeColor','none');
                text(app.ProgressAxes,0,0.1,sprintf('CFS\n%.1f',CFS),...
                    'HorizontalAlignment','center','FontSize',16,'FontWeight','bold');
                hold(app.ProgressAxes, 'off');

            catch ME
                app.StatusLabel.Text = "⚠ Error: Check connection or sensors.";
                uialert(app.UIFigure, ME.message, 'Tracking Error');
            end
        end

        % ============================================================
        % HELPER FUNCTIONS
        % ============================================================
        function updateLabel(app, tag, value)
            lbl = findobj(app.UIFigure,'Tag',tag);
            if ~isempty(lbl)
                lbl.Text = value;
            end
        end

        function safeDeleteMobile(~, M)
            try
                if exist('M','var') && ~isempty(M)
                    delete(M);
                end
            catch
            end
        end
    end

    % ============================================================
    % COMPONENT INITIALIZATION
    % ============================================================
    methods (Access = private)
        function createComponents(app)
            % === FIGURE ===
            app.UIFigure = uifigure('Name','FITGURU Tracker',...
                'Position',[400 200 540 620],...
                'Color',[1 1 1]);
            movegui(app.UIFigure,'center');

            % === HEADER BAR ===
            uipanel(app.UIFigure,'BackgroundColor',[0.2 0.8 0.8],...
                'Position',[0 570 540 50],'BorderType','none');
            uilabel(app.UIFigure,'Text','FITGURU ANALYTICS',...
                'FontSize',22,'FontWeight','bold','FontColor',[1 1 1],...
                'Position',[100 575 340 40],'HorizontalAlignment','center');

            % === STATUS LABEL ===
            app.StatusLabel = uilabel(app.UIFigure,'Text',...
                'Initializing sensors...',...
                'FontSize',14,'FontWeight','bold','FontColor',[0.2 0.2 0.4],...
                'Position',[40 525 460 30],'HorizontalAlignment','center');

            % === METRICS PANEL ===
            metrics = ["Speed (m/s)","DAS","CFS","Status","Steps","Calories (kcal)","Distance (m)"];
            ypos = 460;
            colors = [0.2 0.7 0.3; 0.1 0.6 0.8; 0.9 0.6 0.1; 0.8 0.3 0.5; 0.5 0.4 0.9; 0.2 0.8 0.7; 0.7 0.5 0.2];
            for i = 1:length(metrics)
                card = uipanel(app.UIFigure,'BackgroundColor',[1 1 1],...
                    'Position',[60 ypos 420 45],'BorderType','none');
                uilabel(card,'Text',metrics(i),'FontSize',14,'FontWeight','bold',...
                    'FontColor',colors(i,:),...
                    'Position',[10 10 180 25],'HorizontalAlignment','left');
                uilabel(card,'Text','-',...
                    'FontSize',14,'FontWeight','bold','Position',[250 10 150 25],...
                    'HorizontalAlignment','left','Tag',metrics(i),...
                    'FontColor',[0.1 0.1 0.2]);
                ypos = ypos - 55;
            end

            % === PROGRESS RING (CFS visualization) ===
            app.ProgressAxes = uiaxes(app.UIFigure,'Position',[190 40 160 160]);
            axis(app.ProgressAxes,'off');
            app.ProgressAxes.XLim = [-1.1 1.1];
            app.ProgressAxes.YLim = [-1.1 1.1];
            title(app.ProgressAxes,'CFS Score','FontWeight','bold');

            % === START TRACKING ===
            drawnow;
            pause(0.6);
            app.runTracker();
        end
    end

    % ============================================================
    % APP CREATION
    % ============================================================
    methods (Access = public)
        function app = newww
            createComponents(app)
        end
    end
end
