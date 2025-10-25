classdef FitnessDashboard < matlab.apps.AppBase
    % This class creates a clean and modern dashboard for a fitness application.
    % It uses improved layout management, custom styling, and a more intuitive
    % component arrangement for a better user experience.

    %---------------------------------------------------------------
    % Properties (UI Components)
    %---------------------------------------------------------------
    properties (Access = public)
        UIFigure              matlab.ui.Figure
        MainGrid              matlab.ui.container.GridLayout
        HeaderGrid            matlab.ui.container.GridLayout
        ButtonGrid            matlab.ui.container.GridLayout
        GraphsGrid            matlab.ui.container.GridLayout
        TitleLabel            matlab.ui.control.Label
        LiveTrackingButton    matlab.ui.control.Button
        FitnessGuruButton     matlab.ui.control.Button
        ChatbotButton         matlab.ui.control.Button
        FitnessTrackerAxes    matlab.ui.control.UIAxes
        FitSightAxes          matlab.ui.control.UIAxes
        RefreshButton         matlab.ui.control.Button
    end
    %---------------------------------------------------------------
    % Callbacks
    %---------------------------------------------------------------
    methods (Access = private)
        % === Live Tracking ===
        function LiveTrackingButtonPushed(app, ~)
            try
                analyze = newww;
                analyze.UIFigure.Visible = 'on';
            catch ME
                uialert(app.UIFigure, ME.message, 'Error Launching Tracker');
            end
        end
        % === Fitness Guru ===
        function FitnessGuruButtonPushed(app, ~)
            try
                fit = FitSightApp;
                fit.UIFigure.Visible = 'on';
            catch ME
                uialert(app.UIFigure, ME.message, 'Error Opening FitSight');
            end
        end
        % === Chatbot / Diet Recommendation ===
        function ChatbotButtonPushed(app, ~)
            try
                dapp = app3;
                dapp.UIFigure.Visible = 'on';
            catch ME
                uialert(app.UIFigure, ME.message, 'Error Launching Chatbot');
            end
        end
        % === Refresh Graphs from CSVs ===
        function RefreshButtonPushed(app, ~)
            try
                app.updateFitnessTrackerGraph();
                app.updateFitSightGraph();
            catch ME
                uialert(app.UIFigure, ME.message, 'Error Refreshing Data');
            end
        end
    end
    %---------------------------------------------------------------
    % Utility Methods
    %---------------------------------------------------------------
    methods (Access = private)
        % Load latest Fitness Tracker CSV or plot dummy data
        function updateFitnessTrackerGraph(app)
            file = fullfile(pwd, 'fitness_tracker_latest.csv');
            if isfile(file)
                data = readtable(file);
                cla(app.FitnessTrackerAxes);
                plot(app.FitnessTrackerAxes, data.Time, data.Calories, '-o', 'LineWidth', 2, 'Color', '#0072BD');
                title(app.FitnessTrackerAxes, 'Fitness Tracker – Latest Session');
                xlabel(app.FitnessTrackerAxes, 'Time (min)');
                ylabel(app.FitnessTrackerAxes, 'Calories Burned');
                grid(app.FitnessTrackerAxes, 'on');
            else
                % Dummy plotting
                cla(app.FitnessTrackerAxes);
                time = 1:5;
                calories = [50 120 180 250 300];
                plot(app.FitnessTrackerAxes, time, calories, '-o', 'LineWidth', 2, 'Color', '#0072BD');
                title(app.FitnessTrackerAxes, 'Fitness Tracker – Sample Data');
                xlabel(app.FitnessTrackerAxes, 'Time (min)');
                ylabel(app.FitnessTrackerAxes, 'Calories Burned');
                grid(app.FitnessTrackerAxes, 'on');
                text(0.5, 0.5, 'No fitness tracker data found. Showing sample.', ...
                    'Parent', app.FitnessTrackerAxes, ...
                    'HorizontalAlignment', 'center', ...
                    'Color', [0.5 0.5 0.5]);
            end
        end
        % Load latest FitSight summary CSV or plot dummy data
        function updateFitSightGraph(app)
            file = fullfile(pwd, 'sessions', 'summary_latest.csv');
            if isfile(file)
                data = readtable(file);
                cla(app.FitSightAxes);
                b = bar(app.FitSightAxes, categorical(data.exercise), data.intensity, 'FaceColor', '#77AC30');
                title(app.FitSightAxes, 'FitSight – Intensity by Exercise');
                ylabel(app.FitSightAxes, 'Intensity (0–10)');
                grid(app.FitSightAxes, 'on');
            else
                % Dummy plotting
                cla(app.FitSightAxes);
                exercises = categorical({'Squats', 'Push-ups', 'Plank'});
                intensity = [8.5 7.0 9.2];
                bar(app.FitSightAxes, exercises, intensity, 'FaceColor', '#77AC30');
                title(app.FitSightAxes, 'FitSight – Sample Data');
                ylabel(app.FitSightAxes, 'Intensity (0–10)');
                grid(app.FitSightAxes, 'on');
                text(0.5, 0.5, 'No FitSight data found. Showing sample.', ...
                    'Parent', app.FitSightAxes, ...
                    'HorizontalAlignment', 'center', ...
                    'Color', [0.5 0.5 0.5]);
            end
        end
    end
    %---------------------------------------------------------------
    % Component Initialization
    %---------------------------------------------------------------
    methods (Access = private)
        function createComponents(app)
            % === Figure ===
            app.UIFigure = uifigure('Name', 'FITGURU DASHBOARD', ...
                'Position', [300 200 1000 600], ...
                'Color', [0.98 0.98 0.98], ... % Light, matte white color
                'Resize', 'on');
            % === Main Grid Layout ===
            app.MainGrid = uigridlayout(app.UIFigure, [4, 1], ...
                'RowHeight', {'fit', 80, '1x', 'fit'}, ...
                'ColumnWidth', {'1x'}, ...
                'Padding', [20 20 20 20], ...
                'RowSpacing', 20, ...
                'BackgroundColor', [0.98 0.98 0.98]);
            % === Header (Title) ===
            app.HeaderGrid = uigridlayout(app.MainGrid, [1, 1], ...
                'Padding', [0 0 0 0]);
            app.HeaderGrid.Layout.Row = 1;
            app.TitleLabel = uilabel(app.HeaderGrid, 'Text', 'FITGURU  DASHBOARD');
            app.TitleLabel.FontSize = 32;
            app.TitleLabel.FontWeight = 'bold';
            app.TitleLabel.HorizontalAlignment = 'center';
            app.TitleLabel.FontColor = [0.98 0.98 0.98];
            % === Buttons ===
            app.ButtonGrid = uigridlayout(app.MainGrid, [1, 3], ...
                'ColumnWidth', {'1x', '1x', '1x'}, ...
                'Padding', [0 0 0 0], ...
                'ColumnSpacing', 30);
            app.ButtonGrid.Layout.Row = 2;
            app.LiveTrackingButton = uibutton(app.ButtonGrid, 'push', ...
                'Text', '🏃‍♂️ Live Tracking', ...
                'FontSize', 14, ...
                'FontWeight', 'bold', ...
                'BackgroundColor', '#4CAF50', ...
                'FontColor', 'white', ...
                'ButtonPushedFcn', @(~,~)app.LiveTrackingButtonPushed());
            app.FitnessGuruButton = uibutton(app.ButtonGrid, 'push', ...
                'Text', '🤖 Fitness Guru', ...
                'FontSize', 14, ...
                'FontWeight', 'bold', ...
                'BackgroundColor', '#2196F3', ...
                'FontColor', 'white', ...
                'ButtonPushedFcn', @(~,~)app.FitnessGuruButtonPushed());
            app.ChatbotButton = uibutton(app.ButtonGrid, 'push', ...
                'Text', '💬 Chatbot', ...
                'FontSize', 14, ...
                'FontWeight', 'bold', ...
                'BackgroundColor', '#FF9800', ...
                'FontColor', 'white', ...
                'ButtonPushedFcn', @(~,~)app.ChatbotButtonPushed());
            % === Axes (Graphs) ===
            app.GraphsGrid = uigridlayout(app.MainGrid, [1, 2], ...
                'ColumnWidth', {'1x', '1x'}, ...
                'Padding', [0 0 0 0], ...
                'ColumnSpacing', 30);
            app.GraphsGrid.Layout.Row = 3;
            % Fitness Tracker Axes
            app.FitnessTrackerAxes = uiaxes(app.GraphsGrid);
            app.FitnessTrackerAxes.Toolbar.Visible = 'off';
            app.FitnessTrackerAxes.FontWeight = 'bold';
            % FitSight Axes
            app.FitSightAxes = uiaxes(app.GraphsGrid);
            app.FitSightAxes.Toolbar.Visible = 'off';
            app.FitSightAxes.FontWeight = 'bold';
            % === Refresh Button ===
            app.RefreshButton = uibutton(app.MainGrid, 'push', ...
                'Text', '🔄 Refresh Graphs', ...
                'FontSize', 14, ...
                'FontWeight', 'bold', ...
                'BackgroundColor', '#E0E0E0', ...
                'FontColor', 'black', ...
                'ButtonPushedFcn', @(~,~)app.RefreshButtonPushed());
            app.RefreshButton.Layout.Row = 4;
        end
    end
    %---------------------------------------------------------------
    % Public Methods (Constructor)
    %---------------------------------------------------------------
    methods (Access = public)
        function app = FitnessDashboard
            createComponents(app);
            app.updateFitnessTrackerGraph();
            app.updateFitSightGraph();
        end
    end
end