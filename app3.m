classdef app3 < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure matlab.ui.Figure
        HeaderPanel matlab.ui.container.Panel
        HeaderLabel matlab.ui.control.Label
        ChatPanel matlab.ui.container.Panel
        ChatArea matlab.ui.control.TextArea
        InputPanel matlab.ui.container.Panel
        MessageField matlab.ui.control.EditField
        SendButton matlab.ui.control.Button
    end

    methods (Access = private)
        %% --- API CALL ---
        function response = callLLMApi(app, userInput)
            apiKey = "AIzaSyDJp1MXTa_22lWwQgA7elSW6i6MdP7kM24"; % Replace with valid key
            url = "https://generativelanguage.googleapis.com/v1beta/models/g

            
            
            
            
            enerateContent?key=" + apiKey;
            url = char(url);

            body = struct("contents", struct("parts", struct("text", userInput)));
            options = weboptions('MediaType', 'application/json', ...
                                 'ContentType', 'json', ...
                                 'Timeout', 30);
            try
                data = webwrite(url, body, options);
                response = data.candidates(1).content.parts(1).text;
            catch ME
                response = "⚠️ Error: " + ME.message;
            end
        end

        %% --- Add message bubbles ---
        function addMessage(app, sender, text)
            if strcmp(sender, 'user')
                prefix = '💪 You: ';
                color = '#D4F8E8'; % light green bubble
                align = 'right';
            else
                prefix = '🤖 FitBot: ';
                color = '#EAF2FF'; % light blue bubble
                align = 'left';
            end
            bubble = sprintf('<p style="text-align:%s; background-color:%s; border-radius:12px; padding:8px; margin:6px; display:inline-block;">%s%s</p>', align, color, prefix, text);
            app.ChatArea.Value = [app.ChatArea.Value; bubble];
        end

        %% --- Send Button Action ---
        function SendButtonPushed(app, ~)
            userInput = strtrim(app.MessageField.Value);
            if isempty(userInput)
                return;
            end

            app.addMessage('user', userInput);
            app.MessageField.Value = '';

            % Simulate "typing"
            drawnow;
            pause(0.3);
            app.addMessage('bot', '⌛ FitBot is thinking...');
            drawnow;

            % Call model
            reply = app.callLLMApi(userInput);

            % Replace "thinking" bubble
            app.ChatArea.Value(end) = [];
            app.addMessage('bot', reply);
        end
    end

    %% --- Startup message ---
    methods (Access = public)
        function startupFcn(app)
            app.addMessage('bot', '💬 Welcome to <b>FitBot</b> — Your personal fitness & motivation partner! 🌟');
        end
    end

    %% --- UI Creation ---
    methods (Access = private)
        function createComponents(app)
            % === Main Window ===
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [150 100 750 550];
            app.UIFigure.Name = 'FitBot - Fitness Chat Assistant';
            app.UIFigure.Color = [0.95 1 0.97]; % Mint background

            % === Header ===
            app.HeaderPanel = uipanel(app.UIFigure);
            app.HeaderPanel.Position = [0 500 750 50];
            app.HeaderPanel.BackgroundColor = [0.25 0.65 0.35];

            app.HeaderLabel = uilabel(app.HeaderPanel);
            app.HeaderLabel.Text = '🏋️‍♂️ FitBot — Chat • Train • Grow';
            app.HeaderLabel.FontSize = 18;
            app.HeaderLabel.FontWeight = 'bold';
            app.HeaderLabel.FontColor = [1 1 1];
            app.HeaderLabel.HorizontalAlignment = 'center';
            app.HeaderLabel.Position = [120 10 500 30];

            % === Chat Area Panel ===
            app.ChatPanel = uipanel(app.UIFigure);
            app.ChatPanel.Position = [30 90 690 400];
            app.ChatPanel.BackgroundColor = [1 1 1];
            app.ChatPanel.BorderColor = [0.7 0.9 0.8];
            app.ChatPanel.BorderType = 'line';
            app.ChatPanel.BorderWidth = 1.2;

            % Chat display
            app.ChatArea = uitextarea(app.ChatPanel);
            app.ChatArea.Position = [15 15 660 370];
            app.ChatArea.Editable = 'off';
            app.ChatArea.FontName = 'Segoe UI';
            app.ChatArea.FontSize = 13;
            app.ChatArea.BackgroundColor = [1 1 1];
            app.ChatArea.Value = {};

            % === Input Panel ===
            app.InputPanel = uipanel(app.UIFigure);
            app.InputPanel.Position = [30 25 690 55];
            app.InputPanel.BackgroundColor = [0.9 0.98 0.9];
            app.InputPanel.BorderType = 'none';

            % Message Field
            app.MessageField = uieditfield(app.InputPanel, 'text');
            app.MessageField.Position = [15 12 520 30];
            app.MessageField.Placeholder = 'Type your message...';
            app.MessageField.FontSize = 13;
            app.MessageField.BackgroundColor = [1 1 1];
            app.MessageField.FontName = 'Segoe UI';

            % Send Button
            app.SendButton = uibutton(app.InputPanel, 'push');
            app.SendButton.Position = [550 12 120 30];
            app.SendButton.Text = 'Send 💬';
            app.SendButton.FontWeight = 'bold';
            app.SendButton.BackgroundColor = [0.3 0.7 0.4];
            app.SendButton.FontColor = [1 1 1];
            app.SendButton.ButtonPushedFcn = createCallbackFcn(app, @SendButtonPushed, true);

            % Show
            app.UIFigure.Visible = 'on';
        end
    end

    %% --- App creation and deletion ---
    methods (Access = public)
        function app = app3
            createComponents(app)
            registerApp(app, app.UIFigure)
            app.startupFcn()
            if nargout == 0
                clear app
            end
        end

        function delete(app)
            delete(app.UIFigure)
        end
    end
end
