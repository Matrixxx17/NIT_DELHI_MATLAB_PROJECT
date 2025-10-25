classdef app3 < matlab.apps.AppBase
    % This class implements a simple chatbot using the Gemini API for MATLAB.
    % It uses a responsive grid layout for a cleaner UI.

    %---------------------------------------------------------------
    % Properties (UI Components)
    %---------------------------------------------------------------
    properties (Access = public)
        UIFigure               matlab.ui.Figure
        MainGrid               matlab.ui.container.GridLayout
        ChatArea               matlab.ui.control.TextArea
        InputGrid              matlab.ui.container.GridLayout
        UserInputField         matlab.ui.control.EditField
        SendButton             matlab.ui.control.Button
    end

    %---------------------------------------------------------------
    % Properties (Data and State)
    %---------------------------------------------------------------
    properties (Access = private)
        ChatHistory cell = {};   % Stores conversation history as {role,text}
        ApiKey char = '';        % Place your Gemini API Key here
    end

    %---------------------------------------------------------------
    % Utility Methods
    %---------------------------------------------------------------
    methods (Access = private)

        % Function to call the Gemini API
        function response = callLLMApi(app, userInput)
            % NOTE: Replace 'YOUR_GEMINI_API_KEY' with your actual key.
            if isempty(app.ApiKey)
                response = "Error: Please set your Gemini API Key in the 'ApiKey' property.";
                return;
            end
            
            url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=" + app.ApiKey;
            url = char(url);

            % 1. Add user input to chat history
            app.ChatHistory{end+1} = struct('role', 'user', 'text', userInput);

            % 2. Build contents array for API payload
            contents = [];
            for i = 1:numel(app.ChatHistory)
                contents = [contents; struct('role', app.ChatHistory{i}.role, 'parts', struct('text', app.ChatHistory{i}.text))]; %#ok<AGROW>
            end

            % 3. Build body
            body = struct('contents', contents);

            % 4. Send request
            options = weboptions('MediaType', 'application/json', ...
                                 'ContentType', 'json', ...
                                 'Timeout', 30);
            try
                data = webwrite(url, body, options);
                
                % Check if response candidates exist
                if isfield(data, 'candidates') && ~isempty(data.candidates)
                    response = data.candidates(1).content.parts(1).text;
                    % 5. Store model response
                    app.ChatHistory{end+1} = struct('role', 'model', 'text', response);
                else
                     response = "Bot: API returned an empty response or error structure.";
                end

            catch ME
                response = "Bot: API Error: " + ME.message;
            end
        end
       
    end

    %---------------------------------------------------------------
    % Callbacks that handle component events
    %---------------------------------------------------------------
    methods (Access = private)

        % Button pushed function: SendButton
        function SendButtonPushed(app, ~)
            userInput = strtrim(app.UserInputField.Value);
            if isempty(userInput)
                return;
            end
            
            % Indicate that the bot is thinking
            app.ChatArea.Value = [app.ChatArea.Value; "You: " + userInput; "Bot: (Thinking...)"];

            % Get model response with context
            response = app.callLLMApi(userInput);
            
            % Update ChatArea with the final response
            currentHistory = app.ChatArea.Value;
            % Remove the last 'Bot: (Thinking...)' line
            app.ChatArea.Value = currentHistory(1:end-1); 
            
            % Display final bot response
            app.ChatArea.Value = [app.ChatArea.Value; "Bot: " + response];

            % Clear input
            app.UserInputField.Value = '';
        end

        % Key pressed function: UserInputField (Allows sending with Enter key)
        function UserInputFieldKeyPressed(app, event)
            if strcmp(event.Key, 'return')
                app.SendButtonPushed();
            end
        end
    end

    %---------------------------------------------------------------
    % Component Initialization
    %---------------------------------------------------------------
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)
            
            % === Figure Initialization ===
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 640 480];
            app.UIFigure.Name = 'Gemini Chatbot';
            app.UIFigure.Color = [0.95 0.95 0.95]; % Light gray background
            
            % Initialize API Key (IMPORTANT: PASTE YOUR KEY HERE)
            % Example: app.ApiKey = 'AIzaSy...';
            app.ApiKey = ''; % <-- SET YOUR KEY HERE

            % === Main Grid Layout (Top to Bottom) ===
            app.MainGrid = uigridlayout(app.UIFigure, [2, 1]);
            app.MainGrid.RowHeight = {'1x', 'fit'};
            app.MainGrid.ColumnWidth = {'1x'};
            app.MainGrid.RowSpacing = 10;
            app.MainGrid.Padding = [10 10 10 10];
            app.MainGrid.BackgroundColor = app.UIFigure.Color;

            % === 1. Chat Area (Row 1) ===
            app.ChatArea = uitextarea(app.MainGrid);
            app.ChatArea.Editable = 'off';
            app.ChatArea.FontSize = 12;
            app.ChatArea.FontName = 'Courier New'; % Monospace for chat readability
            app.ChatArea.Layout.Row = 1;
            app.ChatArea.Layout.Column = 1;
            app.ChatArea.Value = "Welcome to the Fitness Chatbot! Ask me about diet, exercises, or form tips.";

            % === 2. Input Grid (Row 2, handles input field and button) ===
            app.InputGrid = uigridlayout(app.MainGrid, [1, 2]);
            app.InputGrid.ColumnWidth = {'1x', 100};
            app.InputGrid.RowHeight = {'fit'};
            app.InputGrid.ColumnSpacing = 10;
            app.InputGrid.Padding = [0 0 0 0];
            app.InputGrid.Layout.Row = 2;
            app.InputGrid.Layout.Column = 1;
            
            % User Input Field
            app.UserInputField = uieditfield(app.InputGrid, 'area');
            app.UserInputField.Layout.Row = 1;
            app.UserInputField.Layout.Column = 1;
            app.UserInputField.FontSize = 12;
            app.UserInputField.Placeholder = 'Type your message here...';
            % Bind 'return' key to send function
            app.UserInputField.KeyPressFcn = createCallbackFcn(app, @UserInputFieldKeyPressed, true); 

            % Send Button
            app.SendButton = uibutton(app.InputGrid, 'push');
            app.SendButton.ButtonPushedFcn = createCallbackFcn(app, @SendButtonPushed, true);
            app.SendButton.Layout.Row = 1;
            app.SendButton.Layout.Column = 2;
            app.SendButton.Text = 'Send';
            app.SendButton.FontSize = 14;
            app.SendButton.FontWeight = 'bold';
            app.SendButton.BackgroundColor = [0.3 0.6 0.9]; % Blue
            app.SendButton.FontColor = [1 1 1];
            
            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    %---------------------------------------------------------------
    % App creation and deletion
    %---------------------------------------------------------------
    methods (Access = public)
        % Construct app
        function app = app3
            % Create UIFigure and components
            createComponents(app)
            % Register the app with App Designer
            registerApp(app, app.UIFigure)
            if nargout == 0
                clear app
            end
        end
        % Code that executes before app deletion
        function delete(app)
            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end
