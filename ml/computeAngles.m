function angles = computeAngles(keypoints)
% computeAngles - derives a minimal angle set from available keypoints.
% Expects COCO-like names if available.
    angles = struct();
    if ~isfield(keypoints,'names') || ~isfield(keypoints,'points'); return; end
    names = keypoints.names; pts = keypoints.points;
    % Helper to get point by name
    function p = get(name)
        idx = find(strcmpi(names, name), 1);
        if ~isempty(idx) && idx <= size(pts,1)
            p = pts(idx, :);
        else
            p = [NaN, NaN];
        end
    end
    % Common joints
    lKnee = get('left_knee'); rKnee = get('right_knee');
    lHip  = get('left_hip');  rHip  = get('right_hip');
    lAnk  = get('left_ankle'); rAnk = get('right_ankle');
    lElb  = get('left_elbow'); rElb = get('right_elbow');
    lSh   = get('left_shoulder'); rSh = get('right_shoulder');
    lWrist= get('left_wrist'); rWrist= get('right_wrist');
    
    % Elbow angles
    angles.elbowLeft  = jointAngle(lSh, lElb, lWrist);
    angles.elbowRight = jointAngle(rSh, rElb, rWrist);
    % Hip angles
    angles.hipLeft = jointAngle(lSh, lHip, lKnee);
    angles.hipRight = jointAngle(rSh, rHip, rKnee);
    % Spine tilt via shoulder-hip midpoint vector
    shMid = nanmean([lSh; rSh], 1); hipMid = nanmean([lHip; rHip], 1);
    angles.spine = lineAngleToVertical(hipMid, shMid);
    
    % The `handsUpScore` and `legSpread` are not relevant for pushups, so we can omit them
    % from the analysis for this exercise type to keep the logic focused.
    
    % Add this section to display the calculated angles
    disp('Calculated Angles:');
    if isfield(angles, 'elbowLeft')
        disp(['  Elbow Left: ' num2str(angles.elbowLeft) ' degrees']);
    end
    if isfield(angles, 'elbowRight')
        disp(['  Elbow Right: ' num2str(angles.elbowRight) ' degrees']);
    end
    if isfield(angles, 'hipLeft')
        disp(['  Hip Left: ' num2str(angles.hipLeft) ' degrees']);
    end
    if isfield(angles, 'hipRight')
        disp(['  Hip Right: ' num2str(angles.hipRight) ' degrees']);
    end
    
    % Local helpers
    function a = jointAngle(aPt, jPt, bPt)
        a = NaN;
        if any(isnan([aPt jPt bPt], 'all')); return; end
        v1 = aPt - jPt; v2 = bPt - jPt;
        num = dot(v1, v2); den = norm(v1) * norm(v2);
        if den == 0; return; end
        c = max(-1, min(1, num / den));
        a = acosd(c);
    end
    function a = jointAngleToVertical(base, tip)
        a = NaN; if any(isnan([base tip],'all')); return; end
        v = tip - base;
        up = [0, -1]; % image y increases downward
        c = max(-1, min(1, dot(v, up) / (norm(v) * norm(up))));
        a = acosd(c);
    end
    function a = lineAngleToVertical(p0, p1)
        a = jointAngleToVertical(p0, p1);
    end
end