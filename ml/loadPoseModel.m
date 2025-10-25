function detector = loadPoseModel()
% loadPoseModel - loads a trained keypoint detector if available.
% Looks for models/poseDetector.mat and returns [] if not found or invalid.

    persistent cachedDetector cachedOk lastCheckTs;
    if ~isempty(cachedDetector) && cachedOk && (isempty(lastCheckTs) || seconds(datetime('now')-lastCheckTs) < 5)
        detector = cachedDetector; return;
    end

    cachedOk = false; detector = [];
    modelPath = fullfile(pwd, 'models', 'poseDetector.mat');
    if exist(modelPath,'file') ~= 2
        lastCheckTs = datetime('now'); return;
    end
    try
        S = load(modelPath);
        if isfield(S, 'detector')
            detector = S.detector;
            cachedDetector = detector; cachedOk = true;
        end
    catch
        detector = [];
    end
    lastCheckTs = datetime('now');
end




