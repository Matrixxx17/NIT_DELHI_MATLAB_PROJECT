function drawOverlay(ax, frame, keypoints, angles, alerts)
% drawOverlay - renders frame and lightweight annotations on UIAxes
    if nargin < 1 || isempty(ax) || ~isvalid(ax); return; end
    
    % Handle different frame sizes and ensure valid image
    if isempty(frame) || size(frame,3) ~= 3
        frame = uint8(zeros(480, 640, 3));
        frame(:, :, 2) = 40; % dim placeholder
    end
    
    % Display frame with proper scaling
    try
        % Clear previous content
        cla(ax);
        
        % Display the image
        image(ax, frame); 
        axis(ax, 'image'); 
        ax.Visible = 'off'; 
        ax.XLim = [0.5, size(frame,2)+0.5];
        ax.YLim = [0.5, size(frame,1)+0.5];
        hold(ax,'on');
        
        % Add a small indicator that frame is updating
        text(ax, 10, 20, sprintf('Frame: %dx%d', size(frame,1), size(frame,2)), ...
            'Color', 'white', 'FontSize', 10, 'BackgroundColor', [0 0 0 0.5]);
        
    catch renderErr
        % Fallback if image display fails
        cla(ax);
        text(ax, 0.5, 0.5, sprintf('Render Error: %s', renderErr.message), ...
            'HorizontalAlignment', 'center', 'Color', 'red', 'FontSize', 12);
        return;
    end

    if isstruct(keypoints) && isfield(keypoints,'points') && size(keypoints.points,1) >= 1
        pts = keypoints.points;
        plot(ax, pts(:,1), pts(:,2), 'yo', 'MarkerFaceColor','y','MarkerSize',4);
        if size(pts,1) >= 2
            % draw minimal connections if shoulders/hips present
            names = getfieldSafe(keypoints,'names',{}); %#ok<GFLD>
            L = @(n) find(strcmpi(names,n),1);
            links = {
                'left_shoulder','right_shoulder';
                'left_hip','right_hip';
                'left_shoulder','left_hip';
                'right_shoulder','right_hip'
            };
            for i=1:size(links,1)
                a = L(links{i,1}); b = L(links{i,2});
                if ~isempty(a) && ~isempty(b) && a<=size(pts,1) && b<=size(pts,1)
                    plot(ax, [pts(a,1) pts(b,1)], [pts(a,2) pts(b,2)], 'g-','LineWidth',1.5);
                end
            end
        end
    end

    % Angle HUD text
    txt = [];
    if isfield(angles,'kneeLeft') && ~isnan(angles.kneeLeft)
        txt = [txt sprintf('KneeL: %.0f°  ', angles.kneeLeft)]; %#ok<AGROW>
    end
    if isfield(angles,'kneeRight') && ~isnan(angles.kneeRight)
        txt = [txt sprintf('KneeR: %.0f°  ', angles.kneeRight)]; %#ok<AGROW>
    end
    if isfield(angles,'spine') && ~isnan(angles.spine)
        txt = [txt sprintf('Spine: %.0f°  ', angles.spine)]; %#ok<AGROW>
    end
    if ~isempty(txt)
        text(ax, 12, 20, txt, 'Color','w','FontWeight','bold','FontSize',11,'BackgroundColor',[0 0 0 0.3]);
    end

    % Alerts banner (show last)
    if ~isempty(alerts)
        msg = string(alerts(end));
        % Adjusted Y-coordinate to move the alert higher
        text(ax, 12, 50, msg, 'Color',[1 0.9 0.2], 'FontWeight','bold', 'FontSize',12, 'BackgroundColor',[0 0 0 0.3]);
    end

    hold(ax,'off');
end

function v = getfieldSafe(s, f, def)
    if isstruct(s) && isfield(s,f); v = s.(f); else; v = def; end
end